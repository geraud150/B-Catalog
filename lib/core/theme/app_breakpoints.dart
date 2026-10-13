import 'package:flutter/widgets.dart';

/// Points de rupture de mise en page.
///
/// L'app garde sa mise en page mobile (colonne unique centrée, barre
/// d'onglets en bas) jusqu'à [desktop] inclus ; au-delà, les écrans étalent
/// leur contenu sur la largeur disponible (grilles multi-colonnes, rail de
/// navigation latéral). Aucune couleur, typographie ni composant ne change
/// entre les deux : seule la disposition s'adapte.
///
/// Le nombre de colonnes et la largeur maximale du contenu sont dérivés
/// d'une même mesure — la largeur d'une carte — pour qu'ils ne puissent pas
/// se contredire. Une version antérieure fixait les colonnes à partir de la
/// largeur de la fenêtre mais plafonnait le contenu à une constante : au
/// passage à trois colonnes, les cartes rétrécissaient et les noms de
/// produits se tronquaient alors que la fenêtre venait de s'agrandir.
abstract final class AppBreakpoints {
  /// Largeur (en pixels logiques) au-delà de laquelle la mise en page large
  /// s'applique. À 800 px ou moins, l'affichage reste strictement celui du
  /// mobile.
  static const desktop = 800.0;

  /// Largeur maximale du contenu en mise en page mobile : celle de la
  /// maquette, et aussi la largeur visée pour une carte sur grand écran.
  static const mobileContentMaxWidth = 520.0;

  /// Largeur maximale d'un formulaire en mise en page large (deux colonnes
  /// de champs). Un formulaire n'est pas une grille de cartes : sa largeur
  /// ne dépend pas du nombre de colonnes et reste donc une constante.
  static const wideFormMaxWidth = 960.0;

  /// Largeur confortable d'une carte : celle de la maquette mobile.
  static const _cardTargetWidth = mobileContentMaxWidth;

  /// Largeur en-deçà de laquelle une carte tronque les noms de produits un
  /// peu longs. C'est elle qui décide du nombre de colonnes : on n'en ajoute
  /// une que si toutes restent au-dessus de ce seuil.
  static const _cardMinWidth = 420.0;

  /// Écart entre deux colonnes, et marge horizontale des listes. Les écrans
  /// reprennent ces valeurs telles quelles : les garder ici évite que la
  /// largeur calculée et la largeur réellement occupée divergent.
  static const gap = 12.0;
  static const listPadding = 32.0;

  /// Place réservée au rail de navigation latéral. Les écrans poussés
  /// par-dessus le shell (fiche produit, aperçu d'import, récapitulatif)
  /// n'ont pas de rail et disposent donc d'un peu plus de place que ce
  /// calcul ne le suppose : l'écart joue en faveur de la lisibilité, jamais
  /// contre elle.
  static const railWidth = 88.0;

  static const _maxColumns = 3;

  static bool isWide(double width) => width > desktop;

  /// Largeur réellement offerte au contenu pour une fenêtre de [width].
  static double _availableWidth(double width) =>
      (isWide(width) ? width - railWidth : width) - listPadding;

  /// Nombre de colonnes de cartes pour une largeur de fenêtre donnée : 1 en
  /// mobile, puis autant de cartes d'au moins [_cardMinWidth] que la place
  /// disponible en accepte, dans la limite de [_maxColumns].
  ///
  /// Conséquence voulue : entre 801 et ~970 px (téléphone en paysage, petite
  /// tablette) on reste à une colonne. Deux y tenaient auparavant, mais à
  /// moins de 420 px chacune — donc avec des noms tronqués.
  static int columnsFor(double width) {
    if (!isWide(width)) return 1;
    final fits =
        ((_availableWidth(width) + gap) / (_cardMinWidth + gap)).floor();
    return fits.clamp(1, _maxColumns);
  }

  /// Largeur maximale du contenu pour une largeur de fenêtre donnée : de
  /// quoi loger [columnsFor] cartes à leur largeur confortable. Au-delà, le
  /// contenu reste centré plutôt que de s'étirer sur un écran 4K.
  ///
  /// Quand la fenêtre est trop étroite pour cette largeur idéale, c'est le
  /// parent qui borne : les cartes rétrécissent alors jusqu'à
  /// [_cardMinWidth] au pire, sans jamais passer en dessous puisque
  /// [columnsFor] n'ajoute une colonne qu'à cette condition.
  static double contentMaxWidthFor(double width) {
    final columns = columnsFor(width);
    if (columns == 1) return mobileContentMaxWidth;
    return columns * _cardTargetWidth + (columns - 1) * gap + listPadding;
  }
}

/// Raccourcis de mise en page dérivés de la largeur de la fenêtre.
extension ResponsiveContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  /// `true` au-delà de [AppBreakpoints.desktop].
  bool get isWideLayout => AppBreakpoints.isWide(_width);

  int get cardColumns => AppBreakpoints.columnsFor(_width);

  /// Largeur maximale du contenu, toujours cohérente avec [cardColumns].
  double get contentMaxWidth => AppBreakpoints.contentMaxWidthFor(_width);
}

/// Découpe [items] en rangées de [columns] éléments, pour afficher une
/// grille tout en conservant une `ListView` (et donc la virtualisation) sur
/// les longues listes.
List<List<T>> chunkIntoRows<T>(List<T> items, int columns) {
  if (columns <= 1) return [for (final item in items) [item]];
  return [
    for (var start = 0; start < items.length; start += columns)
      items.sublist(
        start,
        start + columns < items.length ? start + columns : items.length,
      ),
  ];
}
