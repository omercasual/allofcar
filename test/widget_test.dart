import 'package:flutter_test/flutter_test.dart';
import 'package:allofcar/main.dart'; // Proje isminle uyumlu import

void main() {
  testWidgets('Uygulama çökmeden açılıyor mu testi', (
    WidgetTester tester,
  ) async {
    // Uygulamayı sanal ortamda başlat
    await tester.pumpWidget(const AllofCarApp());

    // Ekranda 'AllofCar' yazısını arar, bulursa test geçer
    expect(find.text('AllofCar'), findsOneWidget);
  });
}
