import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sos_now/app.dart';
import 'package:sos_now/controller.dart';
import 'package:sos_now/format.dart';

void main() {
  test('server address gets a scheme and loses a trailing slash', () {
    expect(normalizeBase('192.168.1.20:8000/'), 'http://192.168.1.20:8000');
    expect(normalizeBase('http://10.0.2.2:8000'), 'http://10.0.2.2:8000');
  });

  testWidgets('login screen asks for a Nigerian phone number', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = SosController();
    await controller.load();
    await tester.pumpWidget(SosApp(controller: controller));
    await tester.pump();

    expect(find.text('SOS Now'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });
}
