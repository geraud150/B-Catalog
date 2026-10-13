import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Boîte de dialogue de confirmation avant suppression définitive d'un
/// produit, d'après la maquette Stitch "Confirmation de suppression".
///
/// Volontairement épurée par rapport à la maquette : seuls le nom du produit
/// et l'avertissement d'irréversibilité sont affichés (ni vignette photo, ni
/// prix, ni quantité), pour que la décision porte sur l'identité de la fiche
/// et non sur des chiffres qui n'entrent pas en jeu.
///
/// Retourne `true` si la suppression est confirmée, `false` ou `null` sinon
/// (annulation, retour arrière, clic hors de la boîte).
Future<bool> confirmDeleteProduct(
  BuildContext context, {
  required String productName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x991B1229),
    builder: (dialogContext) => _ConfirmDeleteDialog(productName: productName),
  );
  return confirmed ?? false;
}

class _ConfirmDeleteDialog extends StatelessWidget {
  const _ConfirmDeleteDialog({required this.productName});

  final String productName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppPalette.rose100.withValues(alpha: 0.7)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 342),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vignette corbeille entourée d'un anneau rose.
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppPalette.rose50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppPalette.rose100.withValues(alpha: 0.6),
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 28,
                  color: AppPalette.rose500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Supprimer ce produit ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.slate900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.rose50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppPalette.rose200.withValues(alpha: 0.7),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: AppPalette.rose500,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Action irréversible',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.rose600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '« $productName »',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.slate800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cette action est irréversible et retirera définitivement '
                'la fiche de votre catalogue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppPalette.slate500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        backgroundColor: AppPalette.slate100,
                        foregroundColor: AppPalette.slate700,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Supprimer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
