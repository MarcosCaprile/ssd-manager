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
- `docs`: architecture, API, deployment, Firebase, roles, security, project context, and decision history.

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

With the local database migrated and seeded, start the backend and run the API smoke test in another terminal:

```bash
php -S localhost:8080 -t backend/public
php backend/tests/api_smoke.php
php backend/tests/api_write_smoke.php
php backend/tests/api_security_smoke.php
```

The concurrency smoke test needs two backend processes on ports 8080 and 8081:

```bash
php -S localhost:8081 -t backend/public
php backend/tests/api_concurrency_smoke.php
```

Run the app against an Android emulator backend:

```bash
flutter run --dart-define=SSD_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

The minimum iOS deployment target is 15.0. On the MacBook, iOS builds inside the Documents/File Provider area may fail because of extended file attributes; use the temporary external build-directory procedure documented in `docs/PROJECT_CONTEXT.md`.

On the MacBook, Homebrew OpenJDK 17 and Android Command-line Tools are configured in Flutter. Android SDK platforms 34-36, Build Tools 36.0.0, Platform Tools, NDK 28.2, and CMake 3.22.1 are installed, and `flutter doctor` reports all Android licenses accepted. Local HTTP is allowed only in Android debug builds; release builds must use HTTPS.

The production deployment target is a dedicated SSD Manager project in the owner's existing Railway workspace. Deploy the PHP API and Railway MySQL in the same EU region; do not modify the separate StudyConnect Railway project. Railway secrets belong in service variables and must not be written into the repository.

## Working Rules

- Do not commit secrets or local environment files. Keep `backend/.env`, Firebase config files, service-account JSON files, signing keys, and local build output out of Git.
- Preserve the role model and school boundary checks. Security-sensitive rules must be enforced server-side, not only in Flutter UI.
- Prefer the existing architecture: Riverpod providers and repositories on the Flutter side; controller/service/core separation on the PHP side.
- Keep V1 scope focused. Chat, uploads, open registration, and broad social features are not part of the current SSD Manager V1 unless explicitly requested.

## Project Memory Protocol

Codex must keep important project knowledge portable across devices by updating repository documentation automatically when the project state changes materially. Do this as part of the same task whenever possible, before committing or before the final response.

Update these files based on the type of information:

- `docs/PROJECT_CONTEXT.md`: current app status, implemented scope, known gaps, setup notes, handoff notes, and project-wide context.
- `docs/DECISIONS.md`: product, architecture, workflow, deployment, privacy, or tooling decisions and the reason for each decision.
- `AGENTS.md`: durable rules that Codex should follow in future chats.

Record context when any of these happen:

- A user makes a decision that affects the product, architecture, workflow, deployment, security, privacy, testing, or release process.
- Codex discovers a persistent blocker, setup requirement, known bug, missing test, or environment constraint.
- A feature is added, removed, deferred, or explicitly declared out of scope.
- A workflow changes, such as how GitHub, local development, Codex Cloud, Firebase, signing, or deployment should be used.

Keep entries concise and factual. Do not store secrets, credentials, tokens, private keys, real student data, or local-only machine paths unless the path is necessary for a documented local setup step.

## Verification Expectations

For Flutter changes, run `flutter analyze` and relevant `flutter test` tests. For backend changes, run `php backend/tests/run.php` when PHP 8.2+ is available. If a required tool is missing, say exactly which verification could not be run.
