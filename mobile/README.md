# Wayfarer Sync – Mobile Application (Flutter)

Wayfarer Sync is an offline-first, collaborative trip itinerary and real-time location mapping application built with Flutter. This mobile client relies on a local reactive SQLite database cache layer to support continuous GPS tracking in areas with compromised network coverage, automatically synchronizing data trails back to the backend once a stable internet connection is established.

---

## 🏗 Key Features & System Design

*   **Offline-First GPS Logging:** Collects background hardware coordinate streams via the `geolocator` subsystem, burning points directly into an offline SQLite engine before initiating network operations.
*   **Dual-Path Synchronization:** Dispatches live movement frames over raw persistent WebSockets when network availability is stable, while gracefully queuing points locally to be sent in an optimized HTTP batch fallback array if connection drops.
*   **Reactive UI Repainting:** Utilizes standard OpenStreetMap tile layers via `flutter_map`, repainting a **per-member colored polyline trail** (each traveler's own ordered path) and live position markers reactively using unified Riverpod state providers.
*   **Interactive Destination Pinning:** Support for searching and reverse geocoding locations via OpenStreetMap's Nominatim API, allowing users to map and pin a static destination to share when starting a trip.
*   **Traveler Centering & Tracking:** Renders a horizontal scrollable row of active members on the live map overlay. Travelers can tap any member chip to center the map on their last reported location coordinates.
*   **Trip Sharing & Joining:** After creating a trip, a confirmation dialog lets the owner copy the trip ID or send it through the native OS share sheet (`share_plus`); any trip in the dashboard is shareable via a per-card action. Others join by pasting the shared trip ID into the Join dialog.
*   **Adaptive Theming (Light + Dark):** A centralized, token-driven design system exposes light and dark themes (light by default, switchable at runtime and persisted). No visual value is hardcoded in screens — all colours resolve through the theme and a semantic-colour extension.

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
│   └── widgets/       # Reusable themed widgets (primary button, glass panel, ticket card, skeleton…)
└── features/
    ├── auth/          # Login & signup screens with persisted JWT session
    ├── trip/          # Trip list, creation (map pin + Nominatim search), and share service
    └── tracking/      # Interactive Map screens, live GPS trackers, sync, and data repositories
```

---

## 🎨 Design System & Theming

The UI is driven entirely by a centralized theme so appearance can change in future releases without editing screens.

*   **Tokens** (`core/theme/appTokens.dart`): the single source of literal colours (light + dark palettes) and the spacing/radius scale. Nothing else in the app declares raw hex or magic spacing.
*   **Semantic colours** (`core/theme/appSemanticColors.dart`): a `ThemeExtension` for brand/semantic colours (route accent, glass surfaces, online signal, map-marker colours). Widgets read them via `context.semantic.<name>` so every value adapts between light and dark automatically.
*   **Themes** (`core/theme/appTheme.dart`): `buildLightTheme()` / `buildDarkTheme()` produced from one shared builder, plus a `monoData()` helper for the monospaced geo-data signature (coordinates, trip IDs).
*   **Theme mode** (`core/theme/themeModeController.dart`): a persisted `themeModeProvider` — light is the default; dark is fully built and switchable at runtime with no screen changes.

**Contributor rule:** never hardcode a colour in a screen or widget. Use `Theme.of(context).colorScheme`, `context.semantic.*`, `Theme.of(context).textTheme` / `monoData(context)`, and the `AppSpace` / `AppRadius` tokens. Add a new token first if a value is missing.

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