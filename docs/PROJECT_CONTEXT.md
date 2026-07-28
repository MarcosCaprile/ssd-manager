# SSD Manager Project Context

Stand: 2026-07-25

This document preserves important project context from earlier local Codex chats. Those chats existed only on the original Windows PC, so this file should travel with the repository through GitHub and be used as durable context on the MacBook or in future Codex chats.

## Portable Memory Rule

Important project knowledge must be written into repository documentation, not left only in local Codex chats. Future Codex work should update:

- `AGENTS.md` for durable agent instructions.
- `docs/PROJECT_CONTEXT.md` for current status, gaps, setup notes, and broad project context.
- `docs/DECISIONS.md` for product, architecture, workflow, deployment, privacy, tooling, or release decisions.

Do not store secrets, credentials, tokens, signing keys, real student data, or private account details in these documents.

## Current Status

SSD Manager is a solid MVP/V1 prototype, but it is not production-ready yet. The repository already contains the Flutter app, PHP backend, database schema, seed data, cron job, documentation, and first tests.

The repository now also contains `website/`, a ready-to-upload static public
site for `ssd-manager.minutmate.com`. It includes product and onboarding
information, anonymized iPhone screenshots, support contacts, public HTML legal
pages, and downloadable reviewed Word versions. The owner still needs to
publish this folder and verify every canonical HTTPS URL before store
submission. Reusable legal documents intentionally contain no standard price,
term, notice period, or pilot conditions; each school receives individually
agreed commercial terms.

Latest verified implementation on 2026-07-25:

- Production diagnostics showed that all seven attempted sick-report pushes
  failed at FCM while normal announcement pushes had successful deliveries.
  The sick payload used FCM's reserved custom-data key `message_type`. The
  backend now removes all reserved FCM data keys centrally, and regression
  tests cover the sick-report payload and the full reserved-key set.
- Railway now has the scheduled `ssd-cron` service in EU West. It uses
  `/railway.cron.json`, runs `php cron/run_due_jobs.php` every 15 minutes, has
  no public domain or web healthcheck, and receives production settings only
  through references to `ssd-api`. Its first manual production run completed
  successfully on 2026-07-26.
- Live refreshes for announcements, duties, the Sani list, profiles, devices,
  storage, and user details retain their last successful payload and update
  cached data without replacing the screen's completed `Future`. The unread
  badge watches its provider inside the navigation icon only, so a new
  announcement cannot rebuild the whole home shell and flash the current
  Android panel white.
- Verification passed with clean Flutter analysis, all 43 Flutter tests, all
  PHP syntax checks, 9 backend rule tests, the dedicated duty-completion smoke
  test, and the local read/write/duty-management API smoke suites.
- A Railway-targeted Android release APK was built successfully with package
  `com.minutmate.ssdmanager`, minSdk 24, targetSdk 36, valid Android-v2 debug
  signing, and SHA-256
  `0187f1e40c6db4f4871b15baca6477bc0f141ddb223049bd633a91f2fe79652b`.
- Commit `8062e99` is live through Railway deployment
  `13ec223e-07a3-46ef-b752-4b9036de021c`; the database-backed production
  healthcheck returned HTTP 200.
- A release-only Android notification outage was traced to the optimizer
  removing `ic_stat_ssd_manager`, which had been referenced only by its runtime
  resource name. Firebase's default-notification-icon manifest metadata now
  keeps it in the release APK. The rebuilt APK has SHA-256
  `34a74a38a57f7a406713e267cb52f1dfdd981a51e70412b583c92016791b3b49`,
  was installed through the data-preserving ADB update path, exposes the normal
  importance-4 and sick-report importance-5 channels, and registered its new
  device token against Railway with HTTP 200.
- Final real-device acceptance is complete. Normal announcements and separate
  urgent sick-report notifications arrive on Android and iOS; sick reports
  also appear as red system messages in the shared chat. A past planned duty
  appears as completed in history/profile statistics, and Android live updates
  no longer produce the previous white-screen flash.

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
- At this checkpoint Android still used the former package identifier; its
  compile, minimum, and target SDK versions continued to come from Flutter
  defaults.
- OpenJDK 17 and the Android SDK Command-line Tools are installed through Homebrew, and Flutter is configured to use them. Android platforms 34-36, Build Tools 36.0.0, Platform Tools, NDK 28.2, and CMake 3.22.1 are installed; `flutter doctor` reports a healthy Android toolchain and all licenses accepted.
- A universal, debug-signed Android APK was built successfully on the MacBook
  with the then-current package identifier, minimum SDK 24, and target SDK 36.
  The APK signature and manifest were verified, and the embedded local backend
  URL was confirmed in Flutter's build input.
- Android declares Internet access for all builds. Cleartext HTTP is enabled only in the debug manifest so a physical device can reach the local PHP backend during development; release builds remain intended for HTTPS.
- The installed iOS 26.5 runtime and iPhone 17 Pro simulator were started successfully. SSD Manager launched, displayed its login screen, received HTTP 200 from the local API for the seeded `noah` demo login, and correctly navigated to the mandatory initial password-change screen.
- A hosted All-Inkl MySQL/MariaDB database is available. The initial schema migration was imported successfully through phpMyAdmin and all nine expected empty tables were verified; no demo accounts, seeds, credentials, or student data were imported.
- Railway was selected as the production target instead of combining a Railway API with the All-Inkl database. The dedicated SSD Manager Railway project contains the PHP API and MySQL in the same EU region; the existing StudyConnect project must remain untouched.
- The repository now contains a PHP 8.4/Apache `Dockerfile`, Railway configuration, automatic pre-deploy migration, a database-backed `/api/v1/health` endpoint, and CLI bootstrap scripts for the first school and teacher account.
- CLI bootstrap failures now return a non-zero exit code so Railway cannot accept a failed pre-deploy migration as successful.
- A separate Railway project named `SSD Manager` now exists in the owner's existing workspace; the pre-existing StudyConnect project was not changed.
- Railway MySQL and `ssd-api` run exclusively in `EU West (Amsterdam)`. Migrations `001` through `007` completed successfully and the public healthcheck returns HTTP 200 at `https://ssd-api-production.up.railway.app/api/v1/health`.
- Railway CLI 5.27.2 is installed on the MacBook and the repository is linked locally to the SSD Manager Railway project.
- Railway enabled Apache `mpm_event` again at container startup even though the official PHP Apache image used `mpm_prefork` during the build. The verified runtime fix pins `php:8.4-apache-bookworm` and disables `mpm_event`/`mpm_worker` immediately before Apache starts.
- The Apache fix was merged to GitHub `main` in commit `483274c`. Railway associated that commit with the service and skipped a redundant rebuild with `No changes to watched files` because the identical Dockerfile and backend content was already live from the verified CLI deployment; the public database healthcheck remained healthy.
- A production test school and teacher account were bootstrapped transactionally. Public HTTPS login by username returned HTTP 200 with the expected school, `teacher` role, and mandatory initial password change; the verification session was revoked immediately and no credentials are stored in the repository.
- A new universal debug APK was built against the live Railway HTTPS API with
  the then-current package identifier. Its minSdk is 24, targetSdk is 36, the
  APK contains ARM32, ARM64, and x86_64 binaries, and its Android debug
  signature was verified.
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
- A universal Android debug APK for that Flutter checkpoint built successfully
  with the then-current package identifier, minSdk 24, targetSdk 36,
  ARM32/ARM64/x86_64 libraries, a valid Android debug signature, and the
  Railway HTTPS API URL embedded.
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
  identifier then in use, minSdk 24 and targetSdk 36 against the Railway HTTPS
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
- New sanitary accounts require a valid `Sanitäter seit` date at creation. It
  may be in the past or future, is returned in profiles, and has no update
  endpoint. Existing sanitary accounts remain `Nicht hinterlegt` instead of
  receiving an invented date.
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
  identifier then in use, minSdk 24, targetSdk 36, a valid Android debug
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
- The current continuation allows managers to create named
  weekend duty events while keeping ordinary weekends hidden. New duty days
  require a title, capacity is limited to 1–50, and unoccupied weekend events
  can be removed completely.
- Migration `005_attachment_tombstones.sql` keeps an announcement visible when
  its owner deletes the attached file from profile storage: file bytes and
  quota usage disappear, while an italic deleted-content marker replaces the
  preview. Migration `006_device_install_identity.sql` adds a persistent random
  app-installation identity so logout/login no longer leaves duplicate active
  device rows.
- The Sani list marks Schulsanitäter blue and Sani-Leitung green, removes
  public active-status text, and shows inactive accounts only to
  Sani-Leitung/teachers in a separate bottom section. Account deactivation and
  deletion marking revoke every session; inactive login returns a safe,
  actionable explanation.
- Schulsanitäter are now orange in the Sani list and duty plan for their first
  150 calendar days from `sanitaeter_since`; this is display-only and does not
  change their role or permissions. Teacher supervision can bulk-create a full
  school setup including teacher and secretariat accounts; their sanitary date
  stays empty while it remains mandatory for sanitary roles.
- Login now resolves credentials across all active manually provisioned school
  environments. A successful password must identify exactly one account, and
  the created session retains that account's `school_id` for all tenant checks.
  GitHub `main` commit `5e2b6ca` is live on `ssd-api` through Railway
  deployment `dd3e3784-5345-450a-996e-4636e44ed3a6`; the Demo-Schule teacher
  login returned HTTP 200 with the expected `teacher` role.
- Main navigation panels are loaded lazily and retained after their first
  visit. Full loading indicators are delayed for two seconds, existing content
  remains visible during refreshes, and successful mutations are no longer
  reported as failures merely because a following refresh failed.
- The profile is now a compact menu whose settings open dedicated appearance,
  statistics, registered-device, cloud-storage, and password pages. Logout is
  a confirmed red button at the bottom.
- Final local verification for this continuation passed `flutter analyze`, 25
  Flutter tests, syntax checking of every backend PHP file, the four PHP rule
  tests, and all API smoke suites for general behavior, writes, duties,
  attachments, secretariat, security, and concurrency. Migrations 001–006 are
  applied locally and an immediate rerun skipped all six. Smoke-test data was
  cleaned up. At this checkpoint migrations 005–007 were not yet deployed;
  deployment `85b0afa0-9d47-4e67-a39e-507113fb7708` later applied the complete
  schema through migration 007.
- Android commit `4cf2a6f` was built as a fresh universal debug APK with the
  Railway HTTPS API explicitly embedded. The APK uses package
  identifier then in use, minSdk 24, targetSdk 36, a valid Android debug
  signature, and SHA-256
  `e21a7c1fd2bbfeb63c078a5f5d836cae5945642f672f0c450ae8b27900d759bd`.
  It was installed successfully over USB on the owner's Samsung test phone
  without clearing app data; Android reported `MainActivity` visible and
  top-resumed with a running app process. Features backed by migrations
  005–007 were deployed subsequently with commit `131ff78`.
- Successful API mutations now invalidate central Riverpod revisions for
  users, duties, and announcements. Loaded panels retain visible content while
  refreshing, tab selection and app resume trigger relevant synchronization,
  and role changes no longer require an app restart to appear.
- New sanitary accounts accept an immutable `sanitaeter_since` date in the
  past or future. The creation picker supports advance preparation, and both
  single-account and bulk API tests verify future dates.
- Managers have a dedicated create-only XLSX account import with seven columns:
  Vorname, Nachname, Benutzername, Schul-E-Mail, Temporäres Startpasswort,
  Rolle and Startdatum. Sanitary dates use DD/MM/YYYY; staff rows require
  `N/A`. The bundled template contains one example for each role, while local
  and server validation keep every import transactional and all-or-nothing.
- Migration `007_system_announcements.sql` adds typed announcements. A sick
  report transaction now stores a red system-chat message naming the user,
  date, and remaining planned Sani count before push delivery is attempted.
- The Flutter launcher logo was replaced on Android and iOS with the SSD
  Manager medical-kit/calendar icon; the same asset is used inside the app.
- Push presentation now groups the single announcement conversation: Android
  updates one inbox-style notification with up to six lines, while iOS uses
  one `ssd-announcements` thread. Foreground messages refresh the visible data,
  notification taps retain deep-link routing, and token refreshes are
  registered after authentication.
- The physical-iPhone push-registration defect was traced to requesting an FCM
  token before iOS had supplied its asynchronous APNs token and, during login,
  before the API session existed. The client now waits for APNs with a bounded
  retry, registers FCM only after authentication, retries immediately after
  notification permission and on resume, and declares `fetch` plus
  `remote-notification` background modes. Static verification passes; delivery
  still needs acceptance testing with the freshly installed release build.
- Final local verification passed `flutter analyze`, 30 Flutter tests, every
  backend PHP syntax check, the four PHP rule tests, and all API suites for
  general behavior, writes, bulk users, duty management, attachments,
  secretariat, security, and concurrency. Migration 007 is applied locally,
  and all smoke-test data was cleaned up.
- A fresh universal Android debug APK built successfully with the Railway HTTPS
  API explicitly embedded, the new launcher/status icons, and a valid Android
  debug signature. Its SHA-256 is
  `372fa082b8adcb9c9c51dae55a0c40d9907aba505dcaa7559bbbab00b82fe45d`.
  Because macOS File Provider immediately recreated generated Gradle files
  with names such as `filepaths 2.xml`, this final build used a temporary
  `/private/tmp` target linked at the ignored repository `build` path. The
  clean external build completed without duplicate output.
- GitHub automatically deployed commit `131ff78` to Railway as deployment
  `85b0afa0-9d47-4e67-a39e-507113fb7708`. The pre-deploy process skipped the
  already-applied migrations 001–006, applied migration 007, started Apache
  normally, and passed the public database-backed healthcheck with HTTP 200.
- Android application ID and namespace, the Kotlin launcher package, and the
  iOS Runner bundle identifier are permanently aligned as
  `com.minutmate.ssdmanager`. Runner test bundle identifiers use the matching
  `com.minutmate.ssdmanager.RunnerTests` namespace.
- The identifier migration passed `flutter analyze` and all 30 Flutter tests.
  A fresh Android debug APK built against the Railway HTTPS API reports
  `com.minutmate.ssdmanager` in its packaged manifest, has a valid Android v2
  debug signature, and has SHA-256
  `821e95e3dc4eab358d3fd4f8633a587be9f611c30f82f079a3a335e292ba706e`.
  A fresh iOS simulator build reports the same bundle identifier and minimum
  iOS version 15.0. Because Android considers the permanent identifier a new
  application, earlier legacy test installations are not upgraded in place.

## Implemented Flutter App

The Flutter app currently includes:

- Login by email or username.
- Secure local session storage with `flutter_secure_storage`.
- Access-token and refresh-token flow.
- Forced password change on first login.
- Duty schedule for upcoming 14 days and history.
- Weekday schedule lists plus explicitly named weekend events and exact-date
  calendar search in history.
- Manager creation/editing of duty days with required title, optional
  description, and per-day capacity from 1 to 50.
- Single-day and ranged holiday/school-closure entry with red unavailable cards.
- Manager reset actions for event metadata and holiday/school-closure ranges.
- Self sign-up, regular removal, and sick reporting for duties.
- Admin/lead workflows for assigning and removing other first-aiders.
- Announcement reading and sending.
- Compact grouped announcement bubbles with authenticated photo/file
  attachments, previews, full-screen gallery-style image zoom, system file
  opening, and outgoing platform sharing.
- Native Android/iOS share targets that open shared text, photos, or files in
  the announcement composer without sending automatically.
- First-aider list with name search, blue Schulsanitäter and green
  Sani-Leitung marking, a separate teacher/secretariat section, and a
  manager-only inactive-account section at the bottom.
- User detail view with immutable `Sanitäter seit`, role-appropriate
  statistics, and restricted Sani/Sani-Leitung role management.
- Account creation, deactivation, reactivation, and delete-marking flows.
- Own profile menu with dedicated role-appropriate statistics, 100 MB file
  storage, appearance, password, and device pages plus confirmed red logout at
  the bottom.
- Prepared push/deep-link routes.
- Live in-place synchronization after successful user, duty, attachment, and
  announcement mutations, push-driven chat refresh, and visible-screen
  foreground fallback synchronization.
- Manager-only seven-column XLSX account creation, validation and template
  download with transactional all-or-nothing application.
- Grouped local announcement notifications and typed red sick-report system
  messages.
- SSD Manager launcher and in-app logo assets for Android and iOS.

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
- Firebase Cloud Messaging HTTP v1 payload delivery, token registration, and
  client presentation implemented. Android and iOS native configuration, APNs,
  signing entitlements, and the protected Railway service account are active;
  iOS delivery needs revalidation after the client token-ordering fix.
- Cron job for marking past planned duties as completed and sending 48-hour reminders.
- Versioned migration tracking and explicit duty-day event/closure fields.
- Transactional announcement creation with push failures isolated after commit.
- Authenticated, school-scoped announcement attachment upload/download,
  allowlisted types, size/count limits, and orphan cleanup.
- A transactional 100 MB attachment quota per user plus owner-only storage
  listing and tombstone deletion that preserves shared messages.
- Server-enforced secretariat permissions and immutable sanitary start dates.
- Reversible manager reset endpoints for special duty days and closure ranges.
- Persistent app-installation identities for active-session deduplication and
  immediate all-session revocation when an account is deactivated.

Important backend rules already exist server-side:

- Role checks.
- School isolation.
- 14-day duty planning window.
- 48-hour duty change rule.
- Sick reporting.
- Admin assignment/removal.
- Audit logging.
- Push triggers, token refresh registration, deep-link routing, Android
  announcement stacking, a separate sick-report channel/thread, foreground
  suppression for visible normal chat messages, and iOS announcement-thread
  grouping. Real normal-message delivery is verified on Android; iOS has its
  Firebase plist and APNs configuration and now awaits final delivery
  revalidation on the physical device.
- Transactional sanitary-account bulk validation and application with audit
  logging and session revocation.
- The create-only seven-column bulk import has an editable in-app mapping
  table. Its final status column marks invalid rows red and exposes the exact
  errors; a changed row must be checked again before account creation. Empty
  sanitary dates for teacher supervision and secretariat are stored as SQL
  NULL, preventing strict MySQL DATE errors during a mixed-role import.
- Typed system announcements created atomically with successful sick reports.

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

- Railway API, MySQL, automatic migration, secret-backed variables, container
  build, public HTTPS healthcheck, and the scheduled maintenance service are
  operational. Production still needs the first real school and teacher
  account, a backup schedule, and optionally a custom API domain.
- The corrected Android test APK points to the live Railway HTTPS API and
  passed its end-to-end run on the owner's physical phone.
- The authenticated iOS journey for the production test teacher is verified across the main read paths. Mutating duty and account workflows that require a separate student target still need end-to-end testing after additional test accounts exist.
- Further automated coverage is still useful for cron behavior, notification delivery, and complete Flutter UI-to-API journeys.
- `open_filex` currently uses CocoaPods on iOS and does not yet support
  Flutter's Swift Package Manager integration. Flutter 3.44 only warns, but a
  future Flutter version may require a plugin update or replacement.
- Firebase setup is complete for the Android and iOS clients and Railway
  backend. The ignored iOS `GoogleService-Info.plist` is installed for
  `com.minutmate.ssdmanager`, the owner configured APNs in Firebase, and normal
  plus sick-report pushes were accepted on the physical iPhone.
- The Android Firebase configuration for `com.minutmate.ssdmanager` is
  installed locally at the ignored `android/app/google-services.json` path and
  was validated against the permanent application ID. The matching iOS
  Firebase plist is installed locally at its ignored native path.
- The downloaded Firebase Admin service account was validated locally against
  the same Firebase project without exposing its private key. Production can
  now load this credential directly from the protected
  `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` Railway variable; the previous local
  ignored file-path method remains available for development.
- Railway deployment `6784d52f-2f54-44f9-9e32-7ae54da223ec` runs commit
  `807dc83` with FCM enabled. Migrations 001–007 and the public healthcheck
  passed, and Firebase OAuth authentication succeeded inside the running
  container without printing the credential or access token. The temporary
  Railway SSH key used for this verification was removed immediately.
- The Firebase-configured Android debug APK uses
  `com.minutmate.ssdmanager`, embeds the Railway HTTPS API, contains the
  generated `google_app_id` and `gcm_defaultSenderId` resources, and has a
  valid Android-v2 debug signature. Its SHA-256 is
  `ef9c2e79e70daf0c131b1da81df53693edfae9453eecec7e12afa6c0c0e6a7ef`.
  It was installed successfully on the connected Samsung test phone in the
  primary Android user, and its `MainActivity` reached the top-resumed state
  without a Firebase startup error. The owner subsequently granted permission
  and confirmed real Android delivery for normal announcement messages.
- Announcement pushes now distinguish normal chat messages from
  `duty_sick_reported` system messages. Normal messages keep the single
  announcement stack and are suppressed while the foreground app is visibly
  showing the announcement panel. Sick reports always use their own urgent
  Android channel and notification card plus the separate iOS
  `ssd-sick-reports` thread.
- The app persists an announcement unread count and shows it as a red badge in
  the main navigation outside the announcement panel. Opening that panel marks
  the conversation read. Incoming pushes trigger an immediate content refresh;
  one central home-shell feed synchronizes announcements every second in every
  foreground panel and drives both chat content and unread badges. The visible
  duty/Sani-list panels synchronize every two seconds. Dynamic JSON requests/
  responses use explicit no-cache headers, and foreground push refresh no
  longer waits for local notification presentation.
- Periodic duty and Sani-list synchronization now retains the last visible
  payload while a request is running, compares model values semantically, and
  publishes only real changes. Preserved chat, profile, device, attachment, and
  detail refreshes use synchronously completed state. This removes the white
  one-frame reload that previously appeared on every two-second polling tick;
  regression tests cover cached content and redundant feed suppression.
- Announcement history now shows one date divider above the first message of
  each populated day. Consecutive messages across midnight therefore start a
  new visible day and sender group.
- A fresh Firebase-enabled Android debug APK for this continuation was built
  against the Railway HTTPS API, verified with Android v2 signing, and
  installed successfully over USB on the Samsung test phone. Its SHA-256 is
  `8bf51d0ec5b057138089b863d0a01daea17970c58e84b756599e79501a727a6c`.
- Separate sick-report delivery against the updated live backend is accepted
  on Android and iOS, including the red system-chat message and the dedicated
  urgent notification channel/thread.
- Firebase initialization and token registration now retry after transient
  startup failures. Android notification channels are explicitly created, and
  local notification operations have a timeout so one stalled platform call
  cannot block later notifications.
- Android exposes SSD Manager for native `SEND` and `SEND_MULTIPLE` sharing.
  iOS has a compiled Share Extension using
  `com.minutmate.ssdmanager.ShareExtension` and the shared App Group
  `group.com.minutmate.ssdmanager`. Both Runner and ShareExtension use automatic
  signing with the same Apple Developer team. Simulator and physical-device
  builds complete, and the ShareExtension resolves valid `1.0.0+1` bundle
  versions.
- Photo previews start aspect-fit over a black full-screen canvas, support
  pinch/double-tap zoom across the complete viewport, and expose the system
  share sheet. File cards also expose the system share sheet.
- A fresh Firebase-enabled universal Android debug APK was built against the
  Railway HTTPS API with incoming share intent filters and valid Android-v2
  debug signing. Its SHA-256 is
  `c719d0bfa95d8c288d710463b9d85ab32834bae106a897658fdf67ddcab15570`.
  It was installed as an update on the connected Samsung after restarting ADB
  and accepting USB debugging. The app reached the top-resumed state; Firebase
  initialization succeeded and its background messaging service started
  without an app error.
- Device inspection found Android `POST_NOTIFICATIONS` set to denied even
  though Firebase and the app configuration were intact. The explicitly
  requested permission is now granted. Both `ssd_manager_messages` (high) and
  `ssd_manager_sick_reports` (maximum) channels exist and are enabled.
- Android resolved SSD Manager for both single and multiple share intents. A
  controlled text-share intent opened the app and placed the marked, unsent
  test text in the announcement composer.
- The follow-up device report showed that the previously installed package had
  subsequently been uninstalled from Android user 0, which also removed its
  session and notification permission. Live-v2 was rebuilt and installed
  fresh. Its SHA-256 is
  `9411e1569ff80640b718746c2d4e22c855275967a8f8b966eafead4e8e1ec1dd`.
  Android notification permission is granted for this installation.
- Live-v2 replaces panel-local announcement refresh with one central
  one-second feed shared by the chat and badge. It also requests notification
  permission after login and, if denied, offers a direct route to Android's
  app-specific notification settings. Authenticated two-account testing on the
  connected Samsung verified the one-second Railway refresh and the red unread
  badge without opening announcements.
- The same acceptance test found normal Railway push rows marked `failed`
  although a direct FCM test reached Android. Multiple active sessions from
  earlier reinstallations exposed user-only delivery deduplication: the first
  stale token suppressed the current token of that user. Push delivery now
  deduplicates identical tokens but attempts every distinct token, with a
  regression test covering stale/current token separation.
- GitHub `main` commit `7c38ed4` deployed automatically to Railway as
  deployment `8c5872c4-d746-443d-97bf-8276a986d524`. The deployment succeeded
  and the public database-backed healthcheck returned HTTP 200. A new
  post-deployment announcement remains the final Android acceptance check.
- Physical two-account testing then confirmed normal push delivery and the
  live unread badge, but exposed a UI-only chat defect: Railway returned the
  larger announcement feed in the same second while an already open chat kept
  its old `FutureBuilder` snapshot. The chat now directly watches the shared
  feed and scrolls to a newly arrived latest message. A widget regression test
  verifies that an open chat renders provider updates without navigation.
- The corrected Railway-connected Android debug APK was installed as an update
  on the Samsung with app data preserved. Its SHA-256 is
  `832309b7fd8c38b62a48e8de4ca6069c0dbbfd2c9b285213ddb90a34cc18469f`.
  Open-chat two-account acceptance is complete; provider updates render in the
  already visible conversation without navigation or a blank frame.
- GitHub `main` commit `d348185` deployed successfully to Railway as deployment
  `0531daeb-c509-409a-9aa2-bcbe966b71d5`. Migrations 001–007 were already
  applied, Apache started normally, and the public database-backed healthcheck
  returned HTTP 200 with the new `no-store, no-cache` response policy.
- GitHub `main` commit `871ee87` deployed successfully to Railway as
  deployment `7b328e37-6729-4734-99b2-8890647826ec`. The public
  database-backed healthcheck returned HTTP 200 with the separate
  sick-report-push backend active.
- Android release signing is not set up.
- Development signing and physical iPhone installation are operational. App
  Store distribution, archive validation, and TestFlight remain outstanding.
- Centralized log/alert handling still needs a final production review. The
  Railway cron service is active and its first production execution succeeded.

Product and policy gaps:

- Store distribution is public on Apple App Store and Google Play, but school
  onboarding remains closed. Interested schools contact the operator, who
  manually creates and enables an isolated school environment and its initial
  administrative access; the app has no open registration or self-service
  tenant creation.
- `docs/PRIVACY_OPERATIONS.md` defines the agreed school onboarding,
  data-subject request, deletion/anonymization, 30-day backup, security-incident
  and DSFA-precheck operating model. The actual processor contracts and TOMs
  remain external records and must be reconciled with the real provider
  documents before onboarding another school.
- The existing private StudyConnect contract archive was reviewed as a source.
  `docs/PROVIDER_COMPLIANCE.md` records which Railway and Google/Firebase
  evidence can be revalidated for SSD Manager and explicitly excludes
  StudyConnect-only Vercel, Resend, ALL-INKL and Firebase Storage processing.
  Signed contracts and provider PDFs remain outside the public repository.
- Final deletion/anonymization after 30 days is implemented in the shared due
  job. It removes identity, credentials, sessions, tokens and uploaded bytes,
  tombstones claimed attachments, removes future planned duties, retains
  historical duties/messages as `Gelöschter Nutzer`, and cleans operational
  logs at the documented 90-day/12-month limits. Manager-only ZIP data exports
  include JSON plus the user's still available attachments without secrets.
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

- Safeguard and rotate the APNs authentication key when required; never commit
  it to the repository.
- Provide the real school name and first teacher's identity/login details for the initial production accounts.
- Clarify school approval and privacy/legal requirements.
- Handle Apple Developer and Google Play or internal distribution setup.
- Create and safeguard Android signing keys.
- Handle App Store Connect contracts, distribution provisioning, and
  TestFlight/App Store release steps.
- Provide real user lists and role assignments.
- Test on real school devices or provide test devices.

Codex can help integrate config files, prepare builds, run checks, fix bugs, prepare deployment steps, and document the process. Codex cannot take over school approvals, app-store contracts, 2FA-only account steps, or legal/privacy decisions.

## Open Decisions

Resolve these before production deployment:

1. Which roles may send announcements?
2. Should the 48-hour rule be calculated from midnight or from the actual duty start time?
3. May a normal first-aider see historical duties of other users?
4. Is push notification support mandatory for V1 or optional?

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

If Android repeatedly creates generated duplicates such as `filepaths 2.xml`
or `GeneratedPluginRegistrant 2.dex` even after `flutter clean`, keep Gradle's
expected repository path but redirect only the ignored build output to a fresh
temporary directory:

```bash
flutter clean
flutter pub get
ANDROID_BUILD_DIR="$(mktemp -d /private/tmp/ssd_manager_android_build.XXXXXX)"
ln -s "$ANDROID_BUILD_DIR" build
trap 'test ! -L build || unlink build' EXIT
flutter build apk --debug --dart-define=SSD_API_BASE_URL=https://ssd-api-production.up.railway.app/api/v1
```

Always remove the `build` symlink after the build. The temporary directory
contains generated output only and is not committed.
- The SSD Manager off-site database backup path is implemented for All-Inkl.
  A secret-protected Railway endpoint creates a consistent SQL dump, compresses
  and authenticates/encrypts it, then uploads only `.sql.gz.enc` data and a
  checksum manifest to a dedicated All-Inkl FTPS account. Remote generations
  expire after 30 days and backup run records after 90 days. The separate
  StudyConnect FTP account and cron remain untouched. The dedicated restricted
  account and protected Railway variables are configured. KAS task `Daily
  Backup SSD Manager` runs daily at 03:35 Europe/Berlin and filters failure
  mail to `verwaltung@minutmate.com`; the mailbox confirmation requested by
  All-Inkl must still be accepted. The first production run on 2026-07-26
  uploaded a 5,384,595-byte encrypted dump plus manifest. A downloaded copy
  passed authenticated decryption and gzip validation, after which all local
  test copies and the temporary key file were removed.
- A complete editable legal/release working package now lives in
  `docs/legal-release-package/`. It contains 16 rendered and visually checked
  Word documents: register/StudyConnect comparison, imprint, privacy notice,
  terms, school SaaS contract, Art. 28 DPA, TOMs, subprocessors, retention,
  DPIA template, records of processing, data-subject and incident procedures,
  confidentiality form, school onboarding approval, and App Store privacy
  worksheet. The active Railway, Google/Firebase, and All-Inkl provider
  evidence was copied into a Git-ignored private subfolder; StudyConnect-only
  Vercel, Resend, and Firebase Storage claims were not reused. These remain
  review drafts pending lawyer, school/controller, DPO, state-school-law, and
  provider-account evidence review.
- The All-Inkl notification address was confirmed by the owner after setup;
  backup failure e-mails are therefore active.
