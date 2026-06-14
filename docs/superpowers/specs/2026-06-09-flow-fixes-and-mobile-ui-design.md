# System Design Specification: Wayfarer Sync Flow & UI Implementation

This document specifies the technical design for implementing the end-to-end mobile user experience, fixing existing backend/mobile sync gaps, and establishing strong validation and security rules.

---

## 1. System Architecture Overview

Wayfarer Sync combines a Flutter mobile client with a Bun/Express/PostgreSQL backend using persistent WebSockets for real-time tracking and HTTP batch updates for offline-first backup.

```text
┌─────────────────────────────────────────────────────────────────┐
│                       FLUTTER MOBILE CLIENT                     │
│                                                                 │
│  [ UI Screens ] ◄──► [ GoRouter ] ◄──► [ AuthTokenProvider ]   │
│         │                                      ▲                │
│         ▼                                      │                │
│  [ LocationTrackingService ]             (Restores Token)       │
│    /                  \                        │                │
│   ▼                    ▼                       │                │
│ [ Drift SQLite ]     [ WebSocket Channel ]     │                │
│   (Offline DB)          (Live Stream)          │                │
│        │                      ▲                │                │
└────────┼──────────────────────┼────────────────┼────────────────┘
         │ (HTTP Batch Upload)  │ (WS Broadcast) │ (Auth Requests)
         ▼                      ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                       EXPRESS BACKEND SERVER                    │
│                                                                 │
│       [ Express API ] ◄──► [ WS Server / Room Manager ]         │
│              │                      │                           │
│              ▼                      ▼                           │
│         [ Prisma Client ] ◄─────────┘                           │
│              │                                                  │
│              ▼                                                  │
│        [ PostgreSQL ]                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Design & Changes

### 2.1. Mobile Navigation & Authentication (GoRouter)
We will introduce `go_router` for route definition, enabling automatic redirection when the user's authentication state changes.

*   **Routes Matrix:**
    *   `/login`: Login UI with email and password fields. Redirects to `/trips` upon successful authentication.
    *   `/signup`: Signup UI with email and password fields. Redirects to `/trips` upon successful authentication.
    *   `/trips`: Displays the list of trips. Allows creating or joining a trip. Redirects to `/login` if authentication token is cleared.
    *   `/trip/:id/map`: Renders the OpenStreetMap layer, loads tracking providers, and starts continuous coordinate logging.
*   **Token Lifecycle:**
    *   On authentication success: Save JWT to `shared_preferences` under the key `jwt_token`, and push the string value to `authTokenProvider`.
    *   On startup: Check `shared_preferences`. If a token exists, load it to `authTokenProvider` immediately to bypass the login page.
    *   On token expiration or logout: Clear `jwt_token` in `shared_preferences`, and call `clearToken()` on `authTokenProvider` to trigger automatic redirection.

### 2.2. Mobile Offline Sync & Connection States
We will address the un-triggered sync problem by subscribing to network connectivity changes.

*   **Connectivity Provider:**
    *   Wrap `connectivity_plus` inside a provider.
    *   Listen to network changes globally. If transitioning from `ConnectivityResult.none` to `ConnectivityResult.wifi` or `ConnectivityResult.mobile`, execute `SyncService.synchronizeTripPaths(tripId)`.
*   **Sync Logic Flow (`SyncService.synchronizeTripPaths`):**
    *   Read unsynced path points for the current trip from the Drift database (`getUnsyncedPoints`).
    *   Perform batch upload POST `/api/trip/:id/paths/batch` through the HTTP client.
    *   On success, call `markPointsAsSynced(pointIds)` to set `isSynced = true` in SQLite.
*   **Manual Trigger:**
    *   The sync icon button on the `TripMapScreen` App Bar will invoke `synchronizeTripPaths` manually and show status notifications using a SnackBar.

### 2.3. Backend WebSocket Security & Location Checks
We will secure connection requests and validate incoming broadcast locations.

*   **Upgrade Membership Checks:**
    *   In the upgrade handshake logic, fetch the trip metadata along with membership checks. Reject the socket upgrade with `403 Forbidden` if `deletedAt` is not null or `endedAt` is not null.
*   **Coordinate Range Validation:**
    *   Before saving a coordinates update to the database or broadcasting it to the room, validate the inputs against a Zod validation schema:
        *   `latitude`: `z.number().min(-90).max(90)`
        *   `longitude`: `z.number().min(-180).max(180)`
        *   `timestamp`: `z.string().datetime()`
        *   `accuracy`: `z.number().nonnegative().nullish()`
    *   If validation fails, reply with an error message to the sender and ignore the point.

---

## 3. Testing Specification

### 3.1. Mobile Drift Database Tests
We will add `mobile/test/local_database_test.dart` to verify the local database operations using an in-memory SQLite engine:
*   Insert sample unsynced points and confirm they return from `getUnsyncedPoints`.
*   Mark coordinates as synced and verify they are filtered out in subsequent queries.

### 3.2. Backend Coordinate Validation Tests
We will add `backend/src/tests/websocket.test.ts` using Bun's test suite:
*   Verify that coordinates outside the `[-90, 90]` or `[-180, 180]` boundaries fail the validation schema.
*   Verify that valid coordinate structures pass.
