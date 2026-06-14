# Trip Destination Search and Peer Tracking Design Spec

## 1. Overview
This specification details the design for adding destination search/selection and peer tracking functionality to the Wayfarer Sync mobile application. 

The goals are:
*   Allow users to search and select a specific destination when starting/creating a trip.
*   Display the trip's destination pin on the live map view.
*   Display other active trip members as a horizontal list of scrollable user chips.
*   Allow centering the map view on any selected trip member.

---

## 2. System Architecture & Component Design

```mermaid
graph TD
    subgraph Mobile Client (Flutter)
        CreateTripScreen[CreateTripScreen] -->|Nominatim HTTP| OSM_Search[OSM Nominatim API]
        CreateTripScreen -->|POST /api/trip| Express_API[Express HTTP Router]
        TripMapScreen[TripMapScreen] -->|GET /api/trip/:id| Express_API
        TripMapScreen -->|WebSocket location_update| WS_Server[WebSocket Server]
        WS_Server -->|WebSocket member_location| TripMapScreen
    end
    subgraph Backend Service
        Express_API --> Prisma[Prisma ORM]
        Prisma --> PostgreSQL[(PostgreSQL)]
    end
```

### 2.1 Backend Changes
We will update `getTripById` in the backend service to return a trip's `destinations` and `members`. This enables the map screen to fetch the target destinations and group members in a single API request on load.

*   **Files Modified**:
    *   [backend/src/services/trip.service.ts](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend/src/services/trip.service.ts)
*   **Signature Update**:
    ```typescript
    export const getTripById = (id: string) => {
      return prisma.trip.findUnique({
        where: { id, deletedAt: null },
        include: {
          destinations: true,
          members: {
            include: {
              user: {
                select: { id: true, email: true }
              }
            }
          }
        }
      });
    };
    ```

### 2.2 Mobile Client Changes

#### A. Navigation & Screen Routing
*   Register a new route `/create-trip` in [router.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/network/router.dart).
*   Modify `TripsScreen` to navigate to `/create-trip` instead of showing a simple dialog.

#### B. CreateTripScreen
*   **Search Engine**: Hits the OpenStreetMap Nominatim Search API:
    `GET https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=5`
    with headers `User-Agent: com.wayfarersync.mobile`.
*   **Interactive Mini-map**: Displays a `flutter_map` viewport.
    *   Tapping a search suggestion pins it on the map and updates the latitude/longitude coordinates.
    *   Tapping anywhere on the mini-map updates the pinned coordinate location.
*   **Creation form**: A text field for the trip title, and a "Start Trip" button which calls `POST /api/trip` and passes:
    ```json
    {
      "title": "Trip Title",
      "startedAt": "2026-06-14T22:54:15.000Z",
      "destinations": [
        {
          "name": "Selected Location Name",
          "latitude": 12.34,
          "longitude": 56.78,
          "order": 0
        }
      ]
    }
    ```

#### C. TripMapScreen Enhancements
*   **On Load Data Ingestion**:
    *   Fetches the trip details using the `GET /api/trip/:id` endpoint.
    *   Extracts static `destinations` and the list of active `members`.
*   **Static Destination Pins**:
    *   Renders green flag/marker pins on the map for all trip destinations.
*   **Active Peer Tracking List**:
    *   Renders a horizontal scrolling row of action chips at the top of the map layer.
    *   Each chip represents a member (showing their email prefix, e.g. `alex` instead of `alex@example.com`).
    *   Each chip is styled using that member's allocated color.
    *   Tapping a member's chip retrieves their last known coordinates from the map state provider. If available, the map controller centers on their position (`_mapController.move(position, 15.0)`). If not available, a toast notification alerts the user: `No location updates from [member] yet`.

---

## 3. Data Flows

### 3.1 Trip Creation Flow
```
[User Type in Search] ──> [Nominatim API Request] ──> [Select Suggestion]
                                                               │
                                                               ▼
[POST /api/trip] <── [Click "Start Trip"] <── [Pin Placed on Mini Map]
```

### 3.2 Peer Centering Flow
```
[User Taps Peer Chip] ──> [Look up Peer ID in mapStateProvider]
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼ (Location Found)                        ▼ (No Location)
     [Center Map on Coordinates]               [Show Toast Notification]
```

---

## 4. Testing & Validation Plan
*   **Backend Integration**: Execute `bun test` to ensure existing database/websocket assertions remain green.
*   **Mock Nominatim Search**: Verify search requests are correctly structured, throttled/debounced, and parse list responses.
*   **Manual Emulator Spoofing**: Simulating movement on two emulators concurrently to verify location updates stream between rooms and that peer tracking buttons center correctly.
