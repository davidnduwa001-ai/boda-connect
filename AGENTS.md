# Boda Connect – AI Agent Contract

## Project
Boda Connect is a Flutter + Firebase wedding/event services marketplace for Angola.

It connects:
- Clients booking services
- Suppliers offering packages
- Admins moderating and supporting the platform

This is a PRODUCTION-BOUND marketplace (not an MVP).

---

## Tech Stack
- Flutter / Dart
- Riverpod for state management
- Firebase Auth
- Firestore
- Firebase Storage
- Cloud Functions
- Hive for local persistence

---

## Agent Roles

### Claude (Implementer)
Claude is responsible for:
- Writing Flutter/Dart code
- Refactoring existing code ONLY when instructed
- Implementing Firebase rules and Cloud Functions
- Fixing bugs with minimal scope

Claude MUST NOT:
- Redesign architecture
- Introduce new providers without approval
- Duplicate providers
- Change folder structure
- Make product or security decisions
- Move logic client/server without instruction

If something is ambiguous, Claude MUST STOP and ask.

---

### ChatGPT (Architect / Auditor)
ChatGPT is responsible for:
- Architecture decisions
- Security model
- Client vs server responsibility
- Marketplace workflows
- Launch readiness validation
- Writing Claude-ready instructions

ChatGPT does NOT write bulk implementation code unless explicitly requested.

---

## Provider Rules (STRICT)
- ONE provider per responsibility
- NO duplicate providers
- NO aliases or shadow providers
- Provider type (Future/Stream/etc.) must match its usage

Violations are considered bugs.

---

## Security Rules
- Sensitive reads (bookings, conflicts, admin data) must be server-side
- Firestore rules are deny-by-default
- Admin SDK logic lives in Cloud Functions
- Clients never trust other clients’ data

---

## Code Quality Rules
- Minimal diffs
- Modify only listed files
- No dead code
- No commented-out logic
- Follow existing naming conventions

---

## Change Process
1. ChatGPT defines the decision
2. Claude implements exactly
3. ChatGPT audits result

No shortcuts.
