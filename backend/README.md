# Wayfarer Sync – Backend Service

Wayfarer Sync is a real-time, offline-first backend service built to power a mobile-only (Flutter) collaborative trip itinerary mapping application. The service facilitates secure user authentication, trip configuration, static map markers (destinations), real-time location sharing via WebSockets, and batch coordinate ingestion for offline synchronization.

---

## 🚀 Tech Stack

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Runtime** | **Bun** | Ultra-fast JS/TS runtime, package manager, and bundler |
| **Server Framework** | **Express** | Lightweight HTTP server router |
| **Database ORM** | **Prisma** (v7.6+) | Type-safe schema builder using schema directory configurations |
| **Databases** | **PostgreSQL & Valkey** | Relational data persistence & Redis-compatible queue/cache |
| **Real-time** | **ws** (WebSocket) | High-performance client-server event loop |
| **Schema Validation** | **Zod** (v4) | Single source of truth for runtime validation and type inference |
| **API Documentation**| **Swagger UI** | Interactive API documentation generated from Zod schemas |

---

## 🛠️ Project Structure

```text
backend/
├── docker-compose.yml       # PostgreSQL and Valkey container definitions
├── package.json             # Scripts and node package dependencies
├── prisma.config.ts         # Prisma 6+ multi-schema project configurations
├── tsconfig.json            # TypeScript compiler rules and path mappings
├── prisma/                  # Modular DB schema directory
│   ├── schema.prisma        # Main prisma configuration and client generator
│   ├── user.prisma          # User profile model
│   ├── trip.prisma          # Trip itinerary metadata model
│   ├── teamMember.prisma    # Trip membership join table (with map colors)
│   ├── destination.prisma   # Static itinerary destination pins
│   └── pathPoint.prisma     # GPS coordinates (breadcrumbs) trail model
├── schema/                  # Zod validation schemas
│   ├── index.ts             # Main schema exporter
│   ├── base.ts              # ID & Timestamps base properties schema
│   ├── auth.ts              # Sign Up & Log In input schemas
│   ├── user.ts              # Outgoing User schema
│   ├── trip.ts              # Trip representation schema
│   ├── destination.ts       # Waypoint coordinate schema
│   ├── pathPoint.ts         # GPS breadcrumbs and batch ingestion schemas
│   └── api.response.ts      # Standardized API success/error wrappers
└── src/                     # Source Code
    ├── index.ts             # Application entry point
    ├── prisma.ts            # Prisma Client singleton initialization
    ├── websocket.ts         # WebSocket upgrade handshake & message handler
    ├── controllers/         # Express Request/Response logic controllers
    ├── middleware/          # JWT Auth and schema validation middleware
    ├── openapi/             # OpenAPI specification structures and helpers
    ├── routes/              # Express API endpoint definitions
    ├── services/            # Database query and core logic layer
    └── utils/               # Common helper functions (colors, JSON wrappers)
```

---

## ⚙️ Installation & Setup

### Prerequisites
- **Bun** (v1.3.6 or newer)
- **Docker & Docker Compose**

### 1. Setup Environment Configuration
Create a `.env` file in the root backend directory:
```env
DATABASE_URL="postgresql://wayfarer:wayfarer123@localhost:5433/wayfarer"
JWT_SECRET="your_secure_jwt_secret_key"
JWT_REFRESH_SECRET="a_secret_of_at_least_32_characters"
REDIS_HOST="localhost"
REDIS_PORT="6379"
PORT=3000
```
Validated at boot (`src/config/env.ts`) — the process exits immediately if a variable is missing or invalid. `JWT_REFRESH_SECRET` must be at least 32 characters **and different from `JWT_SECRET`**; the server refuses to boot if they're equal, since identical secrets collapse the access/refresh token separation. `JWT_SECRET` itself has no length requirement — it's the pre-existing production secret, and rotating it would log out every user, so it is deliberately not tightened. See [Authentication & Tokens](#-authentication--tokens).

### 2. Start the Databases
Spin up the PostgreSQL and Valkey docker containers:
```bash
bun run start
```

### 3. Install Dependencies
```bash
bun install
```

### 4. Build and Push Database Schemas
Generate the type-safe Prisma client and push the schema directly to the database:
```bash
bun run setup
```

### 5. Launch the Development Server
```bash
bun run dev
```
The server will start on `http://localhost:3000`. You can access interactive Swagger documentation at `http://localhost:3000/docs`.

---

## 🗄️ Prisma 6/7 Modular Schemas

This project leverages Prisma's native **schema directory support** (introduced in Prisma 5.15+ and stabilized in 6+). 

In `prisma.config.ts`, the schema target is set as a directory:
```typescript
export default defineConfig({
  schema: "prisma/",
  // ...
});
```

All schema definitions under the `prisma/` folder (such as `user.prisma`, `trip.prisma`, and `pathPoint.prisma`) are parsed together automatically. You do **not** need a merge step or third-party compiler. Simply run `bun run setup` (or `prisma db push`) to build and apply the combined schema model.

---

## 📖 API Endpoint Catalog

### Authentication
*   **`POST /api/auth/signup`**
    *   *Payload*: `{ "email": "user@example.com", "password": "securepassword", "firstName": "Jane", "lastName": "Doe" }`
    *   `firstName`/`lastName` are required, 1–50 characters after trimming, and must not contain emoji — an invalid name returns `400`.
    *   *Response*: User profile (including `firstName`/`lastName`) along with authorization JWT token.
*   **`POST /api/auth/login`**
    *   *Payload*: `{ "email": "user@example.com", "password": "securepassword" }`
    *   *Response*: Authorization JWT token.
*   **`POST /api/auth/refresh`**
    *   *Payload*: `{ "refreshToken": "<jwt>" }`
    *   *Response* (`200`): `{ "accessToken": "<jwt>", "refreshToken": "<jwt>", "token": "<jwt>", "success": true }` — issues a fresh token pair (refresh rotates too).
    *   *Response* (`401`): `{ "error": "Invalid or expired refresh token", "code": "INVALID_REFRESH", "success": false }`. See [the `INVALID_REFRESH` contract](#the-invalid_refresh-contract) below.
    *   Rate-limited at 20/15min per IP (`refreshLimiter`), not the auth limiter.
*   **`POST /api/auth/exchange`** [Auth Required]
    *   One-shot upgrade for a client holding only a legacy `token`/access token and no refresh token (an in-place update from before this feature). Same response shape as `/refresh`.
*   **`POST /api/auth/ws-ticket`** [Auth Required]
    *   *Payload*: `{ "tripId": "<uuid>" }`
    *   *Response*: `{ "ticket": "<jwt>", "success": true }` — a 30-second, single-trip WebSocket credential. See [WebSocket Protocol](#-websocket-protocol).
    *   Rate-limited at 60/15min per IP (`ticketLimiter`), not the auth limiter.
*   **`POST /api/auth/logout`**
    *   *Response*: `{ "success": true }`. Stateless — there is nothing server-side to revoke; the client clears its own tokens.

All auth responses (`signup`, `login`, `me`) return a `user` object that includes `firstName` and `lastName`. These are nullable for legacy accounts created before this field existed.

`signup` and `login` responses also carry `accessToken` (15 min), `refreshToken` (30 days), and `token` — a 7-day legacy alias of the access token kept **only** so the deployed v1.0.4+5 app, which reads `response['token']` with a non-nullable cast, keeps working. Auth response bodies are flat and must **never** gain a top-level `data` key: the mobile `ApiClient` returns `body['data']` when present and the whole body otherwise, so a stray `data` key would silently break every auth parse site.

### Trips
`GET/PUT/DELETE /trip/:id`, `POST /trip/:id/end`, `GET /trip/:id/members`, and both `/trip/:id/paths` routes are gated by `requireTripMembership`, which returns **`404`, never `403`**, for a caller who isn't a member — a `403` would confirm the trip exists and permit UUID enumeration, so "doesn't exist" and "not yours" are deliberately indistinguishable. The check looks at `deletedAt` only, not `endedAt`, so an ended-but-not-deleted trip stays readable by its members. `POST /trip/:id/join` is **not** gated by this middleware (a non-member is exactly who is allowed to call it).

*   **`GET /api/trip`** [Auth Required]
    *   *Response*: Returns only the **caller's** trips (trips they are a member of, non-deleted), most-recent first (max 100). Each trip includes its `destinations`, `members` (with `user`), and `_count.members`.
*   **`POST /api/trip`** [Auth Required]
    *   *Payload*: `{ "title": "Summer Adventure", "startedAt": "2026-06-07T00:00:00Z", "destinations": [] }`
    *   *Response*: The created trip object including its assigned members.
*   **`GET /api/trip/:id`** [Auth Required]
    *   *Response*: Specific trip configuration by UUID.
*   **`PUT /api/trip/:id`** [Auth Required]
    *   *Payload*: `{ "title": "Updated Trip Title" }`
    *   *Response*: The updated trip.
*   **`DELETE /api/trip/:id`** [Auth Required]
    *   *Response*: Marks the trip as ended and soft-deletes it.
*   **`POST /api/trip/:id/join`** [Auth Required]
    *   Joins the current user to the trip and allocates a map trail color. Idempotent: joining a trip you already belong to returns your existing membership.
    *   `:id` must be a valid UUID (else `400`); the trip must exist and be active/non-deleted (else `404`).
    *   *Response*: `{ "success": true, "data": { "member": { … }, "alreadyMember": false } }` — `alreadyMember` is `true` when the user was already a member (clients use it to open the trip map instead of re-joining).
*   **`POST /api/trip/:id/end`** [Auth Required]
    *   Marks the trip as ended (`endedAt` set; `deletedAt` untouched) so it stays visible as "Ended". Live tracking stops and it can no longer be joined.
    *   `:id` must be a valid UUID (else `400`); the caller must be a member of an existing, non-deleted trip (else `404`).
    *   *Response*: `{ "success": true, "data": { …updated trip with destinations, members, _count… } }`
*   **`GET /api/trip/:id/members`** [Auth Required]
    *   *Response*: Returns membership detail arrays and user descriptors.

### Breadcrumbs & Trailing (Offline Sync)
*   **`POST /api/trip/:id/paths/batch`** [Auth Required]
    *   *Payload*: `{ "points": [ { "latitude": 37.77, "longitude": -122.41, "timestamp": "2026-06-07T15:00:00.000Z", "accuracy": 5.2 } ] }`
    *   Each point carries only coordinate fields (validated by `pathPointInputSchema`, 1–200 points). `tripId` (route param), `userId` (JWT), and the point `id` (database default) are assigned server-side — clients must **not** send them.
    *   *Response*: `{ "success": true, "data": { "count": 1 } }`
*   **`GET /api/trip/:id/paths`** [Auth Required]
    *   *Query Parameters*:
        *   `userId` (Optional): Filter track points by user.
        *   `since` (Optional): ISO timestamp to fetch incremental points.
    *   *Response*: Array of historical coordinates.

---

## 📊 Core Architecture & Data Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client (Flutter)
    participant Server as Express Server (HTTP)
    participant WS as WebSocket Server
    participant DB as PostgreSQL (Prisma)

    Note over Client,Server: Authentication & Trip Setup
    Client->>Server: POST /api/auth/signup (email, password, firstName, lastName)
    Server->>DB: Create User record (hashed password)
    DB-->>Server: Saved User
    Server-->>Client: JWT Token & User Profile

    Client->>Server: POST /api/trip (title, destinations) [Auth Bearer]
    Server->>DB: Save Trip and static Destination pins
    DB-->>Server: Saved Trip
    Server-->>Client: Created Trip Details

    Note over Client,WS: Real-time GPS Tracking
    Client->>Server: HTTP UPGRADE GET /?token=JWT&tripId=TRIP_ID
    Server->>DB: Verify JWT & check Trip membership
    DB-->>Server: Verification OK
    Server->>WS: Upgrade Connection to WebSocket protocol
    WS-->>Client: Connection Established

    par Real-time Location Broadcasting
        Client->>WS: Location Frame ("location_update", latitude, longitude)
        WS-->>WS: Broadcast to other active members in tripId room
        WS->>DB: Ingest breadcrumb via pathService.ingestPathBatch() (async)
    end
```

---

## 📡 WebSocket Protocol

The real-time connection requires authentication during upgrade. Connection parameters must be passed in the connection URL query string, in one of two forms:

*   **Ticketed (current)**: `ws://localhost:3000/?ticket=YOUR_WS_TICKET&tripId=YOUR_TRIP_ID` — the ticket comes from `POST /api/auth/ws-ticket` and is bound to that one `tripId`.
*   **Legacy (still supported)**: `ws://localhost:3000/?token=YOUR_JWT_TOKEN&tripId=YOUR_TRIP_ID` — a plain access token, exactly as v1.0.4+5 sends it.

A ticketed connection is armed with a **15-minute re-auth deadline**. To stay connected past it, the client must send an `auth_refresh` message with a fresh ticket before the deadline; the server replies `auth_ok` and rearms the deadline. A background sweep runs every 60 seconds and closes any socket that missed its deadline with close code **`4001`** (reason `"auth expired"`). A legacy `?token=` connection is **never** given a deadline and is therefore never swept — closing it only happens the normal way (client disconnects, error, etc.).

#### `auth_refresh` (Client → Server)
```json
{
  "type": "auth_refresh",
  "payload": { "ticket": "YOUR_FRESH_WS_TICKET" }
}
```
On success the server replies `{"type":"auth_ok","payload":{}}` and extends the deadline by another 15 minutes. On failure (bad/expired ticket, ticket for a different user, or the caller is no longer a trip member) the server closes the socket with code `4001`.

### Outgoing Messages (Client → Server)
For real-time location streaming, clients should send stringified JSON frames:

#### `location_update`
```json
{
  "type": "location_update",
  "payload": {
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2026-05-23T22:15:00.000Z",
    "accuracy": 5.2
  }
}
```

### Incoming Messages (Server → Client)
Broadcast events sent from the server to room members:

#### `member_location`
```json
{
  "type": "member_location",
  "payload": {
    "userId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "timestamp": "2026-05-23T22:15:00.000Z",
    "accuracy": 5.2
  }
}
```

---

## 🔑 Authentication & Tokens

Four token kinds are in play, all HS256, with the algorithm explicitly pinned on both sign and verify (no reliance on library defaults):

| Token | TTL | Signed with | Claims |
| :--- | :--- | :--- | :--- |
| `accessToken` | 15 min | `JWT_SECRET` | `{ userId, type: 'access' }` |
| `refreshToken` | 30 days, sliding | `JWT_REFRESH_SECRET` | `{ userId, type: 'refresh' }` |
| `token` (legacy alias) | 7 days | `JWT_SECRET` | `{ userId, type: 'access' }` |
| WS ticket | 30 sec | `JWT_SECRET` | `{ userId, tripId, type: 'ws' }` |

The `type` claim exists because WS tickets are signed with the **same secret** as access tokens — a ticket presented as a Bearer token decodes cleanly and is rejected *only* by the `type` check. (Refresh tokens use a different secret, so they'd fail signature verification regardless.) `verifyAccessToken` also accepts **untyped** tokens — those issued before this release, which predate the `type` claim entirely. That shim is scheduled for removal 7 days after deploy, once every pre-deploy token has naturally expired.

### The `INVALID_REFRESH` contract

> **`POST /api/auth/refresh` returning HTTP `401` with body `code: "INVALID_REFRESH"` is the *only* signal that makes the mobile client clear its tokens and show the login screen.** Every other outcome — a `500`, a `404`, a bare `401` without that code, a network error, or an HTML gateway page — leaves the user logged in and is treated as transient. Do not add another way to trigger a client-side logout, and never return this exact `(401, INVALID_REFRESH)` pair for anything other than "this refresh token is genuinely invalid or expired." Changing it is a breaking change to the mobile app's session model.

### Rate limits

| Limiter | Limit | Applies to |
| :--- | :--- | :--- |
| `globalLimiter` | 1000 / 15 min | Every route |
| `authLimiter` | 10 / 15 min | `/signup`, `/login` |
| `apiLimiter` | 60 / 1 min | General API routes (trips, paths) |
| `refreshLimiter` | 20 / 15 min | `/refresh` |
| `ticketLimiter` | 60 / 15 min | `/ws-ticket` |

`authLimiter` deliberately does **not** cover `/refresh` or `/ws-ticket` — normal operation refreshes roughly every 15 minutes and re-tickets roughly every 10 minutes per active trip, which would exhaust a 10/15min budget and 429 forever, breaking live tracking. The app also runs behind exactly one reverse-proxy hop (`app.set("trust proxy", 1)`); changing the proxy topology without updating this would make every client share one IP-keyed bucket, or let a spoofed `X-Forwarded-For` bypass rate limiting.

---

## 🛠️ Available Scripts

- `bun run start`: Boot up database containers (PostgreSQL, Valkey) in the background.
- `bun run reset`: Shut down database containers.
- `bun run setup`: Generate Prisma Client types and push migrations/schemas.
- `bun run dev`: Run server in development watch mode.
- `bun run build`: Bundle the TypeScript application to `/dist` for production deployment.
- `bun run test`: Run the test suite using Bun's native test runner.
