# SSD Manager Decisions

This file records durable project decisions so they are available across local Codex chats, the MacBook, the Windows PC, and Codex Cloud. Keep entries concise, factual, and dated.

Do not store secrets, credentials, tokens, signing keys, real student data, or private account details here.

## 2026-07-26

### Separate SSD Manager product contacts from MinutMate company contacts

Decision: SSD Manager uses `info@ssd-manager.minutmate.com` for product and
school-onboarding inquiries and `support@ssd-manager.minutmate.com` for
technical support. General company matters use the existing MinutMate addresses
`info@minutmate.com`, `verwaltung@minutmate.com`,
`datenschutz@minutmate.com`, and `marcos.caprile@minutmate.com`, always labeled
as MinutMate contacts. StudyConnect's support mailbox is not reused.

Reason: Product support and school onboarding must be unambiguous without
misrepresenting MinutMate-wide company and privacy contacts as belonging to a
different product.

### Retain the active school conversation without promising permanent storage

Decision: Announcement text remains available while its school environment is
active and is not removed by an automatic calendar-based expiry. Each school
must confirm the continuing operational need at least annually. The complete
conversation is deleted when the school environment ends. Attachments remain
until the uploader's account is permanently processed or the school
environment ends, whichever occurs first.

Reason: The shared conversation should preserve operational context like a
messenger, but an unconditional "forever" promise conflicts with storage
limitation and the need to review whether personal data remains necessary.

### Anonymize history and remove account-linked files after deletion

Decision: Only teacher supervision and Sani-Leitung may initiate account
deletion, following a request handled through the school. After the 30-day
pending period, identifying account, credential, session, token, device and
file data is erased. Historical duty records and message text remain but show
`Gelöschter Nutzer`; every attachment uploaded by that account loses its bytes
and becomes an unavailable-content tombstone in the chat.

Reason: School history and conversation continuity remain understandable
without retaining the deleted person's direct identifiers or cloud files.

### Expire encrypted rolling backups after 30 days

Decision: Production uses encrypted daily backups with a rolling maximum age
of 30 days. Deletions take effect immediately in the live system and disappear
from ordinary backup rotation within 30 days. A protected deletion ledger is
reapplied before a restored backup may return to service.

Reason: Thirty days provides a practical disaster-recovery window without
turning backups into indefinite shadow storage or allowing a restore to undo a
completed erasure.

### Publish publicly but provision schools manually

Decision: SSD Manager will be distributed publicly through the Apple App Store
and Google Play so additional schools can discover and install it. There is no
open registration or self-service school creation. A school must contact the
operator, after which the operator creates and explicitly enables its isolated
school environment and initial administrative access.

Reason: Public distribution makes the product available to more schools while
manual onboarding prevents unknown users from creating uncontrolled tenants
or gaining access before organizational and privacy requirements are agreed.

## 2026-07-25

### Mark new first-aiders orange for their first 150 days

Decision: A `sanitaeter` account is displayed in orange in the Sani list and
in duty-assignment rows from its `sanitaeter_since` calendar date through day
149. From day 150 it returns to the normal blue display. Sani-Leitung remains
green. This is a visual orientation marker only; roles, permissions and duty
eligibility do not change.

Reason: Teams can immediately recognize inexperienced first-aiders on the
roster and duty plan without treating them as a separate or restricted role.

### Allow initial full-school creation through bulk import

Decision: Bulk creation by teacher supervision may include all four school
roles. `sanitaeter_since` remains required for sanitary roles and must stay
empty for teacher supervision and secretariat. Bulk updates remain limited to
existing sanitary profiles, preserving the existing staff-role safeguards.

Reason: A school can set up a complete isolated environment in one reviewed,
atomic import without opening later staff-role changes through the bulk path.

### Resolve login accounts across active school environments

Decision: Login searches matching usernames and e-mail addresses across all
active schools and authenticates only when the supplied password identifies
exactly one account. Every resulting session keeps that account's `school_id`;
all authenticated reads and writes remain school-scoped. Ambiguous credentials
receive the same generic login failure as unknown credentials.

Reason: Public distribution with manually provisioned school environments
requires users from every enabled school to reach their own tenant without an
open registration flow or a hard-coded default school.

### Keep the Android notification icon through release shrinking

Decision: Android manifest metadata references `ic_stat_ssd_manager` as
Firebase's default notification icon in addition to the runtime local-
notification configuration. Release acceptance verifies the resource inside
the APK before installation.

Reason: Android's release optimizer removed the icon when it was referenced
only by a Dart resource-name string. Local notification initialization then
failed before channel creation and Firebase token registration.

### Keep all FCM custom data free of reserved keys

Decision: The backend sanitizes every FCM custom `data` payload centrally and
removes `from`, `message_type`, and keys beginning with `google.` or `gcm.`.
Notification semantics use project-owned fields such as `notification_type`
and `system_type`.

Reason: FCM rejects the complete message when reserved custom-data keys are
present. A rejected sick-report push must not be confused with a client
permission or platform-channel failure.

### Materialize completed duties on reads until cron is deployed

Decision: Duty-history and profile-statistics requests convert scoped past
`planned` assignments to `completed` before reading them. The scheduled
completion job remains the canonical unattended maintenance path and is still
required for reminders.

Reason: Railway does not yet run the repository cron service, so assignments
could remain planned indefinitely and disappear from completed statistics.
Read-time materialization makes the user-visible result correct without
weakening school or user boundaries.

### Keep live refresh state inside the already rendered screen

Decision: Once a screen has loaded successfully, polling and push-driven
refreshes update its cached payload without replacing the completed
`FutureBuilder` future. Frequently changing unread-count state is watched only
by the navigation icon that renders it.

Reason: Replacing futures or rebuilding the whole home shell briefly exposed
loading/blank frames on Android. Narrow state subscriptions and cached updates
preserve the current panel while still applying live data.

### Register Apple push tokens only after APNs and authentication are ready

Decision: On iOS and macOS, SSD Manager waits within a bounded window for the
native APNs token before requesting the FCM token. The FCM token is sent to the
API only after an authenticated session exists, with retries after notification
permission is granted, on foreground resume, and on Firebase token refresh.
Runner declares the background `fetch` and `remote-notification` modes.

Reason: APNs registration is asynchronous. A single early FCM request can fail
silently, and attaching a token to the login request happens before the new API
session can own that device. The ordered, retryable flow makes physical-iPhone
delivery deterministic without blocking login.

### Keep live synchronization visually stable

Decision: Foreground polling keeps the last successfully loaded duty and user
payload visible while the next request runs. Model values are compared
semantically, unchanged responses publish no new Riverpod/Future state, and
preserved detail/profile/chat updates use cached or synchronously completed
data rather than re-entering a loading snapshot.

Reason: Replacing a completed `FutureBuilder` future every one or two seconds
created a blank frame even when the server returned identical data. Live data
must update promptly without making the interface visibly reload.

### Install release builds for standalone physical-iPhone testing

Decision: Physical iPhone acceptance builds use signed release mode with an
explicit Railway `SSD_API_BASE_URL`. Debug builds remain for attached Flutter
or Xcode sessions only.

Reason: On iOS 14 and newer, a Flutter debug engine cannot be launched later
from the Home Screen without Flutter tooling or Xcode attached. A release build
behaves like the independently launched app users will test.

## 2026-07-24

### Deduplicate push delivery per distinct device token

Decision: Notification delivery keys combine the event, recipient user, and a
non-reversible hash of each distinct Firebase token. Duplicate sessions with
the same token receive only one push, while different tokens of the same user
are each attempted.

Reason: Reinstallations can leave an older active session with a stale token.
User-only deduplication allowed that failed first attempt to suppress the
current working token.

### Separate urgent sick-report pushes from the announcement conversation

Decision: A sick report remains a red system message in announcements but is
delivered through its own urgent Android channel/card and the separate iOS
`ssd-sick-reports` thread. The reporting user is included in delivery so that
account can receive confirmation. Normal announcement pushes remain grouped and
are suppressed only while the announcement panel is visibly open; sick report
notifications are never suppressed by that visibility rule.

Reason: Staffing emergencies must not disappear inside a normal chat stack,
and the person reporting sick needs verifiable confirmation on the same test
device. A user already reading ordinary chat messages does not need a duplicate
phone alert.

### Track unread announcements and synchronize visible panels

Decision: The app stores the device-local unread announcement count, displays a
red count badge in the bottom navigation, and clears it when announcements are
opened. Push receipt refreshes announcements immediately. While foregrounded,
the authenticated home shell owns one central announcement feed that
synchronizes every second regardless of the selected panel. Chat content and
unread badges derive from this same feed. Duty/Sani-list screens synchronize
every two seconds while visible. Every tick reads the actual lifecycle state
rather than relying on a cached shell flag. Dynamic JSON requests and responses
explicitly bypass intermediary caches. In-app push refresh is emitted before
local notification presentation, so notification plugin latency cannot block
content updates.

Reason: Changes from the current device and other devices must appear without
closing or manually reloading the app. Push provides immediate chat updates,
while bounded foreground polling covers missed/delayed pushes and duty or
account changes that do not have a dedicated push event.

### Provide an explicit notification-permission recovery path

Decision: After authentication, SSD Manager requests notification permission
from the operating system. If permission is unavailable, the app shows a
plain-language explanation with a direct button to Android's app-specific
notification settings. The permission is verified independently from Firebase
initialization and channel creation.

Reason: A valid FCM setup and existing notification channels do not imply that
Android currently permits the app to display notifications.

### Support native incoming and outgoing attachment sharing

Decision: SSD Manager is registered as an Android and iOS share target for
text, photos, and files. Incoming content opens the announcement composer with
the attachment/text prepared but never sends automatically. Existing chat
attachments expose the platform share sheet. Android uses `SEND`/
`SEND_MULTIPLE`; iOS uses a `ShareExtension` with the
`group.com.minutmate.ssdmanager` App Group and extension bundle identifier
`com.minutmate.ssdmanager.ShareExtension`.

Reason: Sharing should match normal messenger behavior while keeping the final
send action explicit and preserving the permanent app identity.

### Separate announcement history by populated calendar day

Decision: The announcement chat displays one date divider above the first
message of each day that contains messages. Empty days create no divider, and
sender grouping restarts after a day boundary.

Reason: The conversation chronology should remain clear without adding visual
noise for dates on which nothing was written.

### Use one permanent mobile app identifier

Decision: Android `applicationId` and namespace plus the iOS Runner bundle
identifier use `com.minutmate.ssdmanager`. Platform test targets derive their
identifier from the same namespace.

Reason: Firebase, push delivery, signing, device installation, and future store
records must refer to one stable cross-platform product identity.

### Store the Railway Firebase credential as a protected Base64 variable

Decision: Production reads the Firebase service-account JSON from
`FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`. A local ignored file path remains a
development fallback, but production does not require a credential file in the
container.

Reason: Railway service variables can securely inject the credential at runtime
without committing a private key or depending on an ephemeral filesystem path.

## 2026-07-23

### Refresh visible data after successful mutations

Decision: Successful user, duty, announcement, and attachment mutations bump
central Riverpod revision providers. Loaded screens refresh in place while
keeping their current content, and the app also refreshes relevant data on tab
selection and foreground resume.

Reason: Role and planning changes must appear without closing and reopening the
app, while a transient follow-up fetch must not turn a completed mutation into
a false failure.

### Allow future sanitary start dates

Decision: `sanitaeter_since` remains mandatory for new sanitary accounts and
immutable afterwards, but may be a valid past or future calendar date.

Reason: Schools need to prepare accounts shortly before a student officially
qualifies without later editing historical profile data.

### Create new school accounts through a seven-column XLSX import

Decision: The visible bulk workflow is exclusively for creating new accounts.
Its worksheet contains exactly Vorname, Nachname, Benutzername, Schul-E-Mail,
Temporäres Startpasswort, Rolle and Startdatum. Sanitary dates use DD/MM/YYYY;
teacher supervision and secretariat use `N/A`. The bundled template shows one
example per role. Editing, deactivation, deletion marking and data export stay
in the normal account-management screens and are not encoded as spreadsheet
actions.

Reason: A simple create-only roster is understandable to schools and avoids
mixing destructive account administration with initial cohort import. The
server still validates every row and applies the file transactionally.

### Review and correct bulk imports in the app before creation

Decision: After an XLSX file is mapped, the app shows every imported account
in an editable table with a status column. Invalid rows are red and list their
specific errors; edited rows must be rechecked before the transaction can be
applied. Non-sanitary roles persist an absent sanitary start date as SQL NULL.

Reason: Schools can fix a typo without rebuilding a spreadsheet, while the
server keeps the final all-or-nothing validation. Binding NULL avoids a strict
MySQL DATE conversion error for teacher supervision and secretariat accounts.

### Group announcement pushes as one conversation

Decision: Android receives data pushes that the app renders into one inbox-style
announcement notification containing up to six recent lines. iOS notifications
share the `ssd-announcements` thread. Opening the announcement panel clears the
local stack.

Reason: All announcements belong to one school-wide conversation, so multiple
individual notification cards create noise and misrepresent the product model.

### Publish sick reports as system announcements

Decision: A successful sick report creates a transactional system announcement
with the username, duty date, and remaining planned Sani count. Flutter renders
it separately with a red border; it is not styled as a personal chat bubble.

Reason: Other Sanis need immediate, clearly distinguished staffing information,
and the duty change and shared message must not diverge.

### Automatically commit and push completed Codex work

Decision: After a requested implementation is complete and verified, Codex
commits and pushes the intended changes automatically unless the owner
explicitly opts out. Unrelated local files and secrets remain excluded.
Production deployment is a separate action and is not implied by a Git push.

Reason: The repository is the portable source of truth across devices, so
completed work should not remain only in an uncommitted MacBook worktree.

### Allow explicitly named weekend duty events

Decision: Ordinary Saturdays and Sundays remain absent from the duty plan.
Teacher supervision and Sani-Leitung may create an explicitly named weekend
event, with a required title and capacity from 1 to 50. It is shown and can be
staffed like an upcoming duty. Reset deletes an unoccupied weekend event;
occupied events must be emptied first.

Reason: Normal school weekends should not create noise, while real weekend
school events still need planned first-aid coverage and a safe correction path.

### Preserve messages when attachment content is deleted

Decision: Deleting a claimed file from profile storage removes its BLOB bytes
and frees quota, but keeps the announcement and an attachment tombstone.
Readers see an italic deleted-content notice instead of a preview.

Reason: A user's storage cleanup must not remove or structurally damage the
shared conversation, but the deleted content must no longer be downloadable.

### Identify app installations independently of login sessions

Decision: Each Flutter installation persists a random `device_install_id`
outside session storage. A new login revokes any previous active session for
the same user and installation. Logout does not erase the installation ID.

Reason: Device name and model are not unique enough to prevent duplicated
active-device rows after logout and login.

### Preserve loaded panels and delay loading indicators

Decision: Main navigation panels are loaded lazily once and retained in an
`IndexedStack`. A full loading indicator is delayed for two seconds. Successful
mutations and their optional follow-up refreshes are handled separately, so a
refresh failure cannot turn an already completed action into a false error.

Reason: Sub-second spinners and false post-success failures make the app feel
unstable even when the underlying operation succeeded.

### Keep inactive account management private

Decision: Ordinary Sanis and secretariat staff see active accounts only.
Teacher supervision and Sani-Leitung receive a separate inactive-account
section and may manage it. Deactivation revokes every session immediately, and
login explains that the account is disabled without exposing technical detail.

Reason: Account status is administrative data, while immediate revocation and
clear login guidance are necessary for both security and support.

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

Status: The immutability decision remains active. Any earlier implication that
the creation date must not be in the future is superseded by “Allow future
sanitary start dates” above.

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

Status: Superseded by “Allow explicitly named weekend duty events” above.

### Make duty days editable and model school closures explicitly

Decision: Teacher supervision and lead first-aiders can create and edit weekday duty entries with an optional title, optional description, and a capacity from 1 to 20. They can also create named single-day or multi-day closures; weekends inside a range are skipped, and closures are stored explicitly as `is_closed`, shown in red, and cannot accept assignments.

Reason: Event days need contextual information and variable staffing, while holidays and school-free periods must remain visible and unambiguously unavailable. Existing assignments must be removed before a day can be closed, preventing silent loss of a planned duty.

Status: The weekday-only, optional-title, and 1–20 portions are superseded by
the newer required-title, explicit-weekend-event, and 1–50 decision above.

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
## 2026-07-26

### Store encrypted off-site backups at All-Inkl

Decision: All-Inkl triggers the SSD Manager database backup through a dedicated,
secret-protected Railway HTTPS endpoint each day. Railway creates a consistent
SQL dump, compresses it, encrypts it with authenticated XChaCha20-Poly1305 and
uploads only the encrypted file plus a non-sensitive checksum manifest over
FTPS to a dedicated SSD Manager account. Remote files are retained for 30 days;
operational run records are retained for 90 days. The recovery key is stored
separately from All-Inkl.

Reason: This reuses the owner's established StudyConnect backup provider while
keeping the two products isolated and ensuring the storage provider cannot read
student data. Thirty daily generations cover delayed discovery and routine
recovery without indefinite duplication of personal data.

Operational status: Configured on 2026-07-26 with a dedicated FTP account rooted
at `/ssd-manager-backups/`, a daily 03:35 KAS task, and failure notifications to
the MinutMate administration mailbox. The first encrypted production backup was
uploaded and successfully authenticated, decrypted, and gzip-validated in a
local restore drill. StudyConnect configuration was not changed.

### Maintain a separate SSD Manager legal package

Decision: SSD Manager keeps its editable school-contract, privacy, security,
retention, DPIA, operational-process, onboarding, and store-disclosure drafts in
`docs/legal-release-package/`. StudyConnect supplies reusable MinutMate company
facts, contract structure, and provider evidence only. Product functions,
data categories, active processors, storage, deletion, and security statements
must be verified against SSD Manager itself and may not be copied by renaming.
Private signed/provider evidence remains Git-ignored.

Reason: The two products have different purposes, data flows, vendors, and
risks. A product-specific package supports school procurement and GDPR
accountability without importing false StudyConnect claims into a public
repository.
## 2026-07-26: School-specific commercial terms

Decision: SSD Manager has no standard price, contract term, notice period, or
pilot-model conditions in its reusable legal package. These terms are agreed
individually with each school or school authority and recorded in the specific
offer or contract attachment. Public distribution does not change the closed,
manually approved school-onboarding model.

Reason: School scope, support needs, pilot structure, responsible authority,
and commercial framework can differ materially. A fixed reusable default would
create avoidable contradictions with individually negotiated agreements.

## 2026-07-26: Public SSD Manager website paths

Decision: The canonical product origin is `https://ssd-manager.minutmate.com`.
The stable public paths are `/impressum/`, `/datenschutz/`,
`/nutzungsbedingungen/`, `/avv/`, `/toms/`, `/unterauftragnehmer/`,
`/loeschkonzept/`, `/konto-loeschen/`, and `/support/`. Static source files live in `website/` and
are published by the owner after local review.

Reason: Apple App Store, Google Play, schools, and data-protection materials
need durable, product-specific URLs before release submission.
