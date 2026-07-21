# SSD Manager Agent Guide

This file gives Codex durable project context. Keep it short, practical, and in sync with `docs/PROJECT_CONTEXT.md`.

## Project Summary

SSD Manager is a Flutter mobile app plus PHP/MySQL backend for a school first-aid service. It manages duty planning, announcements, first-aider lists, profiles, device sessions, roles, and administration workflows for student first-aiders, lead first-aiders, and teacher supervision.

The current repository is the source of truth. Historical Codex chats are local to the original PC and should not be treated as portable project state. Important decisions from those chats are captured in `docs/PROJECT_CONTEXT.md`.

## Stack

- Flutter/Dart for Android and iOS.
- Riverpod for app state/providers.
- PHP 8.2+ backend without a required Composer setup.
- MySQL/MariaDB schema and seed data in `backend/database`.
- REST API under `/api/v1`.
- Firebase Cloud Messaging is prepared but optional unless Firebase files and backend service-account settings are present.

## Important Paths

- `lib/`: Flutter app code.
- `lib/core`: API, device, push, and session infrastructure.
- `lib/providers`: Riverpod providers.
- `lib/repositories`: API-facing repositories.
- `lib/screens`: user-facing app screens.
- `backend/public`: PHP web root.
- `backend/src`: backend controllers, core classes, and services.
- `backend/database`: migrations and seed data.
- `backend/cron`: scheduled backend jobs.
- `backend/scripts`: CLI helper scripts.
- `docs`: architecture, API, deployment, Firebase, roles, security, and project context.

## Commands

Install Flutter dependencies:

```bash
flutter pub get
```

Run Flutter checks:

```bash
flutter analyze
flutter test
```

Run the local backend after creating `backend/.env` and a database:

```bash
php -S localhost:8080 -t backend/public
```

Run backend tests when PHP is available:

```bash
php backend/tests/run.php
```

Run the app against an Android emulator backend:

```bash
flutter run --dart-define=SSD_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

## Working Rules

- Do not commit secrets or local environment files. Keep `backend/.env`, Firebase config files, service-account JSON files, signing keys, and local build output out of Git.
- Preserve the role model and school boundary checks. Security-sensitive rules must be enforced server-side, not only in Flutter UI.
- Prefer the existing architecture: Riverpod providers and repositories on the Flutter side; controller/service/core separation on the PHP side.
- Keep V1 scope focused. Chat, uploads, open registration, and broad social features are not part of the current SSD Manager V1 unless explicitly requested.
- For documentation or onboarding changes, update `docs/PROJECT_CONTEXT.md` when the project state changes materially.

## Verification Expectations

For Flutter changes, run `flutter analyze` and relevant `flutter test` tests. For backend changes, run `php backend/tests/run.php` when PHP 8.2+ is available. If a required tool is missing, say exactly which verification could not be run.
