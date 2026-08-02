import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('boots into the profile chooser', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SabuflixApp());
    // Two pumps: one for the first frame, one for the profile provider's
    // asynchronous load to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Quem está assistindo?'), findsOneWidget);
  });
}
