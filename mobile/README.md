# Wayfarer Sync – Mobile Application (Flutter)

Wayfarer Sync is an offline-first, collaborative trip itinerary and real-time location mapping application built with Flutter. This mobile client relies on a local reactive SQLite database cache layer to support continuous GPS tracking in areas with compromised network coverage, automatically synchronizing data trails back to the backend once a stable internet connection is established.

---

## 🏗 Key Features & System Design

*   **Offline-First GPS Logging:** Collects background hardware coordinate streams via the `geolocator` subsystem, burning points directly into an offline SQLite engine before initiating network operations.
*   **Dual-Path Synchronization:** Dispatches live movement frames over raw persistent WebSockets when network availability is stable, while gracefully queuing points locally to be sent in an optimized HTTP batch fallback array if connection drops.
*   **Reactive UI Repainting:** Utilizes standard OpenStreetMap tile layers via `flutter_map`, repainting a **per-member colored polyline trail** (each traveler's own ordered path) and live position markers reactively using unified Riverpod state providers.
*   **Interactive Destination Pinning:** Support for searching and reverse geocoding locations via OpenStreetMap's Nominatim API, allowing users to map and pin a static destination to share when starting a trip.
*   **Traveler Centering & Tracking:** Renders a horizontal scrollable row of active members on the live map overlay. Travelers can tap any member chip to center the map on their last reported location coordinates.
*   **Bottom-Nav Shell (Trips · Profile):** A persistent `NavigationBar` (`AppScaffoldShell`, backed by `StatefulShellRoute.indexedStack`) hosts two top-level tabs — **Trips** and **Profile** — each keeping its own navigation stack and scroll position across switches.
*   **Trips Dashboard (Active-Only + Search):** The Trips tab (backed by a typed data layer — models + `TripRepository` + a Riverpod `tripsProvider`) shows only the current user's **active** trips (ended trips have moved to Profile → Trip History). Summary stat tiles (active · travelers · destinations) sit above the active-trip cards; each card shows the destination, a member colour-avatar cluster + count, a status pill, the trip id, and start date, with an overflow menu to **Share** or **End trip**. An app-bar search action swaps the title for a text field and filters the active list client-side by trip title or destination name as you type.
*   **Profile Tab:** A new dashboard-style tab showing an identity header (email-monogram avatar + display name via `nameMonogram()` — see below), real stat tiles (total trips · active · destinations), a **Trip History** section listing ended trips (tap to reopen the last map view), a **Dark mode** toggle that flips the persisted `themeModeProvider` at runtime, and a **Log out** action that clears the auth token.
*   **Trip Actions (Share & End):** Available from two surfaces — the **trip dashboard card** (3-dot menu) and the **live map screen app bar** (⋮ menu). Share opens the OS share sheet with an invite message; End Trip shows a confirmation dialog, stops live tracking for all members, and navigates back to the dashboard. The trip title is passed through the router so the app bar always shows the correct name.
*   **Trip Sharing & Joining:** After creating a trip, a confirmation dialog lets the owner copy the trip ID or send it through the native OS share sheet (`share_plus`); any trip in the dashboard is shareable via a per-card action. Others join by pasting the shared trip ID into the Join dialog — a first-time join adds the trip to their dashboard, while pasting the ID of a trip they already belong to opens its live map directly (driven by the backend's `alreadyMember` flag).
*   **Adaptive Theming (Light + Dark):** A centralized, token-driven design system — the **Stitch palette** — exposes light and dark themes (light by default, switchable at runtime and persisted from the Profile tab). No visual value is hardcoded in screens — all colours resolve through the theme and a semantic-colour extension.
*   **Identity Monogram & No-Emoji Inputs:** `core/util/name_monogram.dart` derives a 1–2 char avatar label from first/last name, falling back to an email-derived monogram for legacy accounts. `core/util/text_input_rules.dart` provides `inputRules()`, a shared `TextInputFormatter` list (emoji-stripping `noEmojiFormatter` plus any screen-specific extras) applied to every editable `TextField` in the app so emoji never reaches a request body.

---

## 🛠 Tech Stack Configuration

| Layer | Component Technology | Description |
| :--- | :--- | :--- |
| **Framework UI** | **Flutter (Material 3 Engine)** | Cross-platform UI compilation |
| **State Management** | **Flutter Riverpod** | Reactive providers and state loop managers |
| **Local Cache Store** | **Drift (SQLite Engine Wrapper)** | Type-safe, reactive local database model |
| **Mapping Engine** | **Flutter Map** | OpenStreetMap tile renderer with custom layers |
| **Hardware Core** | **Geolocator Subsystem** | Background and foreground GPS coordinates parser |
| **Networking** | **HTTP + WebSocket Channels** | Sync service pipelines and socket feeds |
| **Routing** | **go_router** | Auth-aware redirects and shared-axis page transitions |
| **Connectivity** | **connectivity_plus** | Detects network restoration to auto-trigger offline sync |
| **Persistence** | **shared_preferences** | Stores the JWT session and the selected theme mode |
| **Sharing** | **share_plus** | Native OS share sheet for trip invites |
| **Design System** | **google_fonts + animations** | Themed typography and smooth motion/transitions |

---

## 📂 Directory Architecture

The application layout follows a strict **feature-first** design system to maintain separation of concerns:

```text
lib/
├── core/
│   ├── network/       # API Rest Client, HTTP token interceptors, GoRouter, and Socket loops
│   ├── storage/       # Drift Database schema contracts & connection initializers
│   ├── theme/         # Design tokens, semantic colours, light/dark themes, ThemeMode controller
│   ├── util/          # name_monogram.dart (avatar initials), text_input_rules.dart (inputRules()/noEmojiFormatter)
│   └── widgets/       # Reusable themed widgets (primary button, glass panel, ticket card, skeleton, app_scaffold_shell…)
└── features/
    ├── auth/          # Login & signup screens with persisted JWT session
    │                  #   models/ (CurrentUser), providers/ (currentUserProvider, persistCurrentUser)
    ├── trip/          # Trips dashboard (active-only + search), creation, sharing, and the typed data layer:
    │                  #   models/ (Trip, Destination, TripMember, JoinResult),
    │                  #   repositories/ (TripRepository), providers/ (tripsProvider),
    │                  #   widgets/ (dashboard cards, stat tiles, status pill, avatar cluster)
    ├── profile/       # Profile tab: identity header, stat tiles, Trip History, theme toggle, logout
    │                  #   screens/ (profile_screen.dart), widgets/ (history_row, setting_row)
    └── tracking/      # Interactive Map screens, live GPS trackers, sync, and data repositories
```

---

## 🎨 Design System & Theming

The UI is driven entirely by a centralized theme so appearance can change in future releases without editing screens.

*   **Tokens** (`core/theme/appTokens.dart`): the single source of literal colours (the **Stitch palette** — light + dark) and the spacing/radius scale. Nothing else in the app declares raw hex or magic spacing.
*   **Semantic colours** (`core/theme/appSemanticColors.dart`): a `ThemeExtension` for brand/semantic colours (route accent, glass surfaces, online signal, map-marker colours). Widgets read them via `context.semantic.<name>` so every value adapts between light and dark automatically.
*   **Themes** (`core/theme/appTheme.dart`): `buildLightTheme()` / `buildDarkTheme()` produced from one shared builder. Body and display text render in **Plus Jakarta Sans** (via `google_fonts`); a `monoData()` helper renders the monospaced geo-data signature (coordinates, trip IDs) in **JetBrains Mono**.
*   **Theme mode** (`core/theme/themeModeController.dart`): a persisted `themeModeProvider` — light is the default; dark is fully built and switchable at runtime from the Profile tab, with no screen changes.
*   **Identity & input hygiene** (`core/util/`): `name_monogram.dart` derives every avatar's initials (first+last, or an email fallback), and `text_input_rules.dart` exposes `inputRules()` — every editable `TextField` across auth, trip creation/join/search, and elsewhere wires it in via `inputFormatters: inputRules()` to strip emoji before it reaches a request body.

**Contributor rule:** never hardcode a colour in a screen or widget. Use `Theme.of(context).colorScheme`, `context.semantic.*`, `Theme.of(context).textTheme` / `monoData(context)`, and the `AppSpace` / `AppRadius` tokens. Add a new token first if a value is missing. Every editable `TextField` must set `inputFormatters: inputRules()`.

> **Backend note:** users now have a first and last name (`CurrentUser.firstName` / `.lastName`, backend companion change), consumed by the signup form and the Profile/avatar monogram.

---

## 🚀 Installation & Developer Setup

### Prerequisites
*   **Flutter SDK**: Installed and configured (recommend channel stable).
*   **Target Devices**:
    *   **Android**: Android Studio emulator or physical device.
    *   **iOS**: Xcode simulator (requires macOS) or physical device.

---

### 1. Fetch Dependencies
Navigate to the mobile directory and fetch packages:
```bash
flutter pub get
```

---

### 2. Code Generation (Drift Database Client)
This project uses **Drift** for local SQLite schema structures, which relies on code generation. Whenever you clone the project or modify schema entities inside [localDatabase.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/storage/localDatabase.dart), you **MUST** run the code generator:

```bash
dart run build_runner build --delete-conflicting-outputs
```
This command generates the missing [localDatabase.g.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/storage/localDatabase.g.dart) file which holds generated query classes and model converters.

---

### 3. Server Configuration & Local Network Settings
By default, the client points to `http://192.168.1.7:3000` inside the central URL configuration file:
*   [apiUrl.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/network/apiUrl.dart): contains `baseUrl` for HTTP requests and `wsBaseUrl` for WebSocket connections.

To test on emulators/devices, adjust these addresses:
*   **Android Emulator**: Change `localhost` to `10.0.2.2` (Android’s gateway loopback address to the host server).
*   **iOS Simulator**: `localhost` works out of the box.
*   **Physical Device**: Use your workstation's local network IP (e.g. `http://192.168.1.50:3000`).

---

### 4. Running the App
Start a emulator/simulator or plug in a device, and launch the build:
```bash
flutter run
```

---

## 🛰️ Real-time Tracking & State Architecture

```text
                   [ Geolocator GPS Stream ]
                               │
                               ▼
              [ locationTrackingService.dart ]
              /                              \
             /                                \
            ▼                                  ▼
[ localDatabase.dart ]              [ trackingSocketService.dart ]
   (Drift SQLite)                          (WebSocket Channel)
            │                                  │
            ▼                                  ▼
    [ syncService.dart ]               [ Live Room Broadcasts ]
    (Upload offline batches                    (From other members)
     over POST /paths/batch)                   │
            │                                  ▼
            │                     [ liveTrackingProviders.dart ]
            │                                  │
            ▼                                  ▼
            └──────────► [ mapStateProvider.dart ]
                               │
                               ▼
                     [ tripMapScreen.dart ]
                      (Repaints OSM View)
```