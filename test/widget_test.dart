import 'package:erp_danf/app/erp_danf_app.dart';
import 'package:erp_danf/models/erp_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserva título e colaboradores da agenda de engenharia', () {
    final scheduledAt = DateTime(2026, 9, 1, 9, 30);
    final schedule = EngineeringTaskSchedule(
      scheduledAt: scheduledAt,
      notes: 'Alinhar entregas',
      title: 'Reunião semanal',
      collaborators: const ['Ana', 'Carlos'],
      createdBy: 'Daniel',
    );

    final restored = EngineeringTaskSchedule.fromMap(schedule.toMap());

    expect(restored.scheduledAt, scheduledAt);
    expect(restored.title, 'Reunião semanal');
    expect(restored.collaborators, ['Ana', 'Carlos']);
    expect(restored.createdBy, 'Daniel');
  });

  test('migra a chave reservada da agenda pessoal antes de salvar', () {
    final orderMap = <String, dynamic>{
      'code': 'TEST-1',
      'engineeringActivitySchedules': {
        '__personal_engineering__': {
          'scheduledAt': DateTime(2026, 9, 1, 9),
          'notes': '',
          'title': 'Planejamento',
          'collaborators': <String>[],
        },
      },
      'clientReports': [
        {
          'id': 'report-1',
          'authorEmail': 'autor@danf.com',
          'authorName': 'Autor',
          'message': 'Cliente solicitou retorno.',
          'createdAt': DateTime(2026, 9, 1, 10),
          'mentionedUserEmails': <String>[],
          'readByUserEmails': <String>[],
        },
      ],
    };

    final restored = WorkflowOrder.fromMap(orderMap);
    final serializedSchedules =
        restored.toMap()['engineeringActivitySchedules']! as Map;

    expect(serializedSchedules, contains('personal_engineering'));
    expect(serializedSchedules, isNot(contains('__personal_engineering__')));
    expect(restored.clientReports, hasLength(1));
    expect(restored.clientReports.single.authorName, 'Autor');
    expect(restored.clientReports.single.message, 'Cliente solicitou retorno.');
    expect(restored.hasElectricalProject, 'Não');
  });

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
