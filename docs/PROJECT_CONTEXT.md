# SSD Manager Project Context

Stand: 2026-07-23

This document preserves important project context from earlier local Codex chats. Those chats existed only on the original Windows PC, so this file should travel with the repository through GitHub and be used as durable context on the MacBook or in future Codex chats.

## Portable Memory Rule

Important project knowledge must be written into repository documentation, not left only in local Codex chats. Future Codex work should update:

- `AGENTS.md` for durable agent instructions.
- `docs/PROJECT_CONTEXT.md` for current status, gaps, setup notes, and broad project context.
- `docs/DECISIONS.md` for product, architecture, workflow, deployment, privacy, tooling, or release decisions.

Do not store secrets, credentials, tokens, signing keys, real student data, or private account details in these documents.

## Current Status

SSD Manager is a solid MVP/V1 prototype, but it is not production-ready yet. The repository already contains the Flutter app, PHP backend, database schema, seed data, cron job, documentation, and first tests.

Verified on the original Windows development machine:

- `flutter analyze` completed cleanly.
- `flutter test` passed with 5 tests.
- Android debug APK build completed successfully.
- PHP was not available in `PATH`, so backend/PHP tests could not be run there.
- Backend code was inspected structurally, but not end-to-end tested against a live database in that session.

Verified on the MacBook through 2026-07-23:

- Flutter 3.44.7 and Dart 3.12.2 are available.
- `flutter pub get` completed successfully.
- `flutter test` passed with 5 tests.
- `flutter analyze` completes cleanly after generated `build/**` sources were excluded in `analysis_options.yaml`.
- PHP 8.4.23 and MySQL 8.4.10 are installed through the versioned Homebrew formulas `php@8.4` and `mysql@8.4`; MySQL runs as a Homebrew service.
- A local ignored `backend/.env`, the `ssd_manager` development database, the initial migration, and the demo seed data are set up.
- `php backend/tests/run.php` passed with 4 tests, and all backend PHP files passed `php -l` syntax checks.
- A native-PDO login failure caused by reusing the named placeholder `:identifier` was fixed by using separate placeholders for email and username lookup.
- `php backend/tests/api_smoke.php` now verifies unauthenticated rejection, login by username and email, authenticated session lookup, own profile, upcoming duties, duty history, announcements, user list, token refresh, logout, and rejection of the revoked session against the local database.
- `php backend/tests/api_write_smoke.php` verifies local write operations and role boundaries for account creation and roles, announcements, self/admin duty assignment, duplicate prevention, regular cancellation, sick reporting, password changes, device management, deactivation, reactivation, deletion marking, and session revocation.
- `php backend/tests/api_security_smoke.php` verifies school isolation plus negative validation and conflict responses.
- `php backend/tests/api_concurrency_smoke.php` uses two local backend processes to verify that concurrent requests cannot exceed the three-person duty capacity.
- The API tests are restricted to a local API/database and remove their uniquely identified test data after each run.
- Live testing found and fixed four backend defects: concurrent capacity overbooking, invalid calendar dates returning HTTP 500, duplicate accounts returning HTTP 500, and removal of an assignment through a mismatched duty-date URL.
- The iOS deployment target was raised from 13.0 to 15.0 in all Runner build configurations. An unsigned iOS simulator build then completed successfully and produced `Runner.app`.
- The repository is inside the macOS Documents/File Provider area. Building iOS into the default local `build/` directory can add extended attributes that make Apple code signing reject generated frameworks. A temporary Flutter build directory under `/private/tmp` avoids this machine-specific problem.
- Android remains unchanged: its package name is `de.schule.ssdmanager`, and its compile, minimum, and target SDK versions continue to come from Flutter defaults.
- OpenJDK 17 and the Android SDK Command-line Tools are installed through Homebrew, and Flutter is configured to use them. Android platforms 34-36, Build Tools 36.0.0, Platform Tools, NDK 28.2, and CMake 3.22.1 are installed; `flutter doctor` reports a healthy Android toolchain and all licenses accepted.
- A universal, debug-signed Android APK was built successfully on the MacBook for package `de.schule.ssdmanager`, minimum SDK 24, and target SDK 36. The APK signature and manifest were verified, and the embedded local backend URL was confirmed in Flutter's build input.
- Android declares Internet access for all builds. Cleartext HTTP is enabled only in the debug manifest so a physical device can reach the local PHP backend during development; release builds remain intended for HTTPS.
- The installed iOS 26.5 runtime and iPhone 17 Pro simulator were started successfully. SSD Manager launched, displayed its login screen, received HTTP 200 from the local API for the seeded `noah` demo login, and correctly navigated to the mandatory initial password-change screen.
- A hosted All-Inkl MySQL/MariaDB database is available. The initial schema migration was imported successfully through phpMyAdmin and all nine expected empty tables were verified; no demo accounts, seeds, credentials, or student data were imported.
- Railway was selected as the production target instead of combining a Railway API with the All-Inkl database. The dedicated SSD Manager Railway project contains the PHP API and MySQL in the same EU region; the existing StudyConnect project must remain untouched.
- The repository now contains a PHP 8.4/Apache `Dockerfile`, Railway configuration, automatic pre-deploy migration, a database-backed `/api/v1/health` endpoint, and CLI bootstrap scripts for the first school and teacher account.
- CLI bootstrap failures now return a non-zero exit code so Railway cannot accept a failed pre-deploy migration as successful.
- A separate Railway project named `SSD Manager` now exists in the owner's existing workspace; the pre-existing StudyConnect project was not changed.
- Railway MySQL and `ssd-api` run exclusively in `EU West (Amsterdam)`. Migrations `001` through `004` completed successfully and the public healthcheck returns HTTP 200 at `https://ssd-api-production.up.railway.app/api/v1/health`.
- Railway CLI 5.27.2 is installed on the MacBook and the repository is linked locally to the SSD Manager Railway project.
- Railway enabled Apache `mpm_event` again at container startup even though the official PHP Apache image used `mpm_prefork` during the build. The verified runtime fix pins `php:8.4-apache-bookworm` and disables `mpm_event`/`mpm_worker` immediately before Apache starts.
- The Apache fix was merged to GitHub `main` in commit `483274c`. Railway associated that commit with the service and skipped a redundant rebuild with `No changes to watched files` because the identical Dockerfile and backend content was already live from the verified CLI deployment; the public database healthcheck remained healthy.
- A production test school and teacher account were bootstrapped transactionally. Public HTTPS login by username returned HTTP 200 with the expected school, `teacher` role, and mandatory initial password change; the verification session was revoked immediately and no credentials are stored in the repository.
- A new universal debug APK was built against the live Railway HTTPS API. Its package is `de.schule.ssdmanager`, minSdk is 24, targetSdk is 36, the APK contains ARM32, ARM64, and x86_64 binaries, and its Android debug signature was verified.
- Authenticated simulator testing exposed a shared `LocaleDataException`: duty cards, announcements, profile dates, and date-dependent actions used German `intl` formatters without initializing `de_DE`. Date formatting is now deterministic and independent of runtime locale initialization, with regression tests.
- Database timestamps are stored in UTC but returned without a timezone suffix. The Flutter models now parse those values explicitly as UTC before displaying local time, and announcement roles use the German product labels instead of raw API values.
- The user detail screen no longer offers role, deactivation, or deletion actions for the signed-in account because the backend intentionally forbids self-administration. Duty and user-management API failures are now caught and shown as user-facing messages instead of uncaught asynchronous errors.
- The corrected app was installed and interactively verified on the iPhone 17 simulator against Railway: upcoming/history duties, announcements, Sani list, self profile, device timestamps, and the Sani picker render without error. A corrected universal Android debug APK was also built and signature-checked.
- The duty schedule now has a locally implemented manager workflow: teacher supervision and lead first-aiders can add/edit weekday duties with variable capacity, optional event names, and descriptions visible to all users. They can add named single-day closures or multi-day holiday ranges; weekends are omitted, closures are explicit API fields, appear red in Flutter, and reject assignments.
- The history tab now supports exact-date search through the platform Material calendar. The upcoming cards were compacted so several days and their assigned first-aiders remain visible on one phone screen.
- Incremental SQL migrations are tracked in `schema_migrations`. The local database applied `002_duty_day_details.sql`, and an immediate second migration run skipped both recorded migrations successfully.
- Local verification for the duty-schedule extension passed: `flutter analyze`, 13 Flutter tests, the 4 PHP rule tests, the general API smoke test, the existing write smoke test, and the new duty-management API smoke test. The previously verified security/concurrency suites were not re-run in this session because the sandbox approval for their local database connection timed out.
- Simulator logs exposed a separate shared refresh crash: five screens assigned a newly created `Future` through expression-bodied `setState` callbacks. Sani list, announcements, duty schedule, user detail, and profile refreshes now create the future first and perform only a synchronous assignment inside `setState`.
- The duty-schedule extension was interactively verified on the iPhone 17 simulator against the migrated local API: compact weekday-only cards, visible assigned first-aiders, editable capacity/title/description, red multi-day closures with weekends skipped, manager add/edit dialogs, and exact-date history filtering all worked. Temporary UI test users, assignments, event days, closures, sessions, notifications, and audit rows were removed afterwards.
- A universal Android debug APK for the current Flutter code built successfully with package `de.schule.ssdmanager`, minSdk 24, targetSdk 36, ARM32/ARM64/x86_64 libraries, a valid Android debug signature, and the Railway HTTPS API URL embedded. Its matching backend migrations and APIs are live on Railway, so this build is ready for end-to-end testing on the owner's Android phone.
- The shared announcement channel now uses compact messenger-style bubbles.
  Consecutive messages from one sender omit repeated sender metadata; sender
  changes begin a clearly labeled group. Successful sends append the returned
  message locally instead of performing a second fetch that could falsely
  report a send failure.
- Announcement persistence is transactional, while push delivery happens
  defensively after commit. A push exception can no longer turn an already
  saved announcement into an HTTP error.
- Migration `003_announcement_attachments.sql` adds authenticated,
  school-scoped photo/file attachments stored as bounded MySQL BLOBs. The app
  supports up to four 8 MB attachments, image previews, full-screen zoom,
  system file opening, attachment-only messages, and retry-safe upload IDs.
  Unclaimed uploads older than one day are removed by the cron job.
- The Sani list now has case-insensitive first-/last-name search with clear and
  no-result states.
- The iOS simulator verified text sending without a false error, compact
  same-sender grouping, photo upload, image preview/full-screen display, file
  preview/opening, and name search against the local migrated API. The initial
  iOS document picker test exposed missing uniform type identifiers; PDF,
  text, and Office UTIs were added and the native Files picker then opened
  correctly. All temporary UI users, sessions, announcements, attachments,
  notifications, login attempts, and audit rows were removed.
- Final local verification passed `flutter analyze`, 17 Flutter tests, all PHP
  syntax checks, the four PHP rule tests, API smoke/write/duty-management/
  attachment/security/concurrency suites, including cross-school attachment
  isolation and the concurrent final duty slot. Migration 003 was applied
  locally and a second migration run skipped all three tracked migrations.
- The Dart analyzer now excludes generated iOS ephemeral/plugin symlink trees.
  Without that exclusion, a generated Firebase package link can lead the
  analysis server into the large iOS build checkout. Two stale untracked
  macOS File Provider copies ending in ` 2.dart` were confirmed as old subsets
  and removed.
- A new universal Android debug APK was built for package
  `de.schule.ssdmanager`, minSdk 24 and targetSdk 36 against the Railway HTTPS
  URL. Its Android debug signature was verified. The attachment API and its
  database migrations are deployed on Railway.
- A reported production-account login failure was traced to environment
  selection rather than incorrect credentials: the installed iOS simulator
  build targeted `http://127.0.0.1:8080/api/v1`, while the test account exists
  in Railway. Railway login history showed successful authentication. Future
  builds must always set and record `SSD_API_BASE_URL` explicitly.
- Local `backend/.env` values no longer override already supplied process
  environment variables. This prevents `railway run` and deployed Railway
  variables from silently using the local database configuration.
- Migration `004_user_roles_profiles_and_storage.sql` adds the `sekretariat`
  role, the immutable nullable `sanitaeter_since` profile field, and an index
  for per-user attachment storage queries. The migration is applied locally
  and on Railway.
- Secretariat users can view the duty plan, the complete separated school
  user list, and announcements and can send announcements. They cannot assign
  themselves or others, manage duties, manage accounts, or change roles.
  Teacher and secretariat profiles omit duty statistics. Role changes by
  teacher supervision or Sani-Leitung are restricted to existing
  Schulsanitäter/Sani-Leitung accounts and only toggle those two roles.
- New sanitary accounts require a non-future `Sanitäter seit` date at creation.
  It is returned in profiles but has no update endpoint. Existing sanitary
  accounts remain `Nicht hinterlegt` instead of receiving an invented date.
- Each user has a 100 MB quota for announcement uploads. The profile shows
  usage and a sortable list of claimed and unclaimed files; owners can delete
  their own files. Concurrent uploads serialize on the user row so the quota
  cannot be exceeded by a race.
- Event metadata and single-/multi-day closures can be reset to normal duty
  days through explicit manager endpoints and confirmation dialogs. Existing
  assignments are preserved when an event is reset.
- Flutter now supports system, light, and dark appearance modes, persisted
  independently of login sessions. Teacher and secretariat profiles hide
  irrelevant duty sections, logout and consequential mutations ask for
  confirmation, and all screens use shared loading, empty, and safe error
  states. Raw URLs, API paths, exceptions, SQL details, and response bodies are
  never shown directly to users.
- Final local verification for migrations 002-004 and the combined feature
  set passed `flutter analyze`, 24 Flutter tests, all PHP syntax checks, the
  four PHP rule tests, and the API smoke/write/security/duty-management/
  attachment/secretariat/concurrency suites. All smoke-test data was cleaned
  up, and the second concurrency API process was stopped afterwards.
- The first final Android rebuild hit a macOS File Provider duplicate named
  `GeneratedPluginRegistrant 2.dex` in generated D8 output. `flutter clean`
  removed the stale generated cache and the fresh build succeeded; dependency
  changes are not needed for this symptom.
- A new debug-signed universal Android test APK was built against
  `https://ssd-api-production.up.railway.app/api/v1` at
  `build/app/outputs/flutter-apk/SSD-Manager-Test.apk`. It uses package
  `de.schule.ssdmanager`, minSdk 24, targetSdk 36, a valid Android debug
  signature, and SHA-256
  `2891004b4670c172da688e18c38aa1fd6141c9435e984cf7d391656953eae96d`.
- A fresh iOS simulator build against the same Railway URL succeeded through
  the external temporary build directory, was installed on the booted iPhone
  17 simulator, and visibly launched the SSD Manager login screen. The public
  Railway database healthcheck returned HTTP 200. The installed app now no
  longer points at the local API.
- GitHub `main` commit `4ffb110` (`Expand SSD workflows and role security`)
  was deployed successfully to Railway as
  `dbb59439-ee79-447e-bf0a-f80d4fbea95a` on 2026-07-23. The pre-deploy step
  applied migrations `001_initial_schema.sql` through
  `004_user_roles_profiles_and_storage.sql`; Apache then started normally and
  the database healthcheck returned HTTP 200. Unauthenticated probes of the
  new storage and closure-reset routes returned HTTP 401, confirming that the
  deployed routes are present and protected.

## Implemented Flutter App

The Flutter app currently includes:

- Login by email or username.
- Secure local session storage with `flutter_secure_storage`.
- Access-token and refresh-token flow.
- Forced password change on first login.
- Duty schedule for upcoming 14 days and history.
- Weekend-free schedule lists and exact-date calendar search in history.
- Manager creation/editing of duty days with per-day capacity, title, and description.
- Single-day and ranged holiday/school-closure entry with red unavailable cards.
- Manager reset actions for event metadata and holiday/school-closure ranges.
- Self sign-up, regular removal, and sick reporting for duties.
- Admin/lead workflows for assigning and removing other first-aiders.
- Announcement reading and sending.
- Compact grouped announcement bubbles with authenticated photo/file
  attachments, previews, full-screen image zoom, and system file opening.
- First-aider list with name search, green Schulsanitäter marking, and a
  separate teacher/secretariat section at the bottom.
- User detail view with immutable `Sanitäter seit`, role-appropriate
  statistics, and restricted Sani/Sani-Leitung role management.
- Account creation, deactivation, reactivation, and delete-marking flows.
- Own profile with role-appropriate statistics, 100 MB file storage
  management, appearance settings, password change, device management, and
  confirmed logout.
- Prepared push/deep-link routes.

## Implemented Backend

The PHP backend currently includes:

- REST API under `/api/v1`.
- Authentication, session refresh, and logout.
- Server-side role checks.
- School boundary checks using `school_id`.
- MySQL/MariaDB schema.
- Seed data for demo accounts.
- Audit logging.
- Login rate limiting.
- Notification logs.
- Firebase Cloud Messaging HTTP v1 integration prepared.
- Cron job for marking past planned duties as completed and sending 48-hour reminders.
- Versioned migration tracking and explicit duty-day event/closure fields.
- Transactional announcement creation with push failures isolated after commit.
- Authenticated, school-scoped announcement attachment upload/download,
  allowlisted types, size/count limits, and orphan cleanup.
- A transactional 100 MB attachment quota per user plus owner-only storage
  listing and deletion.
- Server-enforced secretariat permissions and immutable sanitary start dates.
- Reversible manager reset endpoints for special duty days and closure ranges.

Important backend rules already exist server-side:

- Role checks.
- School isolation.
- 14-day duty planning window.
- 48-hour duty change rule.
- Sick reporting.
- Admin assignment/removal.
- Audit logging.
- Push trigger preparation.

## Documentation Already Present

The repository already contains:

- `docs/ARCHITECTURE.md`
- `docs/API.md`
- `docs/ROLES.md`
- `docs/SECURITY_PRIVACY.md`
- `docs/DEPLOYMENT.md`
- `docs/FIREBASE.md`

## Known Gaps

Technical gaps:

- Railway API, MySQL, automatic migration, secret-backed variables, container build, and public HTTPS healthcheck are operational. Production still needs the first real school and teacher account, a backup schedule, the Railway cron service, and optionally a custom API domain.
- The corrected Android test APK points to the live Railway HTTPS API, but it still needs an end-to-end run on the owner's physical phone.
- The authenticated iOS journey for the production test teacher is verified across the main read paths. Mutating duty and account workflows that require a separate student target still need end-to-end testing after additional test accounts exist.
- Further automated coverage is still useful for cron behavior, notification delivery, and complete Flutter UI-to-API journeys.
- `open_filex` currently uses CocoaPods on iOS and does not yet support
  Flutter's Swift Package Manager integration. Flutter 3.44 only warns, but a
  future Flutter version may require a plugin update or replacement.
- Firebase project and config files still need final setup.
- Push notifications must be tested on real Android/iOS devices.
- Android release signing is not set up.
- iOS Bundle ID, Apple Developer Team, and signing are not finalized.
- Deployment still needs cron setup, backups, and centralized log/alert handling.

Product and policy gaps:

- Final deletion/anonymization after 30 days is not implemented yet.
- Final product wording and acceptance testing for event days, holidays, and
  the compact schedule layout still need confirmation on real school devices.
- The 48-hour rule currently depends on the duty day boundary; decide whether it should use midnight or the real duty start time.
- Normal first-aiders currently see relatively broad duty schedule/history information; confirm this from a privacy perspective.
- Admin profile editing is intentionally disabled for V1.
- Announcement sending is currently broad; confirm which roles should be allowed to send announcements.
- Define school rules for moderation, permitted content, retention, and maximum
  storage growth of announcement attachments. Patient documentation remains
  prohibited.

## User-Owned Tasks

The project owner must handle tasks that require external accounts, legal responsibility, or real credentials:

- Create and manage the Firebase project.
- Provide Firebase Android/iOS config files.
- Provide the real school name and first teacher's identity/login details for the initial production accounts.
- Clarify school approval and privacy/legal requirements.
- Handle Apple Developer and Google Play or internal distribution setup.
- Create and safeguard Android signing keys.
- Handle iOS signing and provisioning.
- Provide real user lists and role assignments.
- Test on real school devices or provide test devices.

Codex can help integrate config files, prepare builds, run checks, fix bugs, prepare deployment steps, and document the process. Codex cannot take over school approvals, app-store contracts, 2FA-only account steps, or legal/privacy decisions.

## Open Decisions

Resolve these before production deployment:

1. Should V1 be distributed internally only, through Play Store/App Store, or both?
2. What final Android package name and iOS Bundle ID should be used?
3. Which roles may send announcements?
4. Should the 48-hour rule be calculated from midnight or from the actual duty start time?
5. May a normal first-aider see historical duties of other users?
6. What is the final deletion/anonymization policy?
7. Is an import flow for existing first-aider lists needed?
8. Is push notification support mandatory for V1 or optional?
9. How long should announcement texts and attachments be retained, and who may
   moderate/delete them?

## MacBook Handoff Notes

The code is now portable through GitHub. On the MacBook:

```bash
git clone https://github.com/MarcosCaprile/ssd-manager.git
cd ssd-manager
flutter pub get
```

For every work session:

```bash
git pull
```

After meaningful changes:

```bash
git status
git add .
git commit -m "Describe the change"
git push
```

Do not expect old local Codex chats from the Windows PC to appear automatically on the MacBook. Use this file and `AGENTS.md` as the portable project memory.

If an iOS build in the macOS Documents folder fails with `resource fork, Finder information, or similar detritus not allowed`, run the build from this repository with a temporary external output directory and reset the global setting afterwards:

```bash
flutter config --build-dir=../../../../private/tmp/ssd_manager_flutter_build
flutter build ios --simulator --dart-define=SSD_API_BASE_URL=http://127.0.0.1:8080/api/v1
flutter config --build-dir=
```
