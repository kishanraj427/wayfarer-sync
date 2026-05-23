# Wayfarer Sync – Backend Service

Wayfarer Sync is a real-time, offline-first backend service built to power a mobile-only (Flutter) collaborative trip itinerary mapping application. The service facilitates secure user authentication, trip configuration, static map markers (destinations), real-time location sharing via WebSockets, and batch coordinate ingestion for offline synchronization.

---

## 🚀 Tech Stack

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Runtime** | **Bun** | Ultra-fast JS/TS runtime, package manager, and bundler |
| **Server Framework** | **Express** | Lightweight HTTP server router |
| **Database ORM** | **Prisma** (v7.6+) | Type-safe schema builder using split modular schema files |
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
Create a `.env` file in the root directory:
```env
DATABASE_URL="postgresql://wayfarer:wayfarer123@localhost:5433/wayfarer"
JWT_SECRET="your_secure_jwt_secret_key"
REDIS_HOST="localhost"
REDIS_PORT="6379"
PORT=3000
```

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

## 📊 Core Architecture & Data Flow

```mermaid
sequenceDiagram
    autonumber
    actor Client as Mobile Client (Flutter)
    participant Server as Express Server (HTTP)
    participant WS as WebSocket Server
    participant DB as PostgreSQL (Prisma)

    Note over Client,Server: Authentication & Trip Setup
    Client->>Server: POST /api/auth/signup (email, password)
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

The real-time connection requires authentication during upgrade. Connection parameters must be passed in the connection URL query string:
`ws://localhost:3000/?token=YOUR_JWT_TOKEN&tripId=YOUR_TRIP_ID`

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

## 🛠️ Available Scripts

- `bun run start`: Boot up database containers (PostgreSQL, Valkey) in the background.
- `bun run reset`: Shut down database containers.
- `bun run setup`: Generate Prisma Client types and push migrations/schemas.
- `bun run dev`: Run server in development watch mode.
- `bun run build`: Bundle the TypeScript application to `/dist` for production deployment.
- `bun run test`: Run the test suite using Bun's native test runner.
