# Wayfarer Sync — Stitch UI Redesign (Mobile)

**Date:** 2026-07-04
**Scope:** `wayfarer-sync/mobile` (primary) + a small `wayfarer-sync/backend` change set
(user first/last name, §11) shipped as its own PR.
**Status:** Approved design — ready for implementation plan

## 1. Goal

Adopt the Stitch mockup visual language across the mobile app without hardcoding any
UI value. The look is driven entirely from the central token layer so light and dark
themes both work and future re-skins touch one place. Six surfaces are in scope:
Auth (Login + Signup), Trips tab, Create Trip, Join dialog, Trip View (map), and a new
Profile tab. A bottom-navigation shell (Trips · Profile) is introduced. Users now have a
first/last name (small backend change, §11) so avatars and the Profile header show real
initials and names instead of parsed email.

The four Stitch mockups (`Trips.html`, `Profile.html`, `join trip.html`, `Trip Map.html`)
disagree with each other in several places; this spec is the single reconciled source of
truth. Where a mockup conflicts with this document, this document wins.

## 2. Constraints (standing)

- **No hardcoded UI.** No raw hex, no magic spacing in screens/widgets. Colors resolve
  through `ColorScheme`, `context.semantic.*`, `Theme.of(context).textTheme` / `monoData`,
  and the `AppSpace` / `AppRadius` scales. A missing value means adding a token first.
- **Light + dark.** Every token has a light and a dark value; dark is switchable at runtime
  and persisted (existing `themeModeProvider`).
- **File naming.** New files use `snake_case`; existing `camelCase` files keep their names
  (no bulk rename).
- **Do not commit.** Changes stay in the working tree until the user decides.
- **One package.** All work is inside `wayfarer-sync/mobile`.
- **No emoji in any input.** Every text input in the app (auth email/password, trip name,
  destination search, join Trip ID) rejects emoji and other pictographic / surrogate-pair
  characters at the input layer, so no such character can reach the backend/DB. See §6.2.
- **No profile pictures.** The backend stores no avatar image; every avatar in the app is a
  derived **name monogram** (initials from the user's first + last name, email fallback).
  See §6.1 and §11.

## 3. Design system (token remap)

The existing token layer (`core/theme/`) is already structured correctly and already uses
Plus Jakarta Sans for body text. The remap changes values, not architecture.

### 3.1 `appTokens.dart` — `AppPalette`

Swap the "Field Instrument" palette for the Stitch Material 3 palette. Roles map as:

| Semantic role        | Light      | Dark (derived) |
| -------------------- | ---------- | -------------- |
| accent / route       | `#FF5722`  | `#FF8A65`      |
| onRoute              | `#FFFFFF`  | `#591C00`      |
| primary (rust)       | `#B02F00`  | `#FFB5A0`      |
| background           | `#F8F9FA`  | `#1A1110`      |
| surface (card)       | `#FFFFFF`  | `#241A18`      |
| onSurface            | `#191C1D`  | `#F0E0DB`      |
| onSurfaceVariant     | `#5B4039`  | `#D8C2BA`      |
| hairline / outline   | `#E4BEB4`  | `#3A2C28`      |
| active green         | `#1B6D24`  | `#88D982`      |
| activeContainer      | `#A0F399`  | `#005312`      |
| onActiveContainer    | `#217128`  | `#A3F69C`      |
| peer blue            | `#005CAB`  | `#A5C8FF`      |
| peerContainer        | `#1775D1`  | `#004786`      |
| error                | `#BA1A1A`  | `#FFB4AB`      |
| errorContainer       | `#FFDAD6`  | `#93000A`      |
| statValue            | `#B02F00`  | `#FFB5A0`      |

`AppSpace` and `AppRadius` scales are unchanged (they already match the mockup's
`xs/sm/md/lg/xl` and `rounded-2xl = 16px = AppRadius.md`). Add `AppRadius.xl = 20` only
if a card needs the larger corner; otherwise reuse `md`.

### 3.2 `appSemanticColors.dart` — `AppSemanticColors`

Add four fields to the extension (with light + dark values, `copyWith`, and `lerp`):

- `activeContainer`, `onActiveContainer` — the green "Active" pill background/foreground.
- `endedContainer` — neutral pill background for the "Ended" status (maps to a
  surface-variant tone).
- `statValue` — the accent color for stat-tile numbers.

Existing fields keep their names but repoint to the new palette:
`route → #FF5722`, `signalOnline → active green`, `destinationPin → #FF5722`
(the flag pin is orange in the map + create mockups), `peerFallback → peer blue`.

### 3.3 `appTheme.dart`

- `display(...)` helper switches `GoogleFonts.bricolageGrotesque` → `GoogleFonts.plusJakartaSans`.
- `monoData(...)` stays `GoogleFonts.jetBrainsMono` (trip IDs / coordinates signature).
- `colorScheme.copyWith` gains explicit `secondary`/`secondaryContainer`/`tertiary`/
  `error`/`errorContainer` from the new palette so Material components match the mockups
  rather than seed-derived approximations.
- Type scale aligned to the mockup: `displaySmall 24/700`, `headlineSmall 22/700`,
  `titleLarge 18/600`, `titleMedium 16/600`, `bodyLarge 14/400`, `bodyMedium 14/400`,
  `labelLarge 12/600` (uppercase tracking applied at call sites via `SectionHeader`).

No screen or widget imports `AppPalette` directly (enforced by review/grep).

## 4. Navigation shell

Introduce a `StatefulShellRoute.indexedStack` in `core/network/router.dart` with two
branches:

- Branch 0 → `/trips` (Trips tab)
- Branch 1 → `/profile` (Profile tab)

A new `core/widgets/app_scaffold_shell.dart` renders the shared bottom `NavigationBar`
(2 destinations: `flight_takeoff` "Trips", `person` "Profile"; active destination uses the
green `activeContainer` pill via `NavigationBarThemeData`). The shell hosts the branch
navigator as its body.

Routes **outside** the shell (pushed full-screen, no bottom bar): `/login`, `/signup`,
`/create-trip`, `/trip/:tripId/map/:userId`. The redirect logic is unchanged except the
authenticated landing route stays `/trips`.

## 5. Screens

### 5.1 Auth — Login & Signup (`features/auth/screens/`)

No mockup provided; design to the new system. Card-on-background layout, Jakarta display
heading, orange primary CTA (`PrimaryButton`), themed inputs.

- **Signup adds First name, Last name, and Confirm password fields.** Name fields are
  required (trimmed, non-empty) and carry the no-emoji rule (§6.2). Client-side validation:
  non-empty first/last name + email + password, and `password == confirmPassword` (else
  inline error "Passwords don't match."). Signup now posts `firstName` + `lastName` to the
  backend (§11); login is unchanged.
- On a successful login/signup the response `user` (email + first/last name) is persisted
  and exposed via `currentUserProvider` (§7) for the Profile tab.
- Error surface uses existing `InlineErrorBanner`.

### 5.2 Trips tab (`features/trip/screens/tripsScreen.dart`)

- **Active trips only.** `_Dashboard` filters to `trip.isActive`; the "Ended" section is
  removed from this screen (ended trips move to Profile → Trip History).
- Stat row (3 `StatTile`s): Active count, Travelers (sum of `memberCount`), Destinations.
  Counts computed from the active list.
- `SectionHeader` "ACTIVE TRIPS" with hairline rule.
- Restyled `TripDashboardCard` per §5.6.
- **Search:** app-bar search icon toggles an inline search `TextField` (with clear/close).
  Filters the already-loaded active trips **client-side** by `title` + primary destination
  name, case-insensitive. Empty query → full list. No matches → "No trips match '<query>'"
  empty state. No backend call, works offline. Search state is local `useState`/`StatefulWidget`
  state, cleared when the field is closed.
- FAB stack unchanged (Join + New trip), restyled by theme.
- Logout action moves off this app bar (now lives on Profile); the Trips app bar shows only
  the title and the search icon.

### 5.3 Create Trip (`features/trip/screens/createTripScreen.dart`)

Layout unchanged (map + top search card + bottom action bar). Visual only: orange pin
marker (`context.semantic.destinationPin`), themed card + inputs, orange "Start trip"
button. The "Trip created" dialog restyled to match §5.5 dialog style. No logic changes to
geocoding, create, or refresh.

### 5.4 Trip View / Map (`features/tracking/screens/tripMapScreen.dart`)

**Overlay restyle only. GPS, trail colors, OSRM routing, sync, and lifecycle are untouched.**

- Member chips row: pill chips with colored avatar + name, selected chip uses
  `activeContainer`.
- Floating controls: circular recenter + zoom `+` / `−` buttons (the zoom buttons and
  `_zoomBy` already exist — restyle to circular themed buttons).
- Bottom glass panel: "Trip ID" label + `monoData` id + a "Syncing…" indicator driven by
  existing connectivity/sync state (no new state).
- Destination flag marker: orange, matching create screen.

### 5.5 Join dialog (`features/trip/screens/tripsScreen.dart` `_JoinTripDialog`)

Restyle to the mockup: circular `group_add` icon badge, "Join a Trip" heading, helper text,
a `key`-prefixed input **labeled "Trip ID"** (not "Session ID"; the app joins by UUID).
Primary "Join trip" + secondary "Cancel". Behavior unchanged: validates non-empty, calls
`tripsProvider.notifier.join`, and on `alreadyMember` pushes the map; otherwise shows the
"Joined" snackbar. UUID format errors surface the backend 400 message.

### 5.6 `TripDashboardCard` (`features/trip/widgets/trip_dashboard_card.dart`)

Restyle to the mockup card: title + destination line, avatar cluster + "N members", date
row (`calendar_today` + `monoData` short date), status pill (Active/Ended via
`StatusPill`), and the `⋮` overflow (Share always; End trip only when active). Ended cards
render at reduced opacity. The overflow menu and callbacks are unchanged.

### 5.7 Profile tab — NEW (`features/profile/screens/profile_screen.dart`)

New `features/profile/` feature folder. `ConsumerWidget` reading `currentUserIdProvider`,
the user email (from the auth token / provider), and `tripsProvider`.

Sections:
- **Identity:** a circular avatar showing a **name monogram** (colored disc, `onRoute`
  text on `route` fill), the user's full name ("First Last") as the heading, and the email
  beneath it. No fake "Pro Traveler" badge. The backend stores no profile picture, so the
  avatar is always a derived monogram (see §6.1). No `<img>`/network avatar anywhere in the
  app. Name + email come from `currentUserProvider` (§7).
- **Travel Summary:** real `StatTile`s — total trips, active trips, destinations —
  computed from `tripsProvider` data.
- **Trip History:** ended trips (`!trip.isActive`) rendered as compact history rows
  (icon tile + title + relative date + chevron), tapping opens the trip map read-only via
  the existing route. Empty state: "No past trips yet."
- **Account:** theme light/dark toggle (drives `themeModeProvider`), logout
  (`authTokenProvider.notifier.clearToken`).
- Version footer (app name + version string from a constant, not hardcoded per-widget).

No countries/miles/payment/help rows (no backing data — YAGNI).

## 6. New / changed widgets

Reuse existing leaf widgets (`StatTile`, `StatusPill`, `SectionHeader`,
`MemberAvatarCluster`, `PrimaryButton`, `GlassPanel`, `InlineErrorBanner`, `SkeletonBox`).
New widgets:

- `core/widgets/app_scaffold_shell.dart` — bottom-nav shell.
- `features/profile/widgets/history_row.dart` — Profile trip-history row.
- `features/profile/widgets/setting_row.dart` — Account section row (toggle / action).

`core/widgets/contourBackground.dart` and `tripTicketCard.dart` are retained only if still
referenced after the redesign; unused widgets are deleted (with matching doc cleanup).

### 6.1 Name monogram (`core/util/name_monogram.dart`)

Pure function `nameMonogram({String? firstName, String? lastName, required String email})
-> String` producing a 1–2 character disc label, since the backend stores no profile
picture. Rule (result always uppercased):

- If both `firstName` and `lastName` have a first letter → `firstName[0] + lastName[0]`
  (e.g. "Kunal Sharma" → `"KS"`). This is the normal case for all accounts created after
  §11 ships.
- Else if only one name is present → that name's first letter.
- **Email fallback** (legacy accounts with no name): operate on the email local part
  (before `@`), stripped to letters/digits and uppercased — first char + middle char
  (`local[0] + local[local.length ~/ 2]`); single-char → that char; empty → `"?"`.
  Example: `kunal@essentia.dev` → `"KN"`.

Rendered in a colored circle (`route` fill, `onRoute` text), reused by the Profile identity
avatar and any other single-user avatar surface. Single source of truth for user avatars —
`MemberAvatarCluster` keeps its per-member colors for map/card clusters and is unchanged.

### 6.2 Emoji-free input rule (`core/util/text_input_rules.dart`)

A shared `TextInputFormatter` (`noEmojiFormatter`) that blocks emoji and other
pictographic / surrogate-pair code points as the user types, exported alongside a small
helper `applyInputRules(...)` (or a thin `AppTextField` wrapper) so every text entry point
opts in consistently. Applied to **all** inputs: login/signup email + password, trip name,
destination search, and the join Trip ID field. Rejected characters are silently dropped
(not error-flagged) — the field simply won't accept them. The blocked ranges cover the
Unicode emoji blocks and unpaired/paired surrogates; the exact ranges live as
`UPPER_SNAKE_CASE` constants in this module, not inline in screens. Because rejection
happens at the input layer, no emoji reaches any request body or the backend/DB.

## 7. Data / providers

One new provider: `currentUserProvider` — exposes the signed-in user's `email`, `firstName`,
`lastName` (and `id`). It reads the `user` object returned by login/signup, persisted to
`shared_preferences` alongside the JWT; on cold start with a token but no cached user it
falls back to `GET /me` (existing `getMe`). A small `CurrentUser` model
(`features/auth/models/current_user.dart`, snake_case) mirrors the backend `userSchema`
(email + first/last name) via `fromJson`.

Reused: `tripsProvider` (active + ended both already returned by the membership-scoped
`listMyTrips`; the tabs partition the same list), `themeModeProvider`, `authTokenProvider`,
`currentUserIdProvider`. Profile stats and history are pure derivations of `tripsProvider`
data — no new fetch, no N+1.

## 8. Out of scope

- The only backend change is adding user first/last name (§11). Join stays UUID-based; no
  short trip codes; no other endpoint contract changes.
- No changes to GPS/trail/OSRM/sync logic on the map screen.
- No new list endpoints or pagination changes.
- No vanity profile metrics.

The work spans **two units** (backend + mobile). They are separate change sets: §11
(backend name) ships first so the mobile signup/Profile can rely on it. Keep them as
distinct commits/PRs.

## 9. Verification

Flutter is not installed in this environment, so runtime verification is the user's:

```
cd wayfarer-sync/mobile && flutter pub get && flutter analyze && flutter test
```

Static checks performed here after each phase:
- `grep` for raw hex (`#`), `Color(0x`, and inline `style:`/color literals in touched
  screens/widgets — must be zero (token layer excepted).
- All imports resolve; no dangling references to removed symbols.
- Model/provider/widget symbol names consistent across call sites.
- `grep` every `TextField` / text input in the app and confirm each wires the shared
  no-emoji formatter — no input may accept raw text without it.
- Unit tests for `nameMonogram` (first+last initials, single name, email fallback for empty
  names, non-letters) and for `noEmojiFormatter` (strips emoji, keeps letters/digits/
  punctuation) run under `flutter test`.

Backend (§11) is verifiable here (Bun is installed):

```
cd wayfarer-sync/backend && bun test
```

- Signup test asserts `firstName`/`lastName` are stored and echoed in the response `user`,
  and that a missing/blank name returns 400; an emoji-laden name is rejected by the name
  validator. `bun run tsc` (or build) clean on changed files.

`mobile/README.md` updated in the same change set for: new Profile tab + bottom-nav shell,
Trips search, active-only Trips, and the palette/font remap.

## 10. Phasing (for the implementation plan)

Each phase leaves the app compiling.

0. **Backend — user name (§11)** — separate change set, ships first: Prisma `firstName`/
   `lastName`, Zod signup + user schema, service/controller, `db push`, auth tests. This is
   the only backend PR.
1. **Foundation** — token remap (`appTokens`, `appSemanticColors`, `appTheme`) + the two
   shared utils (`core/util/name_monogram.dart`, `core/util/text_input_rules.dart`) with
   their unit tests. Whole app reskins; helpers ready for later phases.
2. **Nav shell + Profile scaffold** — `StatefulShellRoute`, `app_scaffold_shell`, empty
   Profile screen + route.
3. **Trips tab** — active-only, stat row, search, restyled `TripDashboardCard`.
4. **Create + Join** — restyle create screen + created dialog + join dialog; apply the
   no-emoji rule to trip name, destination search, and join Trip ID.
5. **Map overlays** — chips, zoom/recenter buttons, bottom glass panel (visual only).
6. **Profile content + Auth** — `currentUserProvider` + `CurrentUser` model, Profile
   history/stats/account with the name-monogram avatar and full-name heading, Login/Signup
   restyle, Signup first/last name + confirm-password, and the no-emoji rule on all auth
   fields. README update.

---

## 11. Backend change set — user first/last name

Separate PR in `wayfarer-sync/backend`. Ships before the mobile signup/Profile work.

### 11.1 Schema

- `prisma/user.prisma` — add `firstName String?` and `lastName String?` to `model User`.
  Nullable so no data migration is needed for any existing rows; the signup API requires
  them, so every new account is fully named, and the mobile monogram/name display fall back
  to email for any legacy null (§6.1). Apply with `bun run db push` (dev) and regenerate the
  Prisma client (never hand-edit `src/generated/**`).
- `schema/user.ts` — extend `userSchema` with `firstName` and `lastName`
  (`z.string().nullable()` on the read model, since older rows may be null). This flows
  automatically into the auth response (`authResponseSchema.user`) and `getMe`.

### 11.2 Signup contract

- `schema/auth.ts` — `signupInputSchema` gains `firstName` and `lastName` using a shared
  **`safeNameSchema`**: `z.string().trim().min(1).max(50)` refined to reject emoji /
  pictographic / control characters (defense-in-depth so a non-mobile client can't crash the
  DB/BE; mirrors the mobile no-emoji rule §6.2). The emoji-range check lives as a named
  constant/regex in the schema module. `loginInputSchema` is unchanged.

### 11.3 Service + controller

- `auth.service.ts` — `createUser(email, password, firstName, lastName)` persists the names.
- `auth.controller.ts` — `signup` reads `firstName`/`lastName` from the validated body and
  passes them to `createUser`. The response already returns `userSchema.parse(...)`, so the
  names round-trip to the client with no extra wiring. `login`/`getMe` return names for free
  once the schema includes them.

### 11.4 Tests + docs

- Extend the existing auth tests: signup stores + echoes `firstName`/`lastName`; blank name →
  400; emoji name → 400. Keep the existing UUID-validity lesson in mind for any id fixtures.
- Update `backend/README.md` for the new signup body fields and the `user` response shape.
