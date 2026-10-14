import 'dart:async' show unawaited;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/price_formatter.dart';
import '../../core/utils/sku_generator.dart';
import '../barcode/barcode_scan_button.dart';
import '../lookup/lookup_service.dart';
import '../photo/photo_picker_field.dart';
import '../photo/photo_service.dart';

enum _DuplicateAction { editExisting, createAnyway }

/// Écran d'ajout / édition d'un produit.
///
/// Si [existingProduct] est fourni, l'écran s'ouvre en mode édition et
/// précharge ses valeurs ; sinon il s'ouvre en mode ajout.
///
/// Apparence d'après la maquette Stitch "Ajouter un produit" : sections en
/// cartes blanches (visuel, informations générales, code-barres, tarifs &
/// quantités, variante) et bouton d'enregistrement fixé en bas. Les éléments
/// de la maquette sans équivalent dans l'app ont été écartés : badge
/// "NOUVEAU", sous-titre "Catalogue principal", menu "...", photos
/// secondaires, liste de catégories figée, "Ajouter une autre variante",
/// "Enregistrer comme brouillon", mentions HT/TTC et symbole €.
class ProductEntryScreen extends StatefulWidget {
  const ProductEntryScreen({
    super.key,
    required this.database,
    this.existingProduct,
  });

  final AppDatabase database;
  final Product? existingProduct;

  @override
  State<ProductEntryScreen> createState() => _ProductEntryScreenState();
}

class _ProductEntryScreenState extends State<ProductEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _optionNameController;
  late final TextEditingController _optionValueController;
  late final FocusNode _barcodeFocusNode;
  late final FocusNode _categoryFocusNode;
  late final LookupService _lookupService;
  final PhotoService _photoService = const PhotoService();

  bool _isSaving = false;
  bool _isLookingUp = false;

  /// Catégories déjà utilisées en base, proposées en autocomplétion du champ
  /// Catégorie. Chargées une fois à l'ouverture de l'écran.
  List<String> _knownCategories = const [];

  /// Longueur indicative au-delà de laquelle le compteur de la description
  /// passe en rouge. Non bloquante : aucune limite n'existe en base et les
  /// descriptions importées depuis Word peuvent être plus longues.
  static const descriptionSoftLimit = 600;

  /// Produit couramment édité. Peut diverger de [ProductEntryScreen.existingProduct]
  /// si l'utilisatrice choisit "Modifier l'existant" après un scan détectant
  /// un doublon.
  Product? _currentProduct;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _lookupService = LookupService(database: widget.database);
    _currentProduct = widget.existingProduct;
    _nameController = TextEditingController();
    _skuController = TextEditingController();
    _categoryController = TextEditingController();
    _descriptionController = TextEditingController();
    _barcodeController = TextEditingController();
    _costPriceController = TextEditingController();
    _sellPriceController = TextEditingController();
    _quantityController = TextEditingController();
    _optionNameController = TextEditingController();
    _optionValueController = TextEditingController();
    _populateControllers(_currentProduct);

    _barcodeFocusNode = FocusNode();
    _barcodeFocusNode.addListener(() {
      if (!_barcodeFocusNode.hasFocus) {
        _checkBarcodeDuplicate();
      }
    });
    _categoryFocusNode = FocusNode();
    _loadKnownCategories();
  }

  Future<void> _loadKnownCategories() async {
    final categories = await widget.database.getDistinctCategories();
    if (!mounted) return;
    setState(() => _knownCategories = categories);
  }

  /// Propositions d'autocomplétion pour la catégorie : toutes les catégories
  /// connues si le champ est vide, sinon celles qui contiennent le texte
  /// saisi (sans tenir compte de la casse).
  Iterable<String> _categoryOptions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return _knownCategories;
    return _knownCategories.where((c) => c.toLowerCase().contains(query));
  }

  /// Bouton "Générer auto" : remplit le champ SKU avec un [generateSafeSku()],
  /// que l'utilisatrice reste libre de modifier. Complète (sans le remplacer)
  /// le repli automatique de [_save] quand le champ est resté vide.
  void _generateSku() {
    setState(() => _skuController.text = generateSafeSku());
  }

  /// Stepper de quantité : ajoute [delta] à la valeur saisie (0 si le champ
  /// est vide ou illisible), sans jamais passer sous zéro. Le champ reste
  /// modifiable directement au clavier.
  void _adjustQuantity(int delta) {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 1 << 31);
    _quantityController.value = TextEditingValue(
      text: next.toString(),
      selection: TextSelection.collapsed(offset: next.toString().length),
    );
  }

  void _populateControllers(Product? product) {
    _photoPath = product?.photoPath;
    _nameController.text = product?.name ?? '';
    _skuController.text = product?.sku ?? '';
    _categoryController.text = product?.category ?? '';
    _descriptionController.text = product?.description ?? '';
    _barcodeController.text = product?.barcode ?? '';
    _costPriceController.text = product?.costPrice != null
        ? _formatNumber(product!.costPrice!)
        : '';
    _sellPriceController.text = product?.sellPrice != null
        ? _formatNumber(product!.sellPrice!)
        : '';
    _quantityController.text = product != null
        ? product.quantity.toString()
        : '0';
    _optionNameController.text = product?.optionName ?? '';
    _optionValueController.text = product?.optionValue ?? '';
  }

  Future<void> _checkBarcodeDuplicate() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    final found = await widget.database.getProductByBarcode(barcode);
    if (found == null) {
      unawaited(_performLookup(barcode));
      return;
    }
    if (_currentProduct != null && found.id == _currentProduct!.id) return;
    if (!mounted) return;

    final action = await showDialog<_DuplicateAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Produit déjà existant'),
        content: Text('Ce produit existe déjà : ${found.name}'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DuplicateAction.createAnyway),
            child: const Text('Créer quand même'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_DuplicateAction.editExisting),
            child: const Text("Modifier l'existant"),
          ),
        ],
      ),
    );

    if (action == _DuplicateAction.editExisting && mounted) {
      setState(() {
        _currentProduct = found;
        _populateControllers(found);
      });
    }
  }

  /// Interroge les sources externes (via le cache local en priorité) pour
  /// préremplir nom, catégorie, description, SKU et contenance. Ne réécrit
  /// jamais un champ déjà renseigné et reste silencieuse si rien n'est
  /// trouvé.
  Future<void> _performLookup(String barcode) async {
    setState(() => _isLookingUp = true);

    LookupResult? result;
    try {
      result = await _lookupService.lookupBarcode(barcode);
    } catch (e, stack) {
      // Sans ce filet, une exception (ex. écriture du cache local) partait
      // dans un future non attendu : rien à l'écran, spinner bloqué.
      _log('$barcode · lookup en échec : $e\n$stack');
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }

    if (!mounted) {
      _log('$barcode · écran démonté, résultat ignoré');
      return;
    }
    if (result == null) {
      _log('$barcode · aucun résultat à appliquer');
      return;
    }
    _log('$barcode · résultat reçu : $result');

    // Champ du résultat → contrôleur cible. Un champ n'est appliqué que si
    // le résultat fournit une valeur non vide ET que le contrôleur est vide.
    final bindings = <(String, String?, TextEditingController)>[
      ('name', result.name, _nameController),
      ('category', result.category, _categoryController),
      ('description', result.description, _descriptionController),
      ('sku', result.sku, _skuController),
      ('optionCapacite', result.optionCapacite, _optionValueController),
    ];

    final applied = <String>[];
    final alreadyFilled = <String>[];
    final notProvided = <String>[];
    final toApply = <(TextEditingController, String)>[];
    for (final (field, value, controller) in bindings) {
      if (value == null || value.trim().isEmpty) {
        notProvided.add(field);
      } else if (controller.text.trim().isNotEmpty) {
        alreadyFilled.add('$field (contient "${controller.text}")');
      } else {
        toApply.add((controller, value.trim()));
        applied.add(field);
      }
    }

    if (toApply.isNotEmpty) {
      setState(() {
        for (final (controller, value) in toApply) {
          controller.text = value;
        }
        if (applied.contains('optionCapacite') &&
            _optionNameController.text.trim().isEmpty) {
          _optionNameController.text = 'Contenance';
        }
      });
    }

    _log(
      '$barcode · application au formulaire · '
      'mis à jour : ${applied.isEmpty ? "aucun" : applied.join(", ")} · '
      'ignorés car déjà remplis : '
      '${alreadyFilled.isEmpty ? "aucun" : alreadyFilled.join(", ")} · '
      'absents du résultat : '
      '${notProvided.isEmpty ? "aucun" : notProvided.join(", ")}',
    );

    await _maybeDownloadLookupPhoto(result);
  }

  /// Log de diagnostic (mode debug uniquement) du parcours d'un résultat de
  /// lookup entre sa réception et son application aux champs du formulaire.
  void _log(String message) {
    if (!kDebugMode) return;
    debugPrint('[ProductEntry] $message');
  }

  /// Télécharge et compresse la photo trouvée par la recherche externe
  /// (ex. Icecat), uniquement si le produit n'en a pas déjà une locale.
  /// Échoue silencieusement (réseau, image invalide...) sans perturber la
  /// saisie en cours.
  Future<void> _maybeDownloadLookupPhoto(LookupResult result) async {
    final imageUrl = result.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return;
    if (_photoPath != null && _photoPath!.isNotEmpty) return;

    final bytes = await _lookupService.downloadImage(imageUrl);
    if (bytes == null || !mounted) return;

    final savedPath = await _photoService.saveCompressed(
      bytes,
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim(),
    );
    if (savedPath == null || !mounted) return;
    // Une photo a pu être ajoutée manuellement pendant le téléchargement.
    if (_photoPath != null && _photoPath!.isNotEmpty) return;

    setState(() => _photoPath = savedPath);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _quantityController.dispose();
    _optionNameController.dispose();
    _optionValueController.dispose();
    _barcodeFocusNode.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString();
  }

  double? _parsePositiveDouble(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String? _validateRequiredPositivePrice(String? value) {
    final parsed = _parsePositiveDouble(value ?? '');
    if (parsed == null) return 'Prix invalide';
    if (parsed < 0) return 'Le prix doit être positif';
    return null;
  }

  String? _validateOptionalPositivePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _validateRequiredPositivePrice(value);
  }

  String? _validateQuantity(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Quantité obligatoire';
    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Quantité invalide';
    if (parsed < 0) return 'La quantité doit être positive';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Ni saisie manuelle ni lookup externe (Phase 10) n'ont fourni de SKU :
    // on en génère un plutôt que de bloquer l'enregistrement. Le champ est
    // rempli visiblement (setState) et la sauvegarde s'arrête là pour cette
    // pression sur le bouton : l'utilisatrice voit le SKU généré, peut le
    // modifier, puis confirme en appuyant à nouveau sur "Enregistrer".
    if (_skuController.text.trim().isEmpty) {
      final generatedSku = generateSafeSku();
      setState(() => _skuController.text = generatedSku);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SKU généré automatiquement : $generatedSku. '
            'Modifiez-le si besoin, puis appuyez de nouveau sur Enregistrer.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final barcode = _barcodeController.text.trim();
    final costPrice = _parsePositiveDouble(_costPriceController.text);
    final sellPrice = _parsePositiveDouble(_sellPriceController.text);
    final quantity = int.parse(_quantityController.text.trim());
    final optionName = _optionNameController.text.trim();
    final optionValue = _optionValueController.text.trim();

    final existing = _currentProduct;

    final companion = ProductsCompanion(
      id: existing != null ? Value(existing.id) : const Value.absent(),
      name: Value(name),
      sku: Value(sku.isEmpty ? null : sku),
      category: Value(category.isEmpty ? null : category),
      description: Value(description.isEmpty ? null : description),
      barcode: Value(barcode.isEmpty ? null : barcode),
      costPrice: Value(costPrice),
      sellPrice: Value(sellPrice),
      quantity: Value(quantity),
      optionName: Value(optionName.isEmpty ? null : optionName),
      optionValue: Value(optionValue.isEmpty ? null : optionValue),
      photoPath: Value(_photoPath),
      createdAt: existing != null ? Value(existing.createdAt) : Value(now),
      updatedAt: Value(now),
      syncedToLoyverse: existing != null
          ? Value(existing.syncedToLoyverse)
          : const Value(false),
      syncId: existing != null ? Value(existing.syncId) : const Value.absent(),
      remoteRevision: existing != null
          ? Value(existing.remoteRevision)
          : const Value.absent(),
      syncPending: const Value(true),
      // `update(...).replace(...)` remet à null les colonnes absentes : il
      // faut donc explicitement reporter la liaison Loyverse existante,
      // sous peine de la perdre à chaque modification du produit.
      loyverseItemId: existing != null
          ? Value(existing.loyverseItemId)
          : const Value.absent(),
      loyverseVariantId: existing != null
          ? Value(existing.loyverseVariantId)
          : const Value.absent(),
      groupId: existing != null
          ? Value(existing.groupId)
          : const Value.absent(),
      // Même raison : conserver la traçabilité d'import (et donc le
      // compteur "fiches importées à compléter" de l'accueil) après
      // modification d'une fiche importée.
      importSource: existing != null
          ? Value(existing.importSource)
          : const Value.absent(),
      importBatchId: existing != null
          ? Value(existing.importBatchId)
          : const Value.absent(),
    );

    if (existing != null) {
      await widget.database.updateProduct(companion);
    } else {
      await widget.database.insertProduct(companion);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _currentProduct != null;

    return Scaffold(
      backgroundColor: AppPalette.formBackground,
      appBar: _EntryAppBar(
        title: isEditing ? 'Modifier le produit' : 'Ajouter un produit',
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.isWideLayout
                  ? AppBreakpoints.wideFormMaxWidth
                  : 520,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Sections empilées en mobile (ordre de la maquette), en
                // deux colonnes sur grand écran : visuel et informations
                // générales à gauche, identification et tarifs à droite.
                if (context.isWideLayout)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildPhotoSection(),
                            const SizedBox(height: 20),
                            _buildGeneralInfoSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            _buildBarcodeSection(),
                            const SizedBox(height: 20),
                            _buildPricingSection(isEditing: isEditing),
                            const SizedBox(height: 20),
                            _buildVariantSection(),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildPhotoSection(),
                  const SizedBox(height: 20),
                  _buildGeneralInfoSection(),
                  const SizedBox(height: 20),
                  _buildBarcodeSection(),
                  const SizedBox(height: 20),
                  _buildPricingSection(isEditing: isEditing),
                  const SizedBox(height: 20),
                  _buildVariantSection(),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _SaveBar(
        enabled: !_isSaving,
        onSave: _save,
        label: isEditing
            ? 'Enregistrer les modifications'
            : 'Enregistrer le produit',
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _SectionCard(
      children: [
        const Text(
          'VISUEL DU PRODUIT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppPalette.muted,
          ),
        ),
        const SizedBox(height: 12),
        PhotoPickerField(
          photoPath: _photoPath,
          onChanged: (path) => setState(() => _photoPath = path),
          skuProvider: () => _skuController.text.trim(),
          barcodeProvider: () => _barcodeController.text.trim(),
        ),
      ],
    );
  }

  Widget _buildGeneralInfoSection() {
    return _SectionCard(
      header: const _SectionHeader(
        icon: Icons.description_outlined,
        title: 'Informations générales',
      ),
      children: [
        const _FieldLabel('Nom du produit', required: true),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          decoration: _fieldDecoration(hint: 'ex. Chemise en lin d\'été'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Le nom est obligatoire'
              : null,
        ),
        const SizedBox(height: 16),
        _FieldLabel(
          'SKU (Référence)',
          trailing: TextButton.icon(
            onPressed: _generateSku,
            icon: const Icon(Icons.autorenew, size: 14),
            label: const Text('Générer auto'),
            style: _linkButtonStyle,
          ),
        ),
        TextFormField(
          controller: _skuController,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['Consolas', 'Courier New'],
            letterSpacing: 0.5,
            fontSize: 14,
            color: AppPalette.text,
          ),
          decoration: _fieldDecoration(hint: 'ex. SKU-3F9A21C4'),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Catégorie'),
        _buildCategoryField(),
        const SizedBox(height: 16),
        _FieldLabel(
          'Description',
          trailing: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _descriptionController,
            builder: (context, value, _) {
              final length = value.text.length;
              return Text(
                '$length / $descriptionSoftLimit',
                style: TextStyle(
                  fontSize: 10,
                  color: length > descriptionSoftLimit
                      ? AppPalette.rose700
                      : AppPalette.muted,
                ),
              );
            },
          ),
        ),
        TextFormField(
          controller: _descriptionController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: _fieldDecoration(
            hint:
                'Décrivez les spécificités, matières, contenance, '
                'conseils d\'utilisation...',
          ),
        ),
      ],
    );
  }

  /// Champ Catégorie : texte libre avec autocomplétion sur les catégories
  /// déjà présentes en base. Le [LayoutBuilder] sert uniquement à donner à la
  /// liste de suggestions la largeur exacte du champ.
  Widget _buildCategoryField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: _categoryController,
          focusNode: _categoryFocusNode,
          optionsBuilder: _categoryOptions,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              onFieldSubmitted: (_) => onSubmitted(),
              // Loyverse rejette une catégorie au-delà de 64 caractères ;
              // bloquer la saisie ici évite l'échec (peu clair) au moment
              // de l'envoi.
              maxLength: 64,
              decoration: _fieldDecoration(
                hint: _knownCategories.isEmpty
                    ? 'ex. Soins du visage'
                    : 'Saisir ou choisir une catégorie existante',
                suffixIcon: const Icon(
                  Icons.expand_more,
                  color: AppPalette.muted,
                  size: 20,
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                shadowColor: AppPalette.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: constraints.maxWidth,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppPalette.text,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBarcodeSection() {
    return _SectionCard(
      children: [
        const _FieldLabel('Code-barres / EAN-13'),
        TextFormField(
          controller: _barcodeController,
          focusNode: _barcodeFocusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: ['Consolas', 'Courier New'],
            fontSize: 14,
            color: AppPalette.text,
          ),
          decoration: _fieldDecoration(
            hint: 'ex. 3760123456789',
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLookingUp)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: BarcodeScanButton(
                    onScanned: (value) {
                      _barcodeController.text = value;
                      _checkBarcodeDuplicate();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppPalette.primaryLight,
                      foregroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(44, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: AppPalette.badge),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Scannez l\'étiquette ou saisissez le code : la fiche est '
                'préremplie si le produit est connu.',
                style: TextStyle(fontSize: 11, color: AppPalette.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingSection({required bool isEditing}) {
    return _SectionCard(
      header: const _SectionHeader(
        icon: Icons.payments_outlined,
        title: 'Tarifs & quantités',
        iconBackground: AppPalette.greenTileBackground,
        iconForeground: AppPalette.greenTileForeground,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PriceField(
                label: 'Prix de revient',
                controller: _costPriceController,
                validator: _validateOptionalPositivePrice,
                emptyHint: 'Optionnel',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PriceField(
                label: 'Prix de vente',
                controller: _sellPriceController,
                validator: _validateRequiredPositivePrice,
                required: true,
                emphasized: true,
                emptyHint: 'Obligatoire',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: AppPalette.border.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Quantité en stock', required: true),
                  Text(
                    isEditing
                        ? 'Stock actuel du produit'
                        : 'Disponibilité initiale du produit',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _quantityController,
              builder: (context, value, _) {
                final quantity = int.tryParse(value.text.trim()) ?? 0;
                return _StockBadge(inStock: quantity > 0);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _StepperButton(
              icon: Icons.remove,
              tooltip: 'Diminuer la quantité',
              onPressed: () => _adjustQuantity(-1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.text,
                ),
                decoration: _fieldDecoration(hint: '0'),
                validator: _validateQuantity,
              ),
            ),
            const SizedBox(width: 8),
            _StepperButton(
              icon: Icons.add,
              tooltip: 'Augmenter la quantité',
              filled: true,
              onPressed: () => _adjustQuantity(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariantSection() {
    return _SectionCard(
      header: const _SectionHeader(
        icon: Icons.tune,
        title: 'Variante',
        subtitle: 'Taille, couleur, contenance...',
        iconBackground: AppPalette.purple50,
        trailing: _Tag(label: 'Optionnel'),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.fieldBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Option', muted: true),
                    TextFormField(
                      controller: _optionNameController,
                      decoration: _fieldDecoration(
                        hint: 'ex. Taille',
                        fillColor: AppPalette.surface,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Valeur', muted: true),
                    TextFormField(
                      controller: _optionValueController,
                      decoration: _fieldDecoration(
                        hint: 'ex. M ou Bleu',
                        fillColor: AppPalette.surface,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final _linkButtonStyle = TextButton.styleFrom(
    foregroundColor: AppPalette.primary,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  );
}

/// Décoration commune des champs du formulaire : fond très clair, bordure
/// fine arrondie, bordure violette au focus.
InputDecoration _fieldDecoration({
  String? hint,
  Widget? suffixIcon,
  String? suffixText,
  Color fillColor = AppPalette.fieldBackground,
  Color borderColor = AppPalette.border,
  bool dense = false,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(dense ? 8 : 12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: AppPalette.muted.withValues(alpha: 0.6),
      fontSize: dense ? 12 : 14,
      fontWeight: FontWeight.w400,
    ),
    filled: true,
    fillColor: fillColor,
    isDense: dense,
    contentPadding:
        contentPadding ??
        (dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppPalette.muted,
    ),
    enabledBorder: border(borderColor),
    focusedBorder: border(AppPalette.primary, 1.5),
    errorBorder: border(AppPalette.rose500),
    focusedErrorBorder: border(AppPalette.rose500, 1.5),
    errorStyle: const TextStyle(fontSize: 11, color: AppPalette.rose700),
  );
}

/// Barre supérieure : bouton retour rond blanc et titre centré, sur le fond
/// du formulaire.
class _EntryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EntryAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppPalette.formBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: 68,
      shape: Border(
        bottom: BorderSide(color: AppPalette.border.withValues(alpha: 0.4)),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Center(
          child: Material(
            color: AppPalette.surface,
            shape: const CircleBorder(
              side: BorderSide(color: AppPalette.border),
            ),
            elevation: 2,
            shadowColor: AppPalette.primary.withValues(alpha: 0.12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.arrow_back, size: 20, color: AppPalette.text),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppPalette.text,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// Barre du bas fixée : bouton d'enregistrement principal.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.onSave,
    required this.label,
  });

  final bool enabled;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppPalette.border.withValues(alpha: 0.8)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.06),
            offset: const Offset(0, -10),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          // heightFactor: 1 → la barre ne prend que la hauteur du bouton
          // (sans quoi Center s'étirerait sur toute la hauteur disponible).
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isWideLayout
                    ? AppBreakpoints.wideFormMaxWidth
                    : 520,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: enabled ? AppPalette.buttonShadow : null,
                ),
                child: FilledButton.icon(
                  onPressed: enabled ? onSave : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie regroupant une section du formulaire.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children, this.header});

  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.8)),
        boxShadow: AppPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 16)],
          ...children,
        ],
      ),
    );
  }
}

/// En-tête de section : vignette d'icône, titre, sous-titre et élément de
/// droite facultatifs.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconBackground = AppPalette.primaryLight,
    this.iconForeground = AppPalette.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color iconBackground;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconForeground),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.text,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Libellé au-dessus d'un champ, avec astérisque rose si obligatoire et un
/// élément optionnel aligné à droite (bouton, compteur...).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(
    this.text, {
    this.required = false,
    this.muted = false,
    this.trailing,
  });

  final String text;
  final bool required;
  final bool muted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: AppPalette.rose500,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      style: TextStyle(
        fontSize: muted ? 11 : 12,
        fontWeight: FontWeight.w600,
        color: muted ? AppPalette.muted : AppPalette.text,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: trailing == null
          ? label
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: label),
                const SizedBox(width: 8),
                trailing!,
              ],
            ),
    );
  }
}

/// Champ de prix avec suffixe devise ([kCurrencySymbol]) et, en dessous, le
/// montant formaté via [formatPrice] (ex. "12 500 FCFA") dès qu'une valeur
/// lisible est saisie.
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.validator,
    required this.emptyHint,
    this.required = false,
    this.emphasized = false,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final String emptyHint;
  final bool required;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label, required: required),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 14,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            color: emphasized ? AppPalette.primary : AppPalette.text,
          ),
          decoration: _fieldDecoration(
            hint: '0',
            suffixText: kCurrencySymbol,
            borderColor: emphasized
                ? AppPalette.primary.withValues(alpha: 0.4)
                : AppPalette.border,
          ),
          validator: validator,
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final parsed = double.tryParse(
              value.text.trim().replaceAll(',', '.'),
            );
            return Text(
              parsed == null ? emptyHint : formatPrice(parsed),
              style: const TextStyle(fontSize: 10, color: AppPalette.muted),
            );
          },
        ),
      ],
    );
  }
}

/// Pastille "En stock" / "Rupture", dérivée de la quantité saisie.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: inStock ? AppPalette.emerald50 : AppPalette.rose100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: inStock ? AppPalette.emerald200 : AppPalette.rose200,
        ),
      ),
      child: Text(
        inStock ? 'En stock' : 'Rupture',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: inStock ? AppPalette.emerald700 : AppPalette.rose700,
        ),
      ),
    );
  }
}

/// Bouton carré du stepper de quantité (− ou +).
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: filled ? AppPalette.primary : AppPalette.primarySubtle,
        foregroundColor: filled ? Colors.white : AppPalette.primary,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Petite étiquette grise ("Optionnel").
class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppPalette.muted,
        ),
      ),
    );
  }
}
