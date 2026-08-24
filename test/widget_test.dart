import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Sabuflix app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SabuflixApp());
    await tester.pumpAndSettle();
    expect(find.text('Quem está assistindo?'), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget);
  });
}
