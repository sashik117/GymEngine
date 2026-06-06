import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_engine/data/local/app_database.dart';
import 'package:gym_engine/data/repos/workout_session_repository.dart';
import 'package:gym_engine/main.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('starts with a compact login and switches to registration', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      GymEngineApp(sessionRepository: WorkoutSessionRepository(database)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ВХІД'), findsWidgets);
    expect(find.text('Пошта'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Імʼя'), findsNothing);
    expect(find.text('Повтор паролю'), findsNothing);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.tap(find.text('РЕЄСТРАЦІЯ').last);
    await tester.pumpAndSettle();

    expect(find.text('РЕЄСТРАЦІЯ'), findsWidgets);
    expect(find.text('Імʼя'), findsOneWidget);
    expect(find.text('Повтор паролю'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNWidgets(2));
  });

  testWidgets('builds a Ukrainian day plan and logs a planned session', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      GymEngineApp(
        sessionRepository: WorkoutSessionRepository(database),
        skipAuthGate: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GYMENGINE'), findsOneWidget);
    expect(find.text('ГОЛОВНА'), findsWidgets);
    expect(find.text('СТВОРИТИ ДЕНЬ'), findsWidgets);

    await tester.tap(find.text('СТВОРИТИ ДЕНЬ').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Верх Тіла');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Жим лежачи').first);
    await tester.tap(find.text('Жим лежачи').first);
    await tester.tap(find.text('ДОДАТИ ВПРАВУ').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Пошук вправи'),
      'Підтягування',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Підтягування').first);
    final pullUpAddButton = find.byKey(const ValueKey('catalog-add-pull_up'));
    await tester.ensureVisible(pullUpAddButton);
    await tester.pumpAndSettle();
    await tester.tap(pullUpAddButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЗБЕРЕГТИ ДЕНЬ'));
    await tester.pumpAndSettle();

    expect(find.text('Верх Тіла'), findsWidgets);
    expect(find.text('Жим лежачи'), findsWidgets);
    expect(find.text('ПОЧАТИ'), findsOneWidget);

    await tester.ensureVisible(find.text('ПОЧАТИ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ПОЧАТИ'));
    await tester.pumpAndSettle();

    expect(find.text('ПІДЙОМ'), findsOneWidget);
    expect(find.text('Активна сесія'), findsOneWidget);
    expect(find.text('Жим лежачи'), findsWidgets);
    expect(find.text('РОЗУМНА ІСТОРІЯ'), findsOneWidget);
    expect(find.text('Ще не було підходів'), findsOneWidget);
    expect(find.text('ЗАПИСАТИ ПІДХІД'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('log-set-button')));
    await tester.enterText(find.byKey(const ValueKey('weight-input')), '20');
    await tester.drag(
      find.byKey(const ValueKey('active-session-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-set-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ВІДПОЧИНОК'), findsOneWidget);
    expect(find.textContaining(RegExp(r'1:2[89]|1:30')), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('set-row-1')));
    await tester.pump();

    expect(find.text('1.'), findsOneWidget);
    expect(find.textContaining('20 КГ x'), findsWidgets);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('weight-input')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '20',
    );

    await tester.ensureVisible(find.text('НАСТУПНА ВПРАВА'));
    await tester.tap(find.text('НАСТУПНА ВПРАВА'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('log-set-button')));
    await tester.enterText(find.byKey(const ValueKey('weight-input')), '40');
    await tester.drag(
      find.byKey(const ValueKey('active-session-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-set-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.byKey(const ValueKey('set-row-2')));
    await tester.pump();

    expect(find.text('1.'), findsNWidgets(2));

    await tester.tap(find.text('ЗАВЕРШИТИ ТРЕНУВАННЯ'));
    await tester.pumpAndSettle();

    expect(find.text('ПІДСУМОК'), findsOneWidget);
    expect(find.text('Тренування закрито'), findsOneWidget);
    expect(find.text('40 КГ'), findsOneWidget);

    await tester.tap(find.text('НАЗАД ДО ГОЛОВНОЇ'));
    await tester.pumpAndSettle();

    expect(find.text('ГОЛОВНА'), findsWidgets);
    expect(find.text('ПІДСУМОК'), findsNothing);
    expect(find.text('КАЛЕНДАР'), findsOneWidget);

    await tester.tap(find.text('ПРОГРЕС').last);
    await tester.pumpAndSettle();

    expect(find.text('Прогрес'), findsOneWidget);
    expect(find.text('ТРЕНУВАНЬ ЦЬОГО МІСЯЦЯ'), findsOneWidget);

    for (var scroll = 0; scroll < 5; scroll += 1) {
      if (find.text('КАЛЕНДАР ТРЕНУВАНЬ').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(
        find.byKey(const ValueKey('progress-scroll')),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('КАЛЕНДАР ТРЕНУВАНЬ'), findsOneWidget);

    expect(find.textContaining(_ukMonthTitle(DateTime.now())), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('progress-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    expect(find.text('ДЕНЬ ТРЕНУВАННЯ'), findsOneWidget);

    for (var scroll = 0; scroll < 5; scroll += 1) {
      if (find.text('Вправи').evaluate().isNotEmpty) {
        break;
      }
      await tester.drag(
        find.byKey(const ValueKey('progress-scroll')),
        const Offset(0, 520),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Вправи').last);
    await tester.pumpAndSettle();

    expect(find.text('ПРОГРЕС ПО ВПРАВАХ'), findsOneWidget);
    expect(find.text('МІН. ВАГА'), findsWidgets);
    expect(find.text('МАКС. ВАГА'), findsWidgets);
    expect(find.text('МІН. ПОВТ.'), findsWidgets);
    expect(find.text('МАКС. ПОВТ.'), findsWidgets);
    expect(find.text('40 КГ'), findsWidgets);

    await tester.tap(find.text('ПРОФІЛЬ').last);
    await tester.pumpAndSettle();

    expect(find.text('МІЙ ПРОФІЛЬ'), findsOneWidget);
    expect(find.text('НАЛАШТУВАННЯ'), findsOneWidget);
    expect(find.text('Увійшла як'), findsNothing);
    expect(find.text('ТРЕНУВАЛЬНІ ДАНІ'), findsOneWidget);
  });
}

String _ukMonthTitle(DateTime date) {
  const months = [
    'Січень',
    'Лютий',
    'Березень',
    'Квітень',
    'Травень',
    'Червень',
    'Липень',
    'Серпень',
    'Вересень',
    'Жовтень',
    'Листопад',
    'Грудень',
  ];

  return '${months[date.month - 1]} ${date.year}';
}
