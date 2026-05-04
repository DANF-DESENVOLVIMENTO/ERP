import 'package:erp_danf/app/erp_danf_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza a tela de erro de configuracao', (tester) async {
    await tester.pumpWidget(
      ErpDanfApp(
        firebaseInitializationError: StateError('Falha de teste'),
        runtimeErrorListenable: ValueNotifier<Object?>(null),
      ),
    );
    await tester.pump();

    expect(find.text('Firebase não configurado'), findsOneWidget);
    expect(find.textContaining('Falha de teste'), findsOneWidget);
  });
}
