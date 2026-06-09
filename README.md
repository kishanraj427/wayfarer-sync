# 🌍 Wayfarer Sync

[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bun Version](https://img.shields.io/badge/Bun-%3E%3D1.3.6-black?logo=bun)](https://bun.sh)
[![Flutter Version](https://img.shields.io/badge/Flutter-Mobile-blue?logo=flutter)](https://flutter.dev)

Wayfarer Sync is a real-time, offline-first collaborative trip itinerary mapping platform. It combines a high-performance backend service with a collaborative mobile client (Flutter) to enable seamless trip planning, static route/destination marker creation, real-time location sharing, and robust offline synchronization for remote travel.

---

## 📂 Monorepo Architecture

This repository is organized as a monorepo containing both the backend service and the mobile application:

```text
wayfarer-sync/
├── backend/            # Bun + Express + PostgreSQL + Valkey backend service
│   ├── src/            # Express controllers, routes, and services
│   ├── prisma/         # Type-safe modular database schemas
│   └── schema/         # Shared Zod validation schemas
│
└── mobile/             # Collaborative Flutter mobile application (client)
    ├── lib/            # Dart source files (features, core providers, etc.)
    └── pubspec.yaml    # Flutter project packages and assets configuration
```

---

## 🛠️ Components & Technologies

### 1. [Backend Service](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend)
An ultra-fast real-time service powering API endpoints, WebSocket rooms, and database layers.

*   **Runtime**: [Bun](https://bun.sh) (v1.3.6+) for high-speed execution, bundling, and package management.
*   **API Layer**: Express server with [Zod](https://zod.dev) schemas for strict validation and interactive OpenAPI/Swagger documentation.
*   **Persistence**: PostgreSQL managed through [Prisma](https://prisma.io) v7+ (configured with split, modular schema files).
*   **Cache & Queue**: Valkey (Redis-compatible) for real-time pub/sub and high-throughput queues.
*   **Real-time Protocol**: WebSocket server (`ws`) handling live client location broadcasts.

### 2. [Mobile Application](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile)
A multi-platform client built using [Flutter](https://flutter.dev) tailored for mobile-only collaborative travel navigation.

*   **State Management**: Riverpod (`flutter_riverpod`) for reactive state and data streams.
*   **Local Store**: Drift (reactive SQLite layer) for offline-first GPS coordinate logging.
*   **Mapping**: `flutter_map` with OpenStreetMap tile layers.
*   **Networking**: Native HTTP Client + WebSocket channels.

---

## 🚀 Quick Start

### Prerequisites
*   **Bun** (v1.3.6 or newer)
*   **Docker & Docker Compose**
*   **Flutter SDK** (configured with Android/iOS tools)

---

### Running the Backend

For detailed setup instructions, see the [Backend README](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend/README.md).

1.  **Navigate to the backend directory**:
    ```bash
    cd backend
    ```

2.  **Configure environment variables**:
    Create a `.env` file matching [backend/.env](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend/.env):
    ```env
    DATABASE_URL="postgresql://wayfarer:wayfarer123@localhost:5433/wayfarer"
    JWT_SECRET="your_secure_jwt_secret_key"
    REDIS_HOST="localhost"
    REDIS_PORT="6379"
    PORT=3000
    ```

3.  **Start PostgreSQL and Valkey Docker containers**:
    ```bash
    bun run start
    ```

4.  **Install dependencies**:
    ```bash
    bun install
    ```

5.  **Initialize DB schema & generate Prisma Client**:
    ```bash
    bun run setup
    ```

6.  **Start the API & WebSocket server**:
    ```bash
    bun run dev
    ```
    The backend will run at `http://localhost:3000`. You can view the live interactive Swagger documentation at `http://localhost:3000/docs`.

---

### Running the Mobile Client

For detailed setup instructions, see the [Mobile README](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/README.md).

1.  **Navigate to the mobile directory**:
    ```bash
    cd mobile
    ```

2.  **Install Flutter dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Generate local DB schema**:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **Configure Server Endpoint connection**:
    *   If using an **Android Emulator**, verify that connections map to the default bridge address `10.0.2.2:3000`.
    *   If using an **iOS Simulator** or physical device on the same local network, use the server's local IP (e.g. `192.168.1.X:3000`).

5.  **Run the application**:
    ```bash
    flutter run
    ```
