import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Génère les sources de l'icône d'application à partir du visuel réellement
/// affiché dans l'en-tête de l'accueil (vignette violette + icône carton).
///
/// Ce n'est pas un test : c'est un générateur, volontairement placé hors de
/// `test/` pour ne pas tourner avec la suite. Il s'exécute via le moteur de
/// rendu de Flutter, ce qui garantit que le glyphe Material dessiné est
/// exactement celui de l'app plutôt qu'un dessin approché :
///
/// ```
/// flutter test tool/generate_app_icon.dart
/// ```
///
/// Produit :
/// - `assets/icon/app_icon.png` : carré plein 1024×1024 (fond violet,
///   icône blanche centrée). C'est le lanceur qui applique ensuite son
///   masque (coins arrondis sous Windows, cercle ou squircle sous Android).
/// - `assets/icon/app_icon_foreground.png` : la même icône blanche sur fond
///   transparent, avec la marge de sécurité des icônes adaptatives Android
///   (le fond est alors fourni par `adaptive_icon_background`).
/// - `assets/icon/app_icon_windows.png` : variante au glyphe nettement plus
///   large, lisible une fois réduite à 16 px.
/// - `windows/runner/resources/app_icon.ico` : le fichier réellement utilisé
///   par la fenêtre et la barre des tâches, en 16/32/48/256 px. Il est écrit
///   directement ici et non par `flutter_launcher_icons`, qui n'y place
///   qu'une seule image de 256 px.
void main() {
  const size = 1024.0;

  // Le harnais de test remplace les polices par une police de substitution :
  // sans ce chargement, le glyphe Material sort en carré vide. La police est
  // prise dans le cache du SDK Flutter, retrouvé depuis l'exécutable Dart en
  // cours (<sdk>/bin/cache/dart-sdk/bin/dart).
  setUpAll(() async {
    const relativePath =
        'bin/cache/artifacts/material_fonts/materialicons-regular.otf';
    File? font;
    for (
      var directory = File(Platform.resolvedExecutable).parent;
      font == null && directory.path != directory.parent.path;
      directory = directory.parent
    ) {
      final candidate = File('${directory.path}/$relativePath');
      if (candidate.existsSync()) font = candidate;
    }
    if (font == null) {
      throw StateError(
        'Police Material introuvable sous la racine du SDK Flutter '
        '($relativePath). Lancez `flutter precache`.',
      );
    }

    final loader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
    await loader.load();
  });

  /// Violet de l'en-tête, tel que demandé pour l'icône.
  const background = Color(0xFF5A4B81);

  /// Proportion occupée par le carton, calibrée pour que l'icône pèse
  /// autant que celles des autres applications du lanceur :
  /// - carré plein (Windows, Android hérité) : 66 % du côté ;
  /// - premier plan adaptatif : 62 % de la toile, réduits ensuite par
  ///   l'encart de 16 % du XML puis par le masque du lanceur (~66 % du
  ///   centre), soit environ 63 % de l'icône finalement visible.
  Future<void> render(
    WidgetTester tester, {
    required String fileName,
    required Color? backgroundColor,
    required double iconRatio,
  }) async {
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(size, size)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: size,
              height: size,
              child: ColoredBox(
                color: backgroundColor ?? const Color(0x00000000),
                child: Center(
                  child: Icon(
                    // Même icône que la vignette de l'en-tête d'accueil :
                    // le glyphe `store` du lockup de la maquette Stitch.
                    Icons.store,
                    size: size * iconRatio,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // L'encodage PNG passe par le moteur : il doit tourner hors du temps
    // simulé du harnais de test, sans quoi le future ne se résout jamais.
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      final file = File(fileName);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      debugPrint('[app_icon] écrit : ${file.path} (${bytes.lengthInBytes} o)');
    });
  }

  testWidgets('génère app_icon.png', (tester) async {
    await render(
      tester,
      fileName: 'assets/icon/app_icon.png',
      backgroundColor: background,
      iconRatio: 0.66,
    );
  });

  testWidgets('génère app_icon_foreground.png', (tester) async {
    await render(
      tester,
      fileName: 'assets/icon/app_icon_foreground.png',
      backgroundColor: null,
      iconRatio: 0.62,
    );
  });

  testWidgets('génère app_icon_windows.png', (tester) async {
    // Source dédiée à la barre des tâches. Le glyphe y occupe nettement plus
    // de place que sur le lanceur : à 16 px, les 34 % de marge de la version
    // 0.66 ne laissaient qu'une dizaine de pixels de dessin, d'où une icône
    // qui paraissait minuscule. Windows n'ajoute aucune marge de son côté,
    // contrairement aux masques de lanceur Android.
    await render(
      tester,
      fileName: 'assets/icon/app_icon_windows.png',
      backgroundColor: background,
      iconRatio: 0.84,
    );
  });

  testWidgets('génère le .ico multi-résolutions de Windows', (tester) async {
    await tester.runAsync(() async {
      final source = img.decodePng(
        await File('assets/icon/app_icon_windows.png').readAsBytes(),
      );
      if (source == null) {
        throw StateError('assets/icon/app_icon_windows.png illisible');
      }

      // Les quatre tailles que Windows pioche selon le contexte : barre des
      // tâches et petites listes (16), bureau et Alt+Tab (32, 48), tuiles et
      // aperçus (256). Sans elles, Windows réduit lui-même le 256 et le
      // résultat bave aux petites tailles.
      const sizes = [16, 32, 48, 256];
      final frames = [
        for (final side in sizes)
          img.copyResize(
            source,
            width: side,
            height: side,
            // Ré-échantillonnage moyenné : sur un aplat violet traversé de
            // traits blancs fins, c'est ce qui préserve le mieux le dessin
            // à 16 px.
            interpolation: img.Interpolation.average,
          ),
      ];

      // `encodeIco` n'écrit qu'une image : c'est `encodeImages` qui empile
      // les quatre résolutions dans un seul .ico.
      final file = File('windows/runner/resources/app_icon.ico');
      await file.writeAsBytes(img.IcoEncoder().encodeImages(frames));
      debugPrint(
        '[app_icon] écrit : ${file.path} '
        '(${sizes.join('/')} px, ${await file.length()} o)',
      );
    });
  });
}
