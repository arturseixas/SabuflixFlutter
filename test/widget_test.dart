import 'package:flutter_test/flutter_test.dart';
import 'package:sabuflix/main.dart';

void main() {
  testWidgets('Sabuflix app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SabuflixApp());
    expect(find.text('SABUFLIX'), findsWidgets);
  });
}
