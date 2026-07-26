# 🧪 Testing and Quality Assurance Guide: Wayfarer Sync

Welcome to the Wayfarer Sync QA Guide. This document explains how to run the automated test suites and how to conduct manual, real-world simulations (network dropouts, GPS location spoofing, and boundary security testing) across both the mobile and backend applications.

---

## 🤖 1. Automated Testing

### Backend Test Suite
The backend uses **Bun Test** for unit testing and WebSocket connection simulation.
1. Navigate to the `backend` workspace root:
   ```bash
   cd backend
   ```
2. Run the test suite:
   ```bash
   bun test
   ```
   *This runs WebSocket connection security, soft-deletion verification, coordinate/batch-input Zod validation (`pathBatch.test.ts`), and schema validation tests using in-memory mocks. It also covers the refresh-token contract (`authEndpoints.test.ts`, `token.service.test.ts`, `env.test.ts`), trip-membership 404 behavior (`tripMembership.test.ts`, `tripAccess.test.ts`), and old-client compatibility (`contract.v1.0.4.test.ts`).*
   *Current baseline: **90 pass / 3 fail**. The 3 failures are `websocket.test.ts` handshake timeouts — that suite requires a live Postgres on `:5433` (via `docker-compose up -d`) and fails without it.*

### Mobile Test Suite
The Flutter mobile client uses standard unit/widget tests to verify authentication token persistence, local SQLite Drift database operations, per-user live-trail map state (`map_state_provider_test.dart`), and the trip-share text builder (`trip_share_test.dart`).
1. Navigate to the `mobile` workspace root:
   ```bash
   cd mobile
   ```
2. Run the tests:
   ```bash
   flutter test
   ```
   *Current baseline: **56 pass / 1 fail**. The 1 failure is a pre-existing, unrelated failure in `motion_test.dart` — not caused by the refresh-token work.*
3. Run static code analysis:
   ```bash
   flutter analyze
   ```

---

## 📱 2. Manual & Real-World QA Scenarios

### Step 0: Local Environment Configuration
1. **Start Backend Infrastructure:**
   ```bash
   cd backend
   docker-compose up -d
   bun run setup
   bun run dev
   ```
   *Verify access to the Swagger API docs at `http://localhost:3000/docs`.*
2. **Launch Mobile App:**
   Boot up your emulator and run:
   ```bash
   cd mobile
   flutter run
   ```
   * **Android Emulator:** Resolves API calls to the host system via the bridge address `http://10.0.2.2:3000`.
   * **iOS Simulator:** Resolves API calls to the host system via `http://localhost:3000`.

---

### Scenario A: Happy Path (Real-Time GPS Tracking)
*Goal: Verify real-time GPS tracking and peer broadcasts.*

1. Open the mobile application and **Sign Up** for a new account.
2. On the **My Trips** dashboard, tap the `+` icon, create a new trip (e.g., `"Alpine Trail"`), and tap the trip card to open the **Live Map**.
3. Verify on your backend console that the connection upgraded successfully to a WebSocket:
   `GET /?token=JWT&tripId=TRIP_ID` upgraded.
4. Use emulator GPS spoofing (see the *Location Spoofing Tools* section below) to mock walking movement.
5. **Expected Results:**
   * A colored polyline trail plots live on your mobile map interface.
   * Querying the backend Postgres database confirms coordinate breadcrumbs are ingested live:
     ```sql
     SELECT * FROM "PathPoint" ORDER BY "timestamp" DESC LIMIT 5;
     ```

---

### Scenario B: Offline Resilience & Auto-Sync (Tunnel Simulation)
*Goal: Verify client Drift SQLite caching and automatic sync restoration when network drops and reconnects.*

1. Navigate to the **Live Map** screen.
2. **Simulate Network Loss:** Toggle the emulator's network status off:
   * **Android:** Disable Wi-Fi and Cellular data in the emulator settings.
   * **iOS:** Turn off your host computer's Wi-Fi.
3. Verify on the backend terminal console that the user is reported disconnected:
   `WebSocket connection closed/disconnected for user UUID.`
4. **Spoof Movement (While Offline):** Feed new location coordinates to the emulator.
5. **Verify Local Cache:** 
   * The path trail continues to render locally on the mobile map.
   * The coordinates are saved in the client's local SQLite database with the status flag `isSynced = false`.
6. **Simulate Connection Recovery:** Toggle the emulator's Wi-Fi/cellular network back on.
7. **Expected Results:**
   * The connectivity observer detects the restoration and triggers a sync:
     `Sync successful: N points updated.`
   * Verify the database now shows these points uploaded to the PostgreSQL backend, and updated to `isSynced = true` on the client.

---

### Scenario C: Security & Payload Boundary Hardening
*Goal: Ensure the backend blocks unauthorized handshakes, soft-deleted trips, and out-of-bounds inputs.*

#### Test Case 1: Connection to Soft-Deleted Trips
1. Create a trip and note its UUID.
2. Mark the trip as soft-deleted in the Postgres database:
   ```sql
   UPDATE "Trip" SET "deletedAt" = NOW() WHERE "id" = 'YOUR-TRIP-UUID';
   ```
3. Attempt to upgrade to a WebSocket connection using `wscat`:
   ```bash
   wscat -c "ws://localhost:3000/?token=VALID_JWT&tripId=YOUR-TRIP-UUID"
   ```
4. **Expected Result:** Connection is rejected with `HTTP/1.1 403 Forbidden`.

#### Test Case 2: Handshake without Credentials
1. Try connecting via raw WebSocket without providing token or tripId parameters.
2. **Expected Result:** Connection is rejected with `HTTP/1.1 401 Unauthorized`.

#### Test Case 3: Coordinate Range Validation (Zod boundary checking)
1. Open a WebSocket connection.
2. Intentionally transmit a payload containing out-of-bounds latitude (e.g. `120.5`):
   ```json
   {
     "type": "location_update",
     "payload": {
       "latitude": 120.5,
       "longitude": -122.4194,
       "timestamp": "2026-06-09T12:00:00.000Z",
       "accuracy": 4.5
     }
   }
   ```
3. **Expected Result:**
   * The backend's Zod schema rejects the validation bounds.
   * The socket returns an error frame:
     `{"type":"error","payload":{"message":"Malformed payload frame structure"}}`
   * Confirm that no out-of-bound point is saved to Postgres.

---

### Scenario D: Token expiry never logs you out
*Goal: Confirm access-token expiry alone never triggers a logout.*

1. Log in, open a trip map, then leave the app backgrounded for 20 minutes (past the 15-minute access-token TTL).
2. Bring the app back to the foreground.
3. **Expected Results:**
   * The app resumes straight into the map — no login prompt.
   * Nothing user-visible indicates a refresh happened (the app-resume refresh trigger in `RefreshCoordinator` is silent).

---

### Scenario E: Refresh while offline (the acceptance test)
*Goal: Verify GPS keeps recording and the user stays logged in when the access token expires with no network at all.*

1. Log in and open the map. Disable networking (Wi-Fi and cellular).
2. Wait past the 15-minute access-token expiry, using GPS spoofing to keep the trail moving.
3. **Expected Results:**
   * The app stays logged in and GPS keeps recording to the local Drift database.
   * The UI shows "You're offline. Your trip is still being recorded and will sync automatically." — never a sign-out.
4. Re-enable networking.
5. **Expected Result:** tokens refresh (the connectivity-restored trigger fires) and the queued points sync via `POST /trip/:id/paths/batch`.

---

### Scenario F: WebSocket re-auth
*Goal: Verify the ticketed WebSocket's 15-minute re-auth deadline and 60-second sweep behave as designed.*

1. Open a trip map and leave it connected for 25 minutes.
2. **Expected Result:** live tracking keeps working across at least two re-auth cycles (the client sends `auth_refresh` with a fresh ticket every 10 minutes; each `auth_ok` reply extends the server's 15-minute deadline).
3. In the database, delete the user's `TripMember` row for that trip, then wait for one more re-auth cycle.
4. **Expected Result:** the server's membership re-check on `auth_refresh` fails, the socket closes with code `4001`, and live updates stop.

---

### Scenario G: Old-client compatibility gate
*Goal: Guard the v1.0.4+5 contract before every deploy — see `backend/README.md` for the token model this protects.*

1. Run the Task 16 checklist (`backend/src/tests/contract.v1.0.4.test.ts`, plus a manual pass against a v1.0.4+5 build) against the new backend.
2. **Expected Result:** `login`/`signup` responses still return a top-level `token` field, no auth response has gained a `data` key, and a legacy `?token=&tripId=` WebSocket connection still upgrades and streams normally.

---

## 🛠️ 3. Location Spoofing & Diagnostics Utilities

### GPS Spoofing on Simulators
*   **Android Emulator:** Click the **three dots** in the emulator sidebar -> **Location**. You can search for locations, play back GPX/KML routes, and set travel speeds.
*   **iOS Simulator:** Select **Features** in the menu bar -> **Location** -> Choose **City Run**, **City Bicycle Ride**, or input a **Custom Location**.

### Raw WebSocket Inspection with `wscat`
Install `wscat` via npm to send and listen to WebSocket payloads directly:
```bash
npm install -g wscat
wscat -c "ws://localhost:3000/?token=JWT_TOKEN&tripId=TRIP_UUID"
```

### Inspecting local Client SQLite files
You can drag the SQLite database out of the emulator environment to inspect the tables using **DB Browser for SQLite**:
*   **Android Device Path:** `/data/data/com.wayfarersync.mobile/app_flutter/wayfarer_sync.sqlite`
*   **iOS Device Path:** Print `getApplicationDocumentsDirectory()` in Flutter code to get the local sandboxed path.
