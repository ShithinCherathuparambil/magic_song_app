import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:magic_song/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end App Test', () {
    testWidgets('verify UI elements and interactions', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify core UI elements are present
      expect(find.text('Magic Song Studio'), findsOneWidget);
      expect(find.text('Tap to Record', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Vocal Processing Tools', skipOffstage: false),
        findsOneWidget,
      );

      // Verify that the preset list is present
      // E.g., Warm Melody should be a default or visible preset
      expect(find.text('Warm Melody', skipOffstage: false), findsWidgets);

      // Scroll the preset list to find 'Podcast' and tap it
      final presetList = find.byType(ListView).first;
      await tester.drag(presetList, const Offset(-300, 0));
      await tester.pumpAndSettle();

      final podcastCard = find.text('Podcast', skipOffstage: false);
      if (podcastCard.evaluate().isNotEmpty) {
        await tester.tap(podcastCard.first);
        await tester.pumpAndSettle();
      }

      // Verify manual toggle switch exists
      final manualSwitch = find.byType(Switch);
      expect(manualSwitch, findsOneWidget);

      // Toggle Manual Mode ON
      await tester.tap(manualSwitch);
      await tester.pumpAndSettle();

      // Verify sliders are visible
      expect(find.text('Bass', skipOffstage: false), findsWidgets);
      expect(find.text('Mid', skipOffstage: false), findsWidgets);
      expect(find.text('Treble', skipOffstage: false), findsWidgets);
      expect(find.text('Studio Reverb', skipOffstage: false), findsWidgets);

      // Verify Record Button exists
      final recordButton = find.byIcon(Icons.mic_rounded);
      expect(recordButton, findsOneWidget);
    });
  });
}
