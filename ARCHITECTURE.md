# Sambo — Architecture

A two-person household app: shared budget pulled from Tink (later), a chore
tracker with multi-user completion history ("Idag · Gustav + Sambo"), and
Google Sign-In on iOS + Android so neither of you has to juggle credentials.

This document is the canonical map. When something below stops matching the
code, the **code is right** — fix the doc.

---

## 1. System overview

```
                              ┌───────────────────────────────┐
                              │        Google Identity        │
                              │  (OAuth: iOS / Android / Web) │
                              └──────────────┬────────────────┘
                                             │ ID-token (JWT, signed by Google)
                                             ▼
   ┌─────────────────────┐         ┌──────────────────────────┐         ┌──────────────────┐
   │   Flutter mobile    │ ──────▶│      Spring Boot 3.5     │ ──────▶│   PostgreSQL 16  │
   │   (iOS + Android)   │  HTTPS │      api.sambo (8080)    │   JDBC  │   sambo / sambo  │
   │   sambo_client      │ ◀──────│  Java 25 LTS + Hibernate │ ◀──────│   Flyway-managed │
   └─────────────────────┘  bearer└──────────────┬───────────┘         └──────────────────┘
              ▲                JWT (HS256)        │
              │                                   │ outbound
              │                                   ▼
              │                           ┌──────────────────┐
              └───── (future) ────────────│   Tink (PSD2)    │
                                          │   bank pull APIs │
                                          └──────────────────┘
```

The mobile client never talks to Tink directly; the backend is the trusted
boundary that signs/verifies tokens, holds Tink credentials, and enforces
tenant isolation on every read.

---

## 2. Frontend — `client/`

Flutter 3.41+ (Dart 3.11+). Material 3, dark-only. Inter typography.

### 2.1 Layout

```
client/lib/
├── main.dart                       7-line entry point
├── config.dart                     compile-time constants (Google Web client ID, backend URL)
├── app/
│   ├── app.dart                    SamboApp — MaterialApp.router root
│   ├── app_init_service.dart       startup orchestrator (auth restore, future hooks)
│   └── router.dart                 go_router config + auth-driven redirect
├── core/
│   └── http_exception.dart         shared HTTP error type with statusCode
├── models/                         pure data, no logic
│   ├── auth_user.dart
│   ├── budget.dart                 BudgetCategory, CategoryStatus, MonthlyOverview, Transaction
│   ├── chore.dart                  Chore + UserSummary
│   ├── household.dart              Household (id + name)
│   └── invite.dart
├── services/                       business logic & singletons
│   ├── api_client.dart             central HTTP wrapper (auth header + 401 → signOut)
│   ├── auth_service.dart           Google sign-in + JWT storage + setSession
│   ├── budget_service.dart         /api/budget/** wrapper
│   ├── chore_service.dart          /api/chores/** wrapper
│   ├── household_service.dart      /api/household/{,/members} wrapper
│   └── invite_service.dart         /api/invites/** wrapper, calls AuthService.setSession on accept
├── screens/                        one widget per screen
│   ├── login_screen.dart           hero login with logo + radial-gradient backdrop
│   ├── home_shell.dart             post-login chrome (NavigationBar + IndexedStack)
│   ├── budget_screen.dart          monthly view, month switcher, category cards
│   ├── category_detail_screen.dart big metrics card, transaction list, edit/delete
│   ├── chores_screen.dart          segmented active/archived, completion sheet, schedule
│   └── settings_screen.dart        avatar, household rename, invite generate/accept, sign out
└── theme/
    ├── sambo_app_colors.dart       palette (orange/navy)
    └── sambo_theme.dart            ThemeData (Inter, rounded cards, segmented button styling)
```

### 2.2 Key dependencies

| Package | Why |
|---|---|
| `google_sign_in` ^7 | Native account picker on iOS/Android |
| `flutter_secure_storage` ^10 | JWT + user record persisted across launches |
| `http` ^1 | Backend API calls (wrapped in `ApiClient`) |
| `go_router` ^17 | Declarative routes + auth-state-driven redirect |
| `google_fonts` | Inter typography (downloaded at runtime, cached) |
| `flutter_launcher_icons` (dev) | Generates platform icons from `assets/icons/app_icon.png` |

### 2.3 State patterns

- **Auth state** is a `ValueNotifier<AuthUser?>` on `AuthService.instance`.
- The router's `refreshListenable` is bound to that notifier — flipping the
  user value (login, logout, accept invite) re-runs the redirect callback,
  which sends the user to `/` or `/login` automatically. Screens never call
  `Navigator.push` to handle auth transitions.
- Screen-local UI state lives in `StatefulWidget`s. There is no global state
  framework yet (Riverpod / Bloc) — added when data flow stops fitting
  into singletons.
- Accepting an invite calls `AuthService.setSession(jwt, user)` with the
  fresh JWT issued by the backend (the old JWT carried the wrong householdId).

### 2.4 Build-time configuration

`String.fromEnvironment` reads `--dart-define` flags at compile time:

- `GOOGLE_SERVER_CLIENT_ID` — Google Web OAuth client ID, also used as
  `serverClientId` for `google_sign_in`. Backend's audience list must include
  this value.
- `BACKEND_BASE_URL` — overrides the default per-platform URL.

VS Code `launch.json` injects these for F5 debug. Defaults in `config.dart`
are dev-safe (real Web client ID, plus per-platform `localhost`/`10.0.2.2`
fallback for emulators).

### 2.5 iOS-specific config

`ios/Runner/Info.plist` carries `GIDClientID` (the iOS OAuth client ID) plus
a `CFBundleURLTypes` entry with the reversed iOS client ID as URL scheme
(`com.googleusercontent.apps.<client-id>`) — Google's OAuth callback uses
that to return to the app. The backend audience list must include both Web
and iOS client IDs because the issued ID-token's `aud` claim is the iOS one
on iPhones.

---

## 3. Backend — `server/`

Spring Boot 3.5.3 on Java 25 LTS. Build with Maven via `./mvnw`.

### 3.1 Layout

```
server/src/main/java/com/sambo/
├── SamboApplication.java
├── auth/
│   ├── AuthController.java         POST /api/auth/google
│   ├── AuthService.java            Google ID token → AppUser → server JWT
│   ├── config/
│   │   ├── GoogleAuthProperties.java   sambo.google.audiences (list)
│   │   └── JwtProperties.java          sambo.jwt.{secret, issuer, audience, ttl}
│   ├── google/
│   │   ├── GoogleIdTokenValidator.java   verifies ID token via Google JWKS + aud
│   │   ├── GoogleUserInfo.java
│   │   └── InvalidGoogleTokenException.java  → 401
│   ├── jwt/
│   │   ├── JwtService.java         issue/verify HS256 JWTs
│   │   ├── JwtClaims.java
│   │   ├── SamboPrincipal.java     authenticated principal in SecurityContext
│   │   └── JwtAuthenticationFilter.java   per-request bearer-token filter
│   └── dto/
│       ├── AuthUserDto.java
│       ├── GoogleLoginRequest.java
│       └── LoginResponse.java
├── household/
│   ├── Household.java                  entity (renamable)
│   ├── HouseholdController.java        GET/PUT /api/household, GET /api/household/members
│   ├── HouseholdRepository.java
│   ├── AppUser.java                    entity (with role)
│   ├── AppUserRepository.java
│   ├── Role.java                       enum (USER, ADMIN)
│   ├── Invite.java                     entity (code, expiresAt, usedAt)
│   ├── InviteRepository.java
│   ├── InviteService.java              generate code, accept (moves user, mints new JWT)
│   ├── InviteController.java           POST /api/invites, POST /api/invites/accept
│   ├── InvalidInviteException.java     → 400
│   └── dto/
│       ├── HouseholdDto.java
│       ├── UpdateHouseholdRequest.java
│       ├── InviteDto.java
│       ├── AcceptInviteRequest.java
│       └── AcceptInviteResponse.java
├── budget/
│   ├── BudgetController.java          /api/budget/**
│   ├── BudgetService.java             tenant-scoped category + allocation logic
│   ├── HouseholdCategory.java         template at household level
│   ├── HouseholdCategoryRepository.java
│   ├── BudgetPeriod.java              (year, month, household)
│   ├── BudgetPeriodRepository.java
│   ├── BudgetAllocation.java          monthly $ per category
│   ├── BudgetAllocationRepository.java
│   ├── BudgetCategoryStatusView.java  read-only mapping over the SQL view
│   ├── BudgetCategoryStatusRepository.java
│   └── dto/                           CategoryDto, CategoryStatusDto, MonthlyOverviewDto, …
├── transaction/
│   ├── BankTransaction.java           pulled from Tink (or hand-entered today)
│   ├── BankTransactionRepository.java
│   ├── CategoryMapper.java            keyword → category rule
│   └── CategoryMapperRepository.java
├── chore/
│   ├── Chore.java                     entity (name, scheduledFor, archivedAt)
│   ├── ChoreRepository.java
│   ├── ChoreCompletion.java           append-only event log (many-to-many users)
│   ├── ChoreCompletionRepository.java
│   ├── ChoreController.java           /api/chores/**
│   ├── ChoreService.java              tenant-scoped logic + archive/unarchive
│   └── dto/                           ChoreDto, CreateChoreRequest, CompleteChoreRequest, UserSummaryDto
├── calendar/
│   ├── CalendarEvent.java             entity (title, startsAt, endsAt, allDay, color, createdBy)
│   ├── CalendarEventRepository.java
│   ├── CalendarController.java        GET/POST/PUT/DELETE /api/calendar
│   ├── CalendarService.java           tenant-scoped CRUD
│   └── dto/                           CalendarEventDto, CreateCalendarEventRequest, UpdateCalendarEventRequest
├── tink/                              credential entity (TODO: integration logic)
└── config/
    └── SecurityConfig.java            filter chain + role rules + 401 entry-point
```

### 3.2 Multi-tenancy (the most important rule)

Every request that reads or writes domain data **must scope by household_id
from the authenticated principal** — never from the URL path, request body, or
query string. The principal is populated by `JwtAuthenticationFilter` from the
verified-and-signed JWT, so a USER cannot forge a different household_id.

Pattern (every controller method):

```java
@GetMapping
public List<ChoreDto> list(@AuthenticationPrincipal SamboPrincipal principal) {
    return choreService.listForHousehold(principal.householdId());
}
```

Mutations on a specific entity additionally verify ownership before acting
(both chore and budget services use a `loadOwned*` helper):

```java
private Chore loadOwned(UUID choreId, UUID householdId) {
    Chore chore = choreRepo.findById(choreId).orElseThrow(...);
    if (!chore.getHousehold().getId().equals(householdId)) {
        throw new AccessDeniedException(...);   // → 403
    }
    return chore;
}
```

### 3.3 Auth flow

```
Flutter                  Backend                   Google
   │                         │                       │
   │  google_sign_in         │                       │
   │ ─────────────────────────────────────────────▶ │
   │ ◀────────────────────────────────────────────── │   Google ID-token
   │     (signed by Google, aud = Web client ID on Android,
   │      iOS client ID on iPhones)                   │
   │                         │                       │
   │  POST /api/auth/google  │                       │
   │  { idToken }            │                       │
   │ ───────────────────────▶│                       │
   │                         │ verify signature      │
   │                         │ via Google JWKS       │
   │                         │ aud ∈ sambo.google.audiences (Web + iOS)
   │                         │ verify email_verified │
   │                         │                       │
   │                         │ find-or-bootstrap     │
   │                         │ AppUser (1st login    │
   │                         │ creates Household,    │
   │                         │ user becomes ADMIN)   │
   │                         │                       │
   │                         │ sign HS256 JWT with   │
   │                         │ {sub, householdId,    │
   │                         │  email, role}         │
   │                         │                       │
   │ ◀───────────────────────│                       │
   │  { accessToken, user }  │                       │
   │                         │                       │
   │  flutter_secure_storage │                       │
   │  store JWT + user       │                       │
   │                         │                       │
   │ subsequent calls:       │                       │
   │ Authorization: Bearer.. │                       │
   │ ───────────────────────▶│                       │
   │                         │ JwtAuthenticationFilter:
   │                         │   verify HS256        │
   │                         │   require iss + aud   │
   │                         │   put SamboPrincipal  │
   │                         │   in SecurityContext  │
   │                         │                       │
   │                         │ controller reads      │
   │                         │ @AuthenticationPrincipal
```

**Token lifecycle:** access JWT TTL is 24h while developing
(`sambo.jwt.access-token-ttl`). No refresh-token flow yet — when the access
token expires, `ApiClient` catches the resulting 401 and triggers
`AuthService.signOut()`, which lets the router redirect back to `/login`.
Refresh tokens are a TODO before public release.

**Invite-driven JWT swap:** when a user accepts an invite via
`POST /api/invites/accept`, they're moved to the inviter's household with
`role=USER`. The response carries a *new* JWT (the old one carries the wrong
householdId/role); Flutter swaps it via `AuthService.setSession(...)` so
subsequent calls have the correct tenant context.

### 3.4 Endpoints

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/api/auth/google` | none | Google ID-token → server JWT |
| GET | `/api/household` | JWT | The current user's household (id, name) |
| PUT | `/api/household` | JWT | Rename household. Body `{name}` |
| GET | `/api/household/members` | JWT | List household users (id, displayName) |
| POST | `/api/invites` | JWT + ROLE_ADMIN | Generate 6-char invite code (24h TTL) |
| POST | `/api/invites/accept` | JWT | Accept code → swap household, return new JWT |
| GET | `/api/chores?archived=` | JWT | List chores; `archived=true` for soft-archived |
| POST | `/api/chores` | JWT | Create. Body: `{name, lastCompletedAt?, scheduledFor?}` |
| POST | `/api/chores/{id}/complete` | JWT | Body `{userIds?}` — multi-user. Empty = caller solo. |
| POST | `/api/chores/{id}/archive` | JWT | Soft delete (preserves history) |
| POST | `/api/chores/{id}/unarchive` | JWT | Restore archived chore |
| DELETE | `/api/chores/{id}` | JWT + ROLE_ADMIN | Hard delete |
| GET | `/api/budget/{yyyy-MM}` | JWT | Monthly overview from `v_budget_category_status` |
| GET | `/api/budget/categories` | JWT | List household categories |
| POST | `/api/budget/categories` | JWT | Create category |
| DELETE | `/api/budget/categories/{id}` | JWT | Delete category (allocations cascade, transactions un-categorised) |
| PUT | `/api/budget/{yyyy-MM}/categories/{id}` | JWT | Upsert allocation amount |
| GET | `/api/budget/transactions` | JWT | Filter `?yearMonth&categoryId` |
| POST | `/api/budget/transactions` | JWT | Hand-enter a purchase |
| DELETE | `/api/budget/transactions/{id}` | JWT | |
| GET | `/api/calendar` | JWT | List household events; `?from&to` to filter by range |
| POST | `/api/calendar` | JWT | Create event |
| PUT | `/api/calendar/{id}` | JWT | Update event |
| DELETE | `/api/calendar/{id}` | JWT | Delete event |

ROLE_ADMIN is currently only required where the operation is destructive or
admin-only (delete chore, generate invite). Day-to-day operations
(create/complete/archive chore, create/edit/delete budget categories) are
open to all household members.

---

## 4. Database — PostgreSQL 16

### 4.1 Schema

```
household ─┬── app_user                             (1:N) — Google identity → role
           ├── invite                               (1:N) — short codes, expiresAt, usedAt/usedBy
           ├── household_category                   (1:N) — "Mat", "Hushåll", ...
           ├── budget_period                        (1:N) — (year, month) per household
           │      └── budget_allocation             (1:N) — budget per category per month
           ├── bank_transaction                     (1:N) — pulled from Tink (or hand-entered)
           ├── category_mapper                      (1:N) — keyword → category rule
           └── chore                                (1:N) — name, scheduledFor, archivedAt
                  └── chore_completion              (1:N) — append-only event log
                            └── chore_completion_user   (M:N → app_user) — who did it

app_user ── tink_credential                         (1:N) — encrypted access/refresh tokens
chore_completion ── M:N ── app_user                 — multiple participants per event
bank_transaction.category_id → household_category   (N:1, nullable for un-categorised)

VIEW v_budget_category_status:
   one row per (period, category) with budgeted_amount, spent_amount, remaining_amount
   pre-aggregated from bank_transaction. Indexed query — Flutter gets a fully-rendered
   monthly overview in one HTTP call.
```

Sign convention for `bank_transaction.amount`: positive = expense, negative =
income/refund. Tink ingest (when wired) inverts the bank's native sign so
all budget math is additive.

### 4.2 Migrations

`server/src/main/resources/db/migration/` — `V<n>__<description>.sql`. Flyway
runs them in order at every Spring Boot start-up.

| | Migration | What it does |
|---|---|---|
| V1 | `init_schema` | 9-table base schema + the budget view |
| V2 | `add_app_user_role` | `app_user.role TEXT NOT NULL DEFAULT 'USER'` + CHECK |
| V3 | `add_invite` | invite table + partial index on active codes |
| V4 | `chore_completion_history` | `chore_completion` + `chore_completion_user` join, backfill from old single-user data, drop `chore.last_completed_by` |
| V5 | `add_chore_archived_at` | `chore.archived_at` (soft delete) + `chore.created_at` (audit), partial index on active |
| V6 | `add_chore_scheduled_for` | `chore.scheduled_for` forward-looking deadline + partial index |
| V7 | `manual_transactions` | `bank_transaction.tink_transaction_id` nullable, source/created-by columns for hand-entered purchases |
| V8 | `calendar_event` | shared household calendar table with all-day support |

JPA's `ddl-auto: validate` enforces that the schema Flyway produces matches
what the entity classes declare — drift is caught at start-up, not in prod.

### 4.3 Local connection

```
jdbc:postgresql://localhost:5432/sambo
user: sambo / pw: sambo
```

Override with env: `DB_URL`, `DB_USER`, `DB_PASSWORD`. The pool is HikariCP
on Spring Boot defaults (10 connections).

### 4.4 Cloud (planned)

Cloud SQL for PostgreSQL 16, private-IP only, accessed from Cloud Run via the
Cloud SQL Auth Proxy sidecar. Connection string injected via env from Secret
Manager. Migrations still run via Flyway on every container start — no
out-of-band DBA workflow.

---

## 5. Security model

| Threat | Mitigation |
|---|---|
| Forging the role on a request | Role is a JWT claim signed with `SAMBO_JWT_SECRET`. Server-only HMAC. Tampering breaks signature → 401. Server **never** reads role from header / body / path. |
| Cross-tenant data access | `householdId` taken from JWT only. Per-mutation ownership re-check in services (`AccessDeniedException` → 403). |
| Replaying a stolen JWT | Short TTL (24h dev, plan to drop to 15 min + refresh in prod). |
| Persisting Tink tokens in plaintext | Schema column is `*_ciphertext`. Encryption-at-rest via envelope encryption with KMS DEK is a TODO before Tink integration ships. |
| Forged Google ID token | `GoogleIdTokenVerifier` validates signature against Google's JWKS *and* enforces `aud ∈ sambo.google.audiences` (Web + iOS client IDs). |
| Brute-forcing invite codes | 6-char alphabet excludes ambiguous chars (no 0/O/1/I/L) → 32^6 ≈ 1B combos. Codes single-use, 24h TTL. Rate-limiting on accept is a TODO. |
| Secrets leaked in commits | `.env` ignored at both repo and `server/` levels; pre-commit hook runs `gitleaks` + hard-blocks any `*.env` file. |

Open items: rate-limiting on `/api/auth/google` and `/api/invites/accept`,
refresh-token flow, container-level DEK rotation strategy, Sign in with
Apple (mandatory for App Store publish per Apple Guideline 4.8 since we
offer Google Sign-In).

---

## 6. Deployment topology

**Live as of May 2026** — backend is deployed and reachable.

```
                               ┌───────────────────────────┐
                               │     Cloud Build / GH      │
                               │     ───── docker push ──▶ │
                               └─────────────┬─────────────┘
                                             │
                                             ▼
   ┌─────────┐   HTTPS    ┌─────────────────────────────────┐    private IP    ┌──────────────┐
   │ Mobile  │ ──────────▶│         Cloud Run               │ ───────────────▶ │  Cloud SQL   │
   │ device  │            │  sambo-api (Spring Boot)        │   (Auth Proxy    │  Postgres 16 │
   └─────────┘            │  scale 0–10, 512MB / 1 vCPU     │   sidecar)        └──────────────┘
                          │                                 │
                          │  env from Secret Manager:       │
                          │    SAMBO_JWT_SECRET             │
                          │    SAMBO_GOOGLE_AUDIENCES       │
                          │    DB_URL / DB_USER / DB_PASS   │
                          │    TINK_CLIENT_ID / SECRET (TBD)│
                          └─────────────────────────────────┘
```

**Concrete state:**
- GCP project: `sambo-app-495010`
- Cloud Run service: `sambo-api` in `europe-north1`, image at
  `europe-north1-docker.pkg.dev/sambo-app-495010/sambo/sambo-api`
- Cloud SQL instance: `sambo-db` (Postgres 16, ENTERPRISE/Sandbox tier
  `db-f1-micro`, ~10 USD/mo). Stop with `sambo-db-stop`, start with
  `sambo-db-start` (defined in `~/.zshrc`).
- Public URL: `https://sambo-api-6d4q4hcmqq-lz.a.run.app`
- Secrets: `sambo-jwt-secret`, `sambo-google-audiences`, `sambo-db-password`
- `scripts/deploy.sh` does a manual deploy in ~3 min;
  `scripts/cloudbuild.yaml` is the same as a Cloud Build trigger config.

Mobile distribution: TestFlight (iOS) is set up via Codemagic — see
`codemagic.yaml` at the repo root. The Codemagic team has an App Store
Connect API key uploaded as integration; pushes to `main` will (after
the integration name is filled in) auto-build IPA, bump build number,
and upload to TestFlight. fastlane lives in `client/ios/fastlane/` as a
local-Mac fallback.

---

## 7. Dev tooling & conventions

- **Auth secrets** live in `server/.env` (gitignored). Loaded automatically by
  the `sambo-run` shell function (sources `.env`, then `./mvnw spring-boot:run`).
- **Pre-commit hook** at `scripts/git-hooks/pre-commit` (activate per-clone with
  `git config core.hooksPath scripts/git-hooks`) blocks `.env` files outright
  and runs `gitleaks` against staged content.
- **Java code style**: jakarta.* imports, Lombok `@RequiredArgsConstructor`
  for DI, records for DTOs, package-by-feature (`com.sambo.<feature>`).
- **Dart code style**: package-imports (`package:sambo/...`), one widget per
  file, models in `models/`, services in `services/`, screens in `screens/`.
  `analysis_options.yaml` inherits `flutter_lints`.
- **Folder splits** are domain-driven (auth/household/budget/chore/transaction)
  not layer-driven (controllers/services/dtos).
- **Testing**: `flutter analyze` clean as gate. Unit tests for non-trivial
  service logic land before MVP ships. Integration tests against Testcontainers
  Postgres are deferred until Tink integration adds non-trivial flow.

---

## 8. Roadmap

| Status | Item |
|---|---|
| ✅ done | Auth (Google → server JWT, role-based authz) on Android + iOS |
| ✅ done | Multi-tenant chore module: completion history, multi-user attribution, scheduling, archive/unarchive, hard delete |
| ✅ done | Bottom-nav home shell with 4 tabs (Budget · Sysslor · Kalender · Inställningar), Inter + orange theme |
| ✅ done | Budget UI: monthly overview, category CRUD, allocation upsert, transaction CRUD, category-detail page |
| ✅ done | Manual transactions (V7) — bridge until Tink ingest ships; `bank_transaction.tink_transaction_id` now nullable + source discriminator |
| ✅ done | Calendar (V8 + module) — household-scoped events with title/description/colour, all-day toggle, REST CRUD |
| ✅ done | Invite flow — code generate + accept, household swap with fresh JWT |
| ✅ done | Household rename (via Settings) |
| ✅ done | **Cloud Run + Cloud SQL deployment** — `https://sambo-api-6d4q4hcmqq-lz.a.run.app` (europe-north1) backed by `sambo-db` Postgres 16 |
| ✅ done | JWT secret + Google audiences + DB password in GCP Secret Manager |
| ✅ done | iOS Google Sign-In end-to-end against Cloud Run prod |
| ⏳ next | **TestFlight upload** — `codemagic.yaml` ready, awaiting Codemagic integration name + first push |
| ⏳ later | Tink integration: OAuth, account selection, transaction polling, encryption at rest |
| ⏳ later | Sign in with Apple (mandatory for App Store publish) |
| ⏳ later | Refresh tokens; tighten access-token TTL from 24h → 15m |
| ⏳ later | CI/CD via GitHub Actions: PR build → deploy to staging Cloud Run |
| ⏳ later | Push notifications when partner completes a chore / spends in a category |
| ⏳ later | Rate-limiting on `/api/auth/google` and `/api/invites/accept` |
