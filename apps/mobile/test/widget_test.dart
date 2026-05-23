import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_engine/data/local/app_database.dart';
import 'package:gym_engine/data/repos/workout_session_repository.dart';
import 'package:gym_engine/main.dart';

void main() {
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
    await tester.ensureVisible(find.text('Підтягування').first);
    await tester.tap(find.text('Підтягування').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЗБЕРЕГТИ ДЕНЬ'));
    await tester.pumpAndSettle();

    expect(find.text('Верх Тіла'), findsWidgets);
    expect(find.text('Жим лежачи'), findsWidgets);
    expect(find.text('ПОЧАТИ ТРЕНУВАННЯ'), findsOneWidget);

    await tester.ensureVisible(find.text('ПОЧАТИ ТРЕНУВАННЯ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ПОЧАТИ ТРЕНУВАННЯ'));
    await tester.pumpAndSettle();

    expect(find.text('ПІДЙОМ'), findsOneWidget);
    expect(find.text('Активна сесія'), findsOneWidget);
    expect(find.text('Жим лежачи'), findsWidgets);
    expect(find.text('РОЗУМНА ІСТОРІЯ'), findsOneWidget);
    expect(find.text('Ще не було підходів'), findsOneWidget);
    expect(find.text('ЗАПИСАТИ ПІДХІД'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('log-set-button')));
    await tester.tap(find.byKey(const ValueKey('log-set-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ВІДПОЧИНОК'), findsOneWidget);
    expect(find.text('1:30'), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('set-row-1')));
    await tester.pump();

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('60 КГ x 10'), findsWidgets);

    await tester.ensureVisible(find.text('НАСТУПНА ВПРАВА'));
    await tester.tap(find.text('НАСТУПНА ВПРАВА'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('log-set-button')));
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
    expect(find.text('60 КГ'), findsOneWidget);

    await tester.tap(find.text('НАЗАД ДО ГОЛОВНОЇ'));
    await tester.pumpAndSettle();

    expect(find.text('ГОЛОВНА'), findsWidgets);
    expect(find.text('ПІДСУМОК'), findsNothing);
    expect(find.text('КАЛЕНДАР'), findsOneWidget);

    await tester.tap(find.text('АНАЛІТИКА').last);
    await tester.pumpAndSettle();

    expect(find.text('Аналітика'), findsOneWidget);
    expect(find.text('ТРЕНУВАНЬ ЦЬОГО МІСЯЦЯ'), findsOneWidget);
    expect(find.text('КАЛЕНДАР ТРЕНУВАНЬ'), findsOneWidget);
    expect(find.textContaining('Травень 2026'), findsOneWidget);
    expect(find.text('ДЕНЬ ТРЕНУВАННЯ'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('ПРОГРЕС ПО ВПРАВАХ'), findsOneWidget);
    expect(find.text('МІН. ВАГА'), findsWidgets);
    expect(find.text('МАКС. ВАГА'), findsWidgets);
    expect(find.text('МІН. ПОВТ.'), findsWidgets);
    expect(find.text('МАКС. ПОВТ.'), findsWidgets);
    expect(find.text('60 КГ'), findsWidgets);

    await tester.tap(find.text('ПРОФІЛЬ').last);
    await tester.pumpAndSettle();

    expect(find.text('МІЙ ПРОФІЛЬ'), findsOneWidget);
    expect(find.text('НАЛАШТУВАННЯ'), findsOneWidget);
    expect(find.text('Увійшла як'), findsNothing);
    expect(find.text('ТРЕНУВАЛЬНІ ДАНІ'), findsOneWidget);
  });
}
