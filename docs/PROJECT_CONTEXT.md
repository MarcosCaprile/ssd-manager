# SSD Manager Project Context

Stand: 2026-07-22

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

Verified on the MacBook on 2026-07-21:

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
- Railway was selected as the production target instead of combining a Railway API with the All-Inkl database. A dedicated SSD Manager Railway project will contain the PHP API and MySQL in the same EU region; the existing StudyConnect project must remain untouched.
- The repository now contains a PHP 8.4/Apache `Dockerfile`, Railway configuration, automatic pre-deploy migration, a database-backed `/api/v1/health` endpoint, and CLI bootstrap scripts for the first school and teacher account.
- CLI bootstrap failures now return a non-zero exit code so Railway cannot accept a failed pre-deploy migration as successful.
- A separate Railway project named `SSD Manager` now exists in the owner's existing workspace; the pre-existing StudyConnect project was not changed.
- Railway MySQL and `ssd-api` run exclusively in `EU West (Amsterdam)`. The initial schema migration completed successfully and the public healthcheck returns HTTP 200 at `https://ssd-api-production.up.railway.app/api/v1/health`.
- Railway CLI 5.27.2 is installed on the MacBook and the repository is linked locally to the SSD Manager Railway project.
- Railway enabled Apache `mpm_event` again at container startup even though the official PHP Apache image used `mpm_prefork` during the build. The verified runtime fix pins `php:8.4-apache-bookworm` and disables `mpm_event`/`mpm_worker` immediately before Apache starts.
- The successful live Railway deployment currently includes that Apache fix from a local CLI upload. The Dockerfile and entrypoint changes must be committed and pushed before relying on GitHub autodeploys again.

## Implemented Flutter App

The Flutter app currently includes:

- Login by email or username.
- Secure local session storage with `flutter_secure_storage`.
- Access-token and refresh-token flow.
- Forced password change on first login.
- Duty schedule for upcoming 14 days and history.
- Self sign-up, regular removal, and sick reporting for duties.
- Admin/lead workflows for assigning and removing other first-aiders.
- Announcement reading and sending.
- First-aider list.
- User detail view with statistics and role management.
- Account creation, deactivation, reactivation, and delete-marking flows.
- Own profile with statistics, password change, and device management.
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
- The verified Apache runtime fix still needs to be committed and pushed so GitHub `main` matches the currently running CLI deployment.
- The Android test APK still points to the former local Mac backend. A new APK must be built against the Railway HTTPS API after the real teacher account exists.
- The initial iOS login path is verified, but the authenticated UI journey after the mandatory password change still needs interactive testing. The iOS Simulator and Android build toolchain are working; the Android APK still needs an end-to-end run on the owner's physical phone.
- Further automated coverage is still useful for cron behavior, notification delivery, and complete Flutter UI-to-API journeys.
- Firebase project and config files still need final setup.
- Push notifications must be tested on real Android/iOS devices.
- Android release signing is not set up.
- iOS Bundle ID, Apple Developer Team, and signing are not finalized.
- Deployment still needs HTTPS, cron setup, backups, and log handling.

Product and policy gaps:

- Final deletion/anonymization after 30 days is not implemented yet.
- Holidays, vacation days, and school-free days are not yet an admin feature.
- Duty capacity is currently globally 3 slots.
- The 48-hour rule currently depends on the duty day boundary; decide whether it should use midnight or the real duty start time.
- Normal first-aiders currently see relatively broad duty schedule/history information; confirm this from a privacy perspective.
- Admin profile editing is intentionally disabled for V1.
- Announcement sending is currently broad; confirm which roles should be allowed to send announcements.

## User-Owned Tasks

The project owner must handle tasks that require external accounts, legal responsibility, or real credentials:

- Create and manage the Firebase project.
- Provide Firebase Android/iOS config files.
- Authorize and complete account/2FA steps in the existing Railway workspace, including creating the SSD Manager project and linking its GitHub deployment.
- Decide and provide real database credentials.
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
5. Is a holiday/vacation/school-free-day admin feature required for V1?
6. May a normal first-aider see historical duties of other users?
7. What is the final deletion/anonymization policy?
8. Is an import flow for existing first-aider lists needed?
9. Is push notification support mandatory for V1 or optional?

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
