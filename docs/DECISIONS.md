# SSD Manager Decisions

This file records durable project decisions so they are available across local Codex chats, the MacBook, the Windows PC, and Codex Cloud. Keep entries concise, factual, and dated.

Do not store secrets, credentials, tokens, signing keys, real student data, or private account details here.

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
