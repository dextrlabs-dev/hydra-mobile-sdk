import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_demo/main.dart';

void main() {
  testWidgets('Hydra demo loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HydraDemoApp());
    expect(find.text('Hydra client demo'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
