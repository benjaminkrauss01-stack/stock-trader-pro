import 'package:flutter_test/flutter_test.dart';
import 'package:stock_trader_pro/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const StockTraderApp());
    expect(find.text('Stock Trader Pro'), findsOneWidget);
  });
}
