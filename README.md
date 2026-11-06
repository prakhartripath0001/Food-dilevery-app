# Food Delivery App

A full-stack food delivery application featuring:
- **Mobile Client**: Flutter (Android, iOS, Web)
- **Backend API**: Node.js & Express
- **Database**: MySQL 8.0 running inside Docker

---

## Project Structure

```
Food-dilvery-app/
├── database/               # SQL scripts (auto-run by Docker in alphabetical order)
│   ├── 01-schema.sql       # Table definitions (users, restaurants, orders, etc.)
│   ├── 02-seed.sql         # Sample seed data (categories, restaurants, menu items)
│   └── 03-address-details.sql # Extends addresses with recipient and location details
├── infra/                  # Infrastructure & Docker setup
│   └── docker-compose.yml  # MySQL 8.0 container service
├── server/                 # Express REST API backend
│   ├── .env                # Environment variables (DB credentials, port)
│   ├── src/
│   │   ├── app.js          # Express entry point & route registration
│   │   ├── config/         # Database connection pool (mysql2)
│   │   ├── controllers/    # Route controllers (categories, restaurants, orders)
│   │   ├── middlewares/    # Error handling & middleware
│   │   ├── routes/         # Express router endpoints
│   │   └── test-db.js      # DB connection diagnostic script
│   └── package.json
└── client_app/             # Flutter mobile client
    ├── android/            # Android config (Internet & cleartext traffic enabled)
    ├── lib/                # Flutter source code
    │   ├── main.dart       # App entry point & backend connection screen
    │   └── models/         # Category, Restaurant, MenuItem data models
    └── pubspec.yaml        # Flutter dependencies (http)
```

---

## Prerequisites

Make sure the following tools are installed on your machine:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Node.js](https://nodejs.org/) (v18 or higher)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)

---

## Quick Start (Step-by-Step)

### 1. Start the Database (Docker)

Start the MySQL container with automatic schema and seed data initialization:

```bash
cd infra
docker compose up -d
```

The SQL initialization scripts run automatically only when MySQL creates a new
data volume. For an existing database, apply
`database/03-address-details.sql` once to add address type, recipient, phone,
landmark, and GPS coordinate fields to the existing `addresses` table.
`address_line1` and `postal_code` remain the stored street address and postal
code, respectively; the table stays named `addresses` because orders already
reference it.

> **Database Details:**
> - **Host Port**: `3307` *(mapped to container's internal 3306 to avoid port 3306 conflicts)*
> - **Database Name**: `food_delivery_db`
> - **User / Password**: `food_user` / `food_password`
> - **Root Password**: `rootpassword`

---

### 2. Start the Backend Server (Express)

In a new terminal window:

```bash
cd server
```

1. **Verify your `.env` configuration** (already configured):
   ```env
   PORT=5001
   DB_HOST=localhost
   DB_PORT=3307
   DB_USER=food_user
   DB_PASSWORD=food_password
   DB_NAME=food_delivery_db
   JWT_SECRET=<a-random-secret-at-least-32-characters>
   ```
   *(If creating manually, copy from example: `cp .env.example .env`)*
   Generate a JWT secret, for example with `openssl rand -base64 32`, and set
   it as `JWT_SECRET`. Do not commit the generated secret.

2. **(Optional) Test database connection**:
   ```bash
   npm run test:db
   ```

3. **Start the development server**:
   ```bash
   npm run dev
   ```

The backend will start on **`http://localhost:5001`**.

Verify it is running in your browser:
- Health check: [http://localhost:5001/api/health](http://localhost:5001/api/health)
- Categories: [http://localhost:5001/api/categories](http://localhost:5001/api/categories)
- Restaurants: [http://localhost:5001/api/restaurants](http://localhost:5001/api/restaurants)

---

### 3. Start the Mobile Client (Flutter)

In another terminal window:

```bash
cd client_app
```

1. **Get dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run on Android Emulator or Device**:
   ```bash
   flutter run
   ```

Tap the location header to sign in or create an account, then choose a saved
address, search for a place, use the device's current location, or add an
address manually. The app asks for location permission only when current
location is requested. It stores the bearer token in secure device storage.

---

## Important Networking Notes

### Why Port 5001?
On **macOS (Monterey and newer)**, port `5000` is reserved by default by the native macOS **AirPlay Receiver (`ControlCenter`)**. Sending requests to port 5000 results in `403 Forbidden` / `Access not allowed`. The backend therefore runs on port **`5001`**.

### Connecting Flutter to Local Backend:
| Platform | Backend URL | Why? |
| :--- | :--- | :--- |
| **Android Emulator** | `http://10.0.2.2:5001` | In Android emulators, `10.0.2.2` aliases your computer's `localhost`. |
| **iOS Simulator** | `http://localhost:5001` | iOS simulator shares the macOS host network directly. |
| **Flutter Web / macOS** | `http://localhost:5001` | Runs on the host directly. |
| **Physical Phone** | `http://<YOUR_LOCAL_IP>:5001` | Use your computer's Wi-Fi IP (e.g. `192.168.1.5:5001`). Both devices must be on the same Wi-Fi. |

For a physical phone, configure the client to use your computer's Wi-Fi address:

```bash
flutter run --dart-define=API_BASE_URL=http://<YOUR_LOCAL_IP>:5001
```

---

## Available API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/api/health` | Client health check endpoint (`{"success": true, ...}`) |
| `GET` | `/health` | Full system & DB connectivity status check |
| `GET` | `/api/categories` | List all food categories |
| `GET` | `/api/restaurants` | List restaurants (supports `?search=query`) |
| `GET` | `/api/restaurants/:id` | Get restaurant details and full menu items |
| `POST` | `/api/auth/register` | Register and receive a bearer token |
| `POST` | `/api/auth/login` | Log in and receive a bearer token |
| `POST` | `/api/addresses` | Save an address (requires bearer token) |
| `GET` | `/api/addresses` | List the signed-in user's addresses |
| `GET` | `/api/addresses/:id` | Get one of the signed-in user's addresses |
| `PUT` | `/api/addresses/:id` | Replace one of the signed-in user's addresses |
| `DELETE` | `/api/addresses/:id` | Delete one of the signed-in user's addresses |
| `PATCH` | `/api/addresses/:id/default` | Set a saved address as default |
| `POST` | `/api/orders` | Place a new order with atomic DB transaction |
| `GET` | `/api/orders/:id` | Get order details and ordered items |

Address requests require `Authorization: Bearer <token>`. The server derives
the owner from the token; any `user_id` included in the request body is ignored.
Register and login accept `{ "name", "email", "password" }` (name is required
for registration) and return the token under `data.token`. Address fields use
camelCase (`addressType`, `recipientName`, `addressLine`, `landmark`, `city`,
`state`, `pincode`, `latitude`, `longitude`).

---

## Useful Commands

```bash
# View MySQL Docker logs
cd infra && docker compose logs -f

# Stop MySQL container
cd infra && docker compose down

# Stop MySQL and wipe data volume (clean restart)
cd infra && docker compose down -v

# Run DB connection test
cd server && npm run test:db
```
