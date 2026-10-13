import 'package:boutique_catalog/core/widgets/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/themed_app.dart';

void main() {
  Future<bool?> showAndTap(WidgetTester tester, String? buttonLabel) async {
    bool? result;
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await confirmDeleteProduct(
                  context,
                  productName: 'Casque Bluetooth Orion',
                );
              },
              child: const Text('supprimer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ce produit ?'), findsOneWidget);
    expect(find.text('Action irréversible'), findsOneWidget);
    expect(find.text('« Casque Bluetooth Orion »'), findsOneWidget);
    expect(find.textContaining('irréversible et retirera'), findsOneWidget);

    // Volontairement épuré : ni vignette photo, ni prix, ni quantité.
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('FCFA'), findsNothing);
    expect(find.textContaining('Qté'), findsNothing);

    if (buttonLabel != null) {
      await tester.tap(find.text(buttonLabel));
      await tester.pumpAndSettle();
    }
    return result;
  }

  testWidgets('"Supprimer" confirme la suppression', (tester) async {
    expect(await showAndTap(tester, 'Supprimer'), isTrue);
  });

  testWidgets('"Annuler" refuse la suppression', (tester) async {
    expect(await showAndTap(tester, 'Annuler'), isFalse);
  });

  testWidgets('une fermeture hors bouton vaut refus', (tester) async {
    await showAndTap(tester, null);
    // Retour arrière (équivalent d'un clic hors de la boîte).
    Navigator.of(tester.element(find.text('Supprimer'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce produit ?'), findsNothing);
  });
}
