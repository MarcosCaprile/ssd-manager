# SSD Manager Decisions

This file records durable project decisions so they are available across local Codex chats, the MacBook, the Windows PC, and Codex Cloud. Keep entries concise, factual, and dated.

Do not store secrets, credentials, tokens, signing keys, real student data, or private account details here.

## 2026-07-23

### Add a read-only Secretariat role

Decision: `sekretariat` can view the duty plan, the school user list, and the
shared announcement channel and can send announcements. It cannot take or
assign duties, manage duty days, manage accounts, or change roles. Teacher and
secretariat profiles do not show duty statistics.

Reason: School secretaries need operational visibility and communication
without being treated as first-aiders or receiving irrelevant duty controls.

### Keep sanitary start dates immutable

Decision: New Schulsanitäter and Sani-Leitung accounts require a
`sanitaeter_since` calendar date at creation. The date has no later edit path.
Existing accounts without a trustworthy date display `Nicht hinterlegt`.

Reason: The date is historical profile information, not a routine preference.
Requiring it at creation avoids later accidental manipulation, while refusing
to backfill an invented date preserves data integrity.

### Restrict role changes to Sani and Sani-Leitung

Decision: Teacher supervision and Sani-Leitung may toggle another sanitary
account only between `sanitaeter` and `sani_leitung`. Neither may convert an
account to or from teacher/secretariat, and self-role changes remain blocked.

Reason: Operational delegation should not permit creating privileged school
staff identities through the ordinary Sani profile editor.

### Give each user 100 MB of private attachment storage

Decision: Announcement uploads have a server-enforced 100 MB quota per user.
Claimed and unclaimed uploads are listed in the profile, sortable by date or
size, and removable only by their uploader. Quota checks serialize concurrent
uploads on the user row.

Reason: Users need a predictable storage limit and a way to recover space.
Server-side ownership and race-safe enforcement prevent UI bypass and quota
overruns.

### Support system, light, and dark appearance modes

Decision: Flutter provides system, light, and dark modes. The choice is stored
separately from the authenticated session and logout does not erase it.

Reason: Appearance is a device preference, not account authentication data,
and dark mode must remain readable throughout all screens.

### Hide technical failures from app users

Decision: User-visible failures go through one safe error mapper. Raw
exceptions, URLs, API paths, SQL details, stack traces, and arbitrary response
bodies are never rendered. Important destructive or consequential actions use
confirmation dialogs where cancellation is meaningful.

Reason: Clear recovery-oriented wording improves usability and prevents
accidental disclosure of implementation details.

### Make special duty entries reversible

Decision: Managers can reset an event day or a single-/multi-day closure to a
normal duty day. Reset removes title, description, and closure state while
preserving existing assignments and a valid minimum capacity.

Reason: Events, holidays, and school closures can be entered incorrectly and
must be correctable without manual database work.

### Require explicit mobile API targets

Decision: Every simulator/device build sets `SSD_API_BASE_URL` explicitly.
Process environment variables take precedence over local `backend/.env`
values.

Reason: The production test account is in Railway, while local development
uses a separate database. An installed local-target build can otherwise look
like a credential failure, and local `.env` values must not override Railway
execution variables.

### Turn announcements into a compact shared messenger

Decision: The single school-wide announcement channel uses compact,
WhatsApp-inspired bubbles. Consecutive messages from the same sender show the
sender name only on the first bubble; a sender change starts a new visible
group. All three roles may send text, photos, and supported files.

Reason: The previous cards used too much vertical space and obscured the
conversation flow. Grouping keeps authorship clear without repeating the same
metadata on every message.

### Store V1 announcement attachments privately in MySQL

Decision: Announcement attachments are stored as MySQL BLOBs, are limited to
four files of 8 MB per message, and require an authenticated, school-scoped API
download. Unclaimed uploads expire after one day. Database growth must be
monitored; a later move to private object storage is appropriate if usage grows
materially.

Reason: This provides persistent Railway storage without a second storage
provider or public URLs and preserves the existing school boundary. The
conservative limits keep the initial database impact bounded.

### Use official Flutter pickers for announcement attachments

Decision: Photos use `image_picker`, general files use `file_selector`, and
downloaded documents use `open_filex`. `file_picker` is not used.

Reason: Current `file_picker` versions conflicted with the project's existing
device/package-information dependencies through incompatible Windows support
packages. The selected plugins resolve cleanly and keep Android and iOS support.

### Treat weekends as absent from the duty schedule

Decision: Saturdays and Sundays are not returned in upcoming duty lists, are filtered defensively in Flutter, and cannot be created as duty days.

Reason: SSD duties only exist on school days. Omitting weekends gives the mobile list more useful density and avoids presenting inactive pseudo-days.

### Make duty days editable and model school closures explicitly

Decision: Teacher supervision and lead first-aiders can create and edit weekday duty entries with an optional title, optional description, and a capacity from 1 to 20. They can also create named single-day or multi-day closures; weekends inside a range are skipped, and closures are stored explicitly as `is_closed`, shown in red, and cannot accept assignments.

Reason: Event days need contextual information and variable staffing, while holidays and school-free periods must remain visible and unambiguously unavailable. Existing assignments must be removed before a day can be closed, preventing silent loss of a planned duty.

### Track applied database migrations

Decision: `backend/scripts/migrate.php` records applied SQL filenames in `schema_migrations` and skips them on later deployments.

Reason: Duty-day fields require additive production migrations. Re-running every `ALTER TABLE` on each Railway deployment would fail, while filename tracking makes incremental migrations repeatable.

## 2026-07-22

### Run Railway services in EU West

Decision: The SSD Manager API and MySQL services run exclusively in Railway's `EU West (Amsterdam)` region. The separate StudyConnect Railway project remains unchanged.

Reason: API and database should remain colocated on Railway's private network and use the European region closest to the intended German school users.

### Pin the Railway PHP image and enforce Apache prefork at runtime

Decision: The Railway API uses `php:8.4-apache-bookworm`, disables alternative Apache MPM modules during the image build, and enforces `mpm_prefork` again in the container entrypoint.

Reason: Railway re-enabled `mpm_event` at runtime and Apache refused to start with both event and prefork loaded. Reapplying the official PHP Apache image's prefork requirement immediately before startup produced a successful deployment and HTTP 200 healthcheck.

## 2026-07-21

### Use GitHub as the source of truth

Decision: The SSD Manager repository is hosted at `https://github.com/MarcosCaprile/ssd-manager.git`, and GitHub is the source of truth for moving work between devices.

Reason: The project was originally local to the Windows PC. GitHub makes the code portable to the MacBook and enables future branch, review, and cloud workflows.

### Keep Codex project memory in the repository

Decision: Important project context must be captured in `AGENTS.md`, `docs/PROJECT_CONTEXT.md`, and this decision log instead of relying on local Codex chat history.

Reason: Local Codex tasks and chats do not automatically appear on other devices. Repository documentation travels with the project through GitHub.

### Prefer local development for mobile work

Decision: Primary SSD Manager development should happen locally on the active development machine, with Codex Cloud used for bounded reviews or isolated tasks.

Reason: Flutter, device testing, local `.env` files, Firebase config, signing, and backend integration are easier to verify locally. Cloud work is still useful for PR reviews, test additions, documentation, and scoped code changes.

### Support iOS 15 and newer

Decision: The minimum supported iOS version is 15.0. Android remains an independent Flutter target and continues to use Flutter's Android SDK defaults.

Reason: The current Firebase iOS packages require iOS 15 or newer. Raising only the iOS deployment target preserves the shared Flutter codebase and does not change Android compatibility.

### Allow local HTTP only in Android debug builds

Decision: Android declares Internet access for all build types, but cleartext HTTP is enabled only for debug builds. Release builds must use an HTTPS API URL.

Reason: A physical Android device needs local HTTP access for development against the MacBook backend, while production traffic must retain transport security.

### Use All-Inkl for the hosted backend database

Decision: The first hosted SSD Manager database is provisioned at All-Inkl, and the initial schema migration is the source of truth for its structure. Demo seed data is not imported into the hosted database.

Reason: Keeping the hosted database empty except for the production schema avoids carrying local test accounts or test data into the deployment environment.

Status: Superseded by the Railway deployment decision below. The empty All-Inkl database is not the planned production database.

### Deploy the API and database together on Railway

Decision: SSD Manager will use a separate Railway project in the owner's existing workspace. The PHP API and a Railway MySQL service will run in the same project and EU region. StudyConnect remains an independent Railway project.

Reason: Keeping API and MySQL together provides private service-to-service networking and avoids exposing the All-Inkl database to an external API host. The existing All-Inkl schema contains no production data and can be recreated on Railway from the repository migration.
