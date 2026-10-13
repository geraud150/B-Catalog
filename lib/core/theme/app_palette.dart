import 'package:flutter/material.dart';

/// Couleurs et ombres des maquettes Stitch (accueil, ajout de produit).
///
/// Volontairement appliquées écran par écran plutôt que via le thème
/// global : les écrans pas encore retravaillés (liste, récapitulatif,
/// aperçu d'import) gardent leur apparence Material par défaut.
abstract final class AppPalette {
  static const background = Color(0xFFFAF7FD);
  static const surface = Colors.white;

  // Violet de marque (maquette "Tableau de bord").
  static const brand50 = Color(0xFFF6F2FC);
  static const brand100 = Color(0xFFEDE6FA);
  static const brand200 = Color(0xFFDCCEF7);
  static const brand300 = Color(0xFFC2ABEF);
  static const brand500 = Color(0xFF7E61A8);
  static const brand600 = Color(0xFF64488C);
  static const brand700 = Color(0xFF553C76);
  static const brand800 = Color(0xFF463261);
  static const brand900 = Color(0xFF342549);

  // Tokens de la maquette "Ajouter un produit" (formulaire).
  static const formBackground = Color(0xFFF8F6FB);
  static const primary = Color(0xFF604C82);
  static const primaryHover = Color(0xFF513F6E);
  static const primaryLight = Color(0xFFEFEAF7);
  static const primarySubtle = Color(0xFFF4F0FA);
  static const text = Color(0xFF1C162E);
  static const muted = Color(0xFF736B82);
  static const border = Color(0xFFE8E2EE);
  static const borderSubtle = Color(0xFFF0EAF5);
  static const fieldBackground = Color(0xFFFAF9FC);
  static const badge = Color(0xFF8974AC);

  static const rose50 = Color(0xFFFFF1F2);
  static const rose100 = Color(0xFFFCE7EC);
  static const rose200 = Color(0xFFF8CBD4);
  static const rose500 = Color(0xFFE06D85);
  static const rose600 = Color(0xFFE11D48);
  static const rose700 = Color(0xFF9E3249);

  // Tokens de la maquette "Vérifier et exporter" (alertes d'incomplétude,
  // badge "En attente").
  static const alertBackground = Color(0xFFFEE2E2);
  static const alertBorder = Color(0xFFFECACA);
  static const danger = Color(0xFFE11D48);
  static const pink100 = Color(0xFFFCE4EC);
  static const pink200 = Color(0xFFFBCFE8);
  static const pink500 = Color(0xFFEC4899);
  static const pink700 = Color(0xFFBE185D);

  // Bordure très claire des cartes de la liste des produits.
  static const cardBorder = Color(0xFFF0EDF6);
  static const listBackground = Color(0xFFFAF8FC);

  static const purple50 = Color(0xFFFAF5FF);
  static const purple100 = Color(0xFFF3E8FF);
  static const purple200 = Color(0xFFE9D5FF);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const greenTileBackground = Color(0xFFE6F4EA);
  static const greenTileForeground = Color(0xFF1E7E34);

  /// Ombre "soft" des cartes blanches.
  static const softShadow = [
    BoxShadow(
      color: Color(0x14604A7B),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0A604A7B),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  /// Ombre "card" des sections du formulaire.
  static const cardShadow = [
    BoxShadow(
      color: Color(0x0D604C82),
      offset: Offset(0, 10),
      blurRadius: 25,
      spreadRadius: -5,
    ),
    BoxShadow(
      color: Color(0x08604C82),
      offset: Offset(0, 8),
      blurRadius: 10,
      spreadRadius: -6,
    ),
  ];

  /// Ombre colorée de la carte d'action principale.
  static const primaryShadow = [
    BoxShadow(
      color: Color(0x59553C76),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -3,
    ),
  ];

  /// Ombre du bouton flottant "Ajouter" de la liste des produits.
  static const floatingShadow = [
    BoxShadow(
      color: Color(0x595E4B8B),
      offset: Offset(0, 10),
      blurRadius: 25,
      spreadRadius: -4,
    ),
  ];

  /// Ombre portée vers le haut de la barre d'actions fixée en bas.
  static const bottomBarShadow = [
    BoxShadow(
      color: Color(0x14614F8A),
      offset: Offset(0, -8),
      blurRadius: 26,
      spreadRadius: -2,
    ),
  ];

  /// Ombre du bouton principal du formulaire.
  static const buttonShadow = [
    BoxShadow(
      color: Color(0x59604C82),
      offset: Offset(0, 8),
      blurRadius: 18,
      spreadRadius: -4,
    ),
  ];
}
