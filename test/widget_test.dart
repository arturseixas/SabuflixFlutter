import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Sabuflix app smoke test', (WidgetTester tester) async {
    // The profile picker hydrates from shared preferences before it can paint
    // anything, so the test needs a store to read from.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SabuflixApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The app opens on the profile picker.
    expect(find.text('Quem está assistindo?'), findsOneWidget);
  });
}
