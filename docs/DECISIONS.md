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
