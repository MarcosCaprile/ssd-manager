# SSD Manager Agent Guide

This file gives Codex durable project context. Keep it short, practical, and in sync with `docs/PROJECT_CONTEXT.md`.

## Project Summary

SSD Manager is a Flutter mobile app plus PHP/MySQL backend for a school first-aid service. It manages duty planning, announcements, first-aider lists, profiles, device sessions, roles, and administration workflows for student first-aiders, lead first-aiders, teacher supervision, and school secretariat staff.

The current repository is the source of truth. Historical Codex chats are local to the original PC and should not be treated as portable project state. Important decisions from those chats are captured in `docs/PROJECT_CONTEXT.md`.

## Stack

- Flutter/Dart for Android and iOS.
- Android application ID, Android namespace, and iOS bundle identifier are
  permanently aligned as `com.minutmate.ssdmanager`.
- Android treats the permanent identifier as a different app from earlier
  legacy test builds. Remove the legacy installation before acceptance testing
  if only one SSD Manager app should remain on the device.
- Riverpod for app state/providers.
- PHP 8.2+ backend without a required Composer setup.
- MySQL/MariaDB schema and seed data in `backend/database`.
- REST API under `/api/v1`.
- Firebase Cloud Messaging is configured for Android and the Railway backend.
  The ignored iOS client plist is installed locally, APNs is configured in
  Firebase, and development signing plus a physical release install work.
  Normal and separate sick-report notifications have passed real-device
  acceptance on Android and iOS.

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
php backend/tests/duty_completion_smoke.php
```

With the local database migrated and seeded, start the backend and run the API smoke test in another terminal:

```bash
php -S localhost:8080 -t backend/public
php backend/tests/api_smoke.php
php backend/tests/api_write_smoke.php
php backend/tests/api_bulk_smoke.php
php backend/tests/api_duty_management_smoke.php
php backend/tests/api_attachment_smoke.php
php backend/tests/api_secretariat_smoke.php
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
Keep generated iOS dependency trees (`ios/Flutter/ephemeral/**` and
`ios/.symlinks/**`) excluded from Dart analysis. Following their package
symlinks can make the analysis server scan the full generated build tree.
If Android D8 reports `GeneratedPluginRegistrant 2.dex` beside the normal
registrant, macOS File Provider duplicated a generated cache file. Run
`flutter clean`, then `flutter pub get`, and rebuild; do not change Android
dependencies to work around this generated-output problem. If duplicate
generated files such as `filepaths 2.xml` reappear immediately, point the
ignored repository `build` path at a fresh directory under `/private/tmp` for
that build, then remove the symlink. This keeps generated Gradle output outside
the File Provider area; the exact procedure is documented in
`docs/PROJECT_CONTEXT.md`.
After installing a Firebase-enabled Android test build, verify
`POST_NOTIFICATIONS` separately. Android can preserve or restore this runtime
permission as denied even when Firebase and both notification channels are
configured correctly.

On the MacBook, Homebrew OpenJDK 17 and Android Command-line Tools are configured in Flutter. Android SDK platforms 34-36, Build Tools 36.0.0, Platform Tools, NDK 28.2, and CMake 3.22.1 are installed, and `flutter doctor` reports all Android licenses accepted. Local HTTP is allowed only in Android debug builds; release builds must use HTTPS.

The production deployment target is a dedicated SSD Manager project in the owner's existing Railway workspace. Deploy the PHP API and Railway MySQL in the same EU region; do not modify the separate StudyConnect Railway project. Railway secrets belong in service variables and must not be written into the repository.

The live Railway API healthcheck is `https://ssd-api-production.up.railway.app/api/v1/health`. Railway's runtime enabled `mpm_event` in addition to PHP Apache's required `mpm_prefork`; keep the Bookworm image pin and the runtime MPM enforcement in `backend/docker/railway-entrypoint.sh`. The fix is on GitHub `main`; Railway associated the merge commit with the service and skipped a redundant rebuild because the identical watched files were already live from the verified CLI deployment.

GitHub `main` commit `8062e99` is live on Railway through deployment
`13ec223e-07a3-46ef-b752-4b9036de021c` from 2026-07-25. The deployment
succeeded and the database-backed healthcheck returned HTTP 200. FCM is
enabled with the protected Base64 service account,
and OAuth authentication was verified inside the running container without
printing the credential or token.

Every simulator/device build must set `SSD_API_BASE_URL` explicitly and record
whether it targets local development or Railway. The production test account
exists only in Railway; a simulator build compiled with
`http://127.0.0.1:8080/api/v1` will correctly reject those credentials because
it uses the separate local database. Process environment variables must take
precedence over `backend/.env`; this is required for `railway run` and deployed
service variables.

Railway CLI SSH maintenance requires a registered public SSH key. For one-off production bootstrap work, register a dedicated key only for the operation, verify the result through the public API, and remove the key from Railway immediately afterward.

## Working Rules

- Do not commit secrets or local environment files. Keep `backend/.env`, Firebase config files, service-account JSON files, signing keys, and local build output out of Git.
- After completing and verifying an implementation task, automatically commit
  and push the task's intended changes to the current branch unless the user
  explicitly asks not to. Never include unrelated user files. Railway or other
  production deployments remain separate and require an explicit deployment
  request.
- Preserve the role model and school boundary checks. Security-sensitive rules must be enforced server-side, not only in Flutter UI.
- Never display raw exception, URL, API, SQL, or response-body details to app users. Route errors through the shared safe user-message mapping.
- Prefer the existing architecture: Riverpod providers and repositories on the Flutter side; controller/service/core separation on the PHP side.
- Foreground live synchronization belongs to the visible screen and must read
  the actual current app lifecycle state. Push-driven in-app refresh must be
  emitted before, and must never wait for, local notification presentation.
- Announcements are the exception to visible-screen-only polling: the
  authenticated home shell owns one central one-second announcement feed in
  every foreground panel. That feed is the shared source for chat content and
  unread badges, so neither feature may depend solely on FCM delivery.
- The open announcement chat must render by directly watching that shared feed.
  Do not mirror each feed update into a replacement `Future`, because this can
  leave an already visible `FutureBuilder` on stale snapshot data.
- Keep V1 scope focused. The shared announcement channel supports explicitly requested photo/file attachments; private chat, open registration, and broad social features remain out of scope unless explicitly requested.
- Ordinary Saturdays and Sundays stay absent from the duty plan, but managers
  may create explicitly named weekend events. Manually created duty days always
  require a title, and duty capacity is limited to 1–50.
- Deleting a claimed announcement attachment removes its bytes and frees quota,
  but keeps the announcement and attachment tombstone so the conversation shows
  that its content was deleted.
- `device_install_id` is a random installation identifier persisted outside the
  login session. It must survive logout and is used to replace stale active
  sessions from the same app installation.
- A successful mutation must not be reported as failed only because its
  follow-up refresh failed. Keep already loaded panel content cached, refresh it
  explicitly when needed, and delay full loading indicators for two seconds.
- Foreground polling must compare semantically equal payloads and publish UI
  state only when data actually changed. Never replace already visible content
  with a new `Future`; preserved `FutureBuilder` updates write into the
  screen's cached data so no loading snapshot or blank frame is rendered.
- Scope frequently changing badge/provider watches to the smallest consuming
  widget. An unread-count update must not rebuild the home shell or its
  `IndexedStack`.
- FCM custom `data` payloads must never use reserved keys such as `from`,
  `message_type`, or names beginning with `google.` or `gcm.`. Keep the
  backend's central payload sanitizer active for every notification type.
- Until the Railway cron service exists, duty-history and profile-statistics
  reads must materialize past `planned` assignments as `completed`. Keep the
  cron completion job as the unattended maintenance path and for reminders.
- Sanitary start dates are immutable after account creation but may be in the
  future so accounts can be prepared before qualification becomes effective.
- Bulk user changes are manager-only, limited to sanitary accounts, validated
  in full, and applied transactionally. Keep the bundled XLSX template
  compatible with the Flutter `excel` parser and run
  `test/user_bulk_spreadsheet_test.dart` after changing it.
- Android announcement pushes are data messages rendered as one local inbox
  notification; iOS uses the shared `ssd-announcements` thread. Native Firebase
  config files and Railway FCM service-account variables must never be
  committed.
- Android release shrinking can remove a notification icon referenced only by
  its runtime resource name. Keep `ic_stat_ssd_manager` referenced through
  Firebase's `default_notification_icon` manifest metadata, and verify the
  resource inside every release APK before device acceptance.
- Push deduplication is per user and distinct Firebase token. Multiple active
  sessions may contain stale tokens after reinstallations; a failed stale
  token must never suppress delivery to a current token of the same user.
- On Apple platforms, never request an FCM token before Firebase exposes the
  APNs token. Register the resulting device token only after authentication,
  and retry after notification permission is granted and on foreground resume.
- Railway receives the Firebase service account only through the protected
  `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` variable. Never print, log, commit, or
  persist its decoded private-key content. Local development may use the
  ignored `FIREBASE_SERVICE_ACCOUNT` file path instead.

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
