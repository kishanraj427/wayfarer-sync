# Wayfarer Sync – Mobile Application (Flutter)

Wayfarer Sync is an offline-first, collaborative trip itinerary and real-time location mapping application built with Flutter. This mobile client relies on a local reactive SQLite database cache layer to support continuous GPS tracking in areas with compromised network cellular coverage, automatically synchronizing data trails back to the backend once a stable internet connection is established.

---

## 🏗 Key Features & System Design

* **Offline-First GPS Logging:** Collects background hardware coordinate streams via the `geolocator` subsystem, burning points directly into an offline SQLite engine before initiating network operations.
* **Dual-Path Synchronization:** Dispatches live movement frames over raw persistent WebSockets when network availability is stable, while gracefully queuing points locally to be sent in an optimized HTTP batch fallback array if connection drops.
* **Reactive UI Repainting:** Utilizes standard OpenStreetMap tile layers via `flutter_map`, repainting colored polyline tracks and live position markers reactively using unified Riverpod state providers.

---

## 🛠 Tech Stack Configuration

| Layer | Component Technology |
| :--- | :--- |
| **Framework UI** | Flutter (Material 3 Engine) |
| **State Management** | Flutter Riverpod + Riverpod Architecture Generators |
| **Local Cache Store** | Drift (Reactive SQLite Engine Wrapper) |
| **Mapping Engine** | Flutter Map (OpenStreetMap Tiles Layer) |
| **Hardware Core** | Geolocator Subsystem API |
| **Networking** | HTTP Client + Web Socket Channels |

---

## 📂 Directory Architecture

The application layout follows a strict **feature-first** design system to maintain separation of concerns:

```text
lib/
├── core/
│   ├── network/       # API Rest Client, HTTP token interceptors, and Socket loops
│   └── storage/       # Drift Database schema contracts & connection initializers
└── features/
    ├── auth/          # Authentication state management workflows
    ├── trip/          # Trip lifecycle, creation, and member directory layers
    └── tracking/      # Interactive Map screens, live GPS trackers, and data repositories