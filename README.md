# GymEngine

GymEngine - мобільний комплекс для силових тренувань: швидкий запис підходів, офлайн-надійність і аналітика прогресу без зайвого шуму.

Напрям продукту:

- темний industrial/brutal UI;
- українська мова за замовчуванням + перемикач `УКР | ENG`;
- розклад тренувань по днях тижня;
- мінімум кліків під час роботи в залі;
- локальне збереження сесій;
- бекенд-аналітика після синхронізації.

## Структура

```text
apps/mobile       Flutter-клієнт
services/api      NestJS API
infra/docker      Локальна інфраструктура
docs              Нотатки по продукту й тестуванню
src/flutter       Локальний Flutter SDK, ігнорується git
```

## Flutter Локально

У цьому workspace використовується Flutter SDK з `src/flutter`.

```powershell
.\tools\flutter.ps1 --version
```

Запуск мобільного застосунку:

```powershell
cd apps\mobile
..\..\tools\flutter.ps1 pub get
..\..\tools\flutter.ps1 run
```

На Windows для Flutter-плагінів може знадобитися Developer Mode через symlink-и.
