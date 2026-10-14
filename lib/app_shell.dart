import 'package:flutter/material.dart';

import 'core/app_version.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_breakpoints.dart';
import 'core/theme/app_palette.dart';
import 'features/home/home_screen.dart';
import 'features/import/import_hub_screen.dart';
import 'features/product_list/product_list_screen.dart';
import 'features/sync/catalog_auto_sync.dart';

/// Racine de la navigation : trois destinations (Accueil / Produits /
/// Import), chacune conservant son état grâce à [IndexedStack]. Les écrans
/// de détail (saisie, aperçu d'import, récapitulatif...) sont poussés
/// par-dessus le shell avec le navigateur racine et masquent donc la
/// navigation le temps de leur affichage.
///
/// La navigation prend deux formes selon la largeur disponible : barre
/// d'onglets en bas jusqu'à [AppBreakpoints.desktop], rail latéral au-delà
/// (une barre du bas étirée sur toute la largeur d'un écran d'ordinateur
/// paraissait disproportionnée). Les destinations, leurs icônes et leurs
/// libellés sont identiques dans les deux cas.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.database});

  final AppDatabase database;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _homeIndex = 0;
  static const _productsIndex = 1;

  late final CatalogAutoSync _autoSync = CatalogAutoSync(
    database: widget.database,
  )..start();

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Accueil'),
    (
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2,
      label: 'Produits',
    ),
    // Le libellé couvre les deux flux de l'onglet : l'import d'un .docx et
    // l'export CSV / la synchronisation Loyverse.
    (
      icon: Icons.cloud_upload_outlined,
      selected: Icons.cloud_upload,
      label: 'Import / Export',
    ),
  ];

  int _selectedIndex = _homeIndex;

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Après le premier affichage plutôt que dans initState : _autoSync lit
    // la session Supabase courante, pas encore utile avant que l'app existe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync.trigger());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoSync.trigger();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _selectedIndex,
      children: [
        HomeScreen(
          database: widget.database,
          onShowProducts: () => _select(_productsIndex),
        ),
        ProductListScreen(database: widget.database),
        ImportHubScreen(
          database: widget.database,
          syncError: _autoSync.lastError,
        ),
      ],
    );

    if (context.isWideLayout) {
      return Scaffold(
        body: Row(
          children: [
            _NavigationRail(selectedIndex: _selectedIndex, onSelected: _select),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      // Couleurs, hauteur et typographie de la barre viennent du
      // `navigationBarTheme` global (voir core/theme/app_theme.dart) : seul
      // le filet de séparation reste ici, faute d'équivalent dans le thème.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppPalette.purple100.withValues(alpha: 0.8),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selected),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Rail de navigation latéral (mise en page large), avec le même filet de
/// séparation que la barre du bas, posé cette fois sur son bord droit.
class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Même fond que le rail : la mention de version vit sous lui, hors
        // de la zone qu'il peint lui-même.
        color: AppPalette.surface,
        border: Border(
          right: BorderSide(
            color: AppPalette.purple100.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Column(
        children: [
          // La mention est posée sous le rail plutôt que dans son
          // `trailing` : là-bas, l'Expanded nécessaire pour la plaquer en
          // bas neutralise `groupAlignment` et fait remonter les
          // destinations d'une trentaine de pixels.
          Expanded(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              labelType: NavigationRailLabelType.all,
              minWidth: 88,
              groupAlignment: -0.85,
              destinations: [
                for (final destination in _AppShellState._destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selected),
                    label: Text(destination.label),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8, right: 8, bottom: 14),
            child: AppVersionLabel(),
          ),
        ],
      ),
    );
  }
}
