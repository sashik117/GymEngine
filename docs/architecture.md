# Архітектура GymEngine

## Monorepo

```text
apps/mobile
services/api
infra/docker
docs
tools
```

## Mobile

Flutter відповідає за весь тренувальний досвід. Перший принцип - local-first: застосунок має працювати в залі навіть без мережі.

Поточна структура:

- `core`: тема, локалізація, форматування, спільні віджети.
- `domain`: моделі тренувань, вправ, аналітики.
- `data`: локальна база, репозиторії, майбутні API-клієнти.
- `presentation`: екрани, Cubit/BLoC-стан, UI-компоненти.

Локальне сховище:

- Drift/SQLite для тренувань, підходів, вправ, планів днів і sync-метаданих.
- Key-value сховище буде тільки для дрібних налаштувань, якщо знадобиться.

Поточні таблиці:

- `workout_sessions`
- `exercises`
- `workout_set_entries`
- `planned_workout_days`
- `planned_day_exercises`

Поточна локальна аналітика:

- тижневий об'єм;
- Smart History для обраної вправи;
- оцінений 1ПМ;
- об'єм за 7 днів;
- об'єм по групах м'язів.

## API

NestJS відповідає за акаунти, авторизацію, синхронізацію і серверну частину тренувальної логіки. API лишається тонким: контролери приймають HTTP-запити, сервіси оркеструють сценарії, а чиста логіка винесена в `domain`.

Поточні модулі:

- `auth`: реєстрація, підтвердження пошти, логін, скидання паролю.
- `sync`: local-first синхронізація даних користувача.
- `domain`: чисті моделі та алгоритми без NestJS, файлової системи і HTTP.

Backend layering:

```text
src/
├── domain/
│   ├── exercise.ts
│   ├── workout.ts
│   ├── workout-plan.ts
│   ├── progression-rule.ts
│   ├── progression-calculator.ts
│   └── workout-analytics.ts
├── auth/
│   ├── auth.service.ts              # сценарії авторизації
│   ├── auth-store.repository.ts     # читання/запис users.json
│   ├── password-hasher.service.ts   # PBKDF2 парольна логіка
│   ├── auth-token.service.ts        # bearer token
│   └── auth-code.service.ts         # email/reset коди
└── sync/
    ├── sync-query.service.ts        # read operations
    ├── sync-command.service.ts      # write operations
    ├── sync-snapshot.repository.ts  # файлове сховище snapshot
    ├── sync-snapshot.validator.ts   # shape validation
    └── sync-snapshot.metrics.ts     # counts/analytics
```

Принципи:

- `domain` не імпортує NestJS і не знає про HTTP.
- алгоритми на кшталт прогресії ваги живуть у чистих класах, наприклад `ProgressionCalculator.calculate()`;
- read/write sync-логіка розділена через `SyncQueryService` і `SyncCommandService`;
- старий `SyncService` лишається фасадом для сумісності, але не містить важкої логіки;
- auth-сценарії не займаються напряму хешуванням, токенами чи файловим записом.

## Синхронізація

Офлайн-сутності мають нести sync-метадані:

- `localId`
- `serverId`
- `createdAt`
- `updatedAt`
- `deletedAt`
- `syncStatus`

Мобільний застосунок спочатку пише локально. Синхронізація працює фоном і не блокує запис підходу.
