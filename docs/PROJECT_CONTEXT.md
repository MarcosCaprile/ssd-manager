# SSD Manager Project Context

Stand: 2026-07-21

This document preserves important project context from earlier local Codex chats. Those chats existed only on the original Windows PC, so this file should travel with the repository through GitHub and be used as durable context on the MacBook or in future Codex chats.

## Current Status

SSD Manager is a solid MVP/V1 prototype, but it is not production-ready yet. The repository already contains the Flutter app, PHP backend, database schema, seed data, cron job, documentation, and first tests.

Verified on the original Windows development machine:

- `flutter analyze` completed cleanly.
- `flutter test` passed with 5 tests.
- Android debug APK build completed successfully.
- PHP was not available in `PATH`, so backend/PHP tests could not be run there.
- Backend code was inspected structurally, but not end-to-end tested against a live database in that session.

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

- PHP 8.2+ must be available locally or on the server for backend tests and local backend runs.
- MySQL/MariaDB must be created and migrations must be applied.
- A real `backend/.env` must be created from `backend/.env.example`.
- The first teacher account must be created with `backend/scripts/create_teacher.php`.
- Backend/API flows still need end-to-end testing against a real database.
- Flutter must be tested against the real backend URL.
- More tests are needed for auth, roles, API error cases, and duty logic.
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
- Provide server, hosting, domain, and HTTPS access.
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
3. Where will the backend run: school server, shared hosting, VPS, or another host?
4. Which roles may send announcements?
5. Should the 48-hour rule be calculated from midnight or from the actual duty start time?
6. Is a holiday/vacation/school-free-day admin feature required for V1?
7. May a normal first-aider see historical duties of other users?
8. What is the final deletion/anonymization policy?
9. Is an import flow for existing first-aider lists needed?
10. Is push notification support mandatory for V1 or optional?

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
