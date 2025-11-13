# 🚀 BIT COMMAND – ULTIMATIVER MASTER-PROMPT FÜR CURSOR

**Kopiere diesen kompletten Text und füge ihn 1:1 in Cursor ein.**

---

## ❗ VOLLSTÄNDIGE PROJEKT-ERSTELLUNG: BIT COMMAND

Ich baue eine vollständige, produktionsreife Multi-Tenant MSP-Plattform namens **BIT Command**.

**Ziel:** Ein komplettes, skalierbares SaaS-System mit Frontend, Backend, Database, Auth, RBAC, Multi-Tenant-Isolation, Branding und Docker-Setup.

---

## 🎨 BRANDING & DESIGN

### Logo-Integration

**WICHTIG:** Das Logo liegt unter `/mnt/data/LOGO_MEDIA.png` (Cursor-interne Datei).

Falls diese Datei nicht direkt zugänglich ist:
1. Kopiere das Logo in `/public/bit-logo.png` im Frontend
2. Verwende es als App-Logo, Favicon, Login-Screen-Branding

### Design-System

**Primärfarbe:** `#FFC300` (Goldgelb)  
**Sekundärfarben:** `#000000` (Schwarz), `#262626` (Dunkelgrau)  
**Typografie:** `Inter` (Google Fonts)  
**Stil:** Minimalistisch, professionell, modern

### Branding-Datei erstellen

Erstelle `frontend/src/styles/branding.css`:

```css
:root {
  --bit-primary: #FFC300; /* Goldgelb */
  --bit-secondary: #000000;
  --bit-dark: #262626;
  --bit-gray: #3A3A3A;
  --bit-light: #FFFFFF;
  --bit-success: #10B981;
  --bit-warning: #F59E0B;
  --bit-error: #EF4444;

  --bit-radius: 6px;
  --bit-shadow: 0 2px 4px rgba(0,0,0,0.08);
  --bit-shadow-lg: 0 4px 12px rgba(0,0,0,0.12);
  --bit-font: 'Inter', sans-serif;
}

body {
  font-family: var(--bit-font);
  color: var(--bit-dark);
  background-color: #F9FAFB;
}

.bit-logo {
  height: 48px;
  aspect-ratio: auto;
  object-fit: contain;
}

.bit-button-primary {
  background-color: var(--bit-primary);
  color: var(--bit-dark);
  padding: 10px 18px;
  border-radius: var(--bit-radius);
  border: none;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.bit-button-primary:hover {
  background-color: #FFD700;
  transform: translateY(-1px);
  box-shadow: var(--bit-shadow);
}

.bit-card {
  background: white;
  padding: 24px;
  border-radius: var(--bit-radius);
  box-shadow: var(--bit-shadow);
  margin-bottom: 16px;
}

.bit-navbar {
  background: var(--bit-secondary);
  color: white;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.bit-navbar .bit-logo {
  filter: brightness(0) invert(1);
}
```

---

## 🏗️ ARCHITEKTUR

```
                      ┌─────────────────────────────┐
                      │         BIT Command          │
                      │     (Next.js Frontend)       │
                      │   Port: 3000 (Dev) / 80     │
                      └──────────────┬──────────────┘
                                     │
                                     │ HTTPS (JWT/Auth)
                                     │ REST API
                                     ▼
                      ┌─────────────────────────────┐
                      │        Backend API           │
                      │     (NestJS empfohlen)       │
                      │   Port: 3001 (Dev) / 8080   │
                      ├──────────────┬──────────────┤
                      │ Auth Service │ Tenant Guard  │
                      ├──────────────┼──────────────┤
                      │ Users        │ Tenants       │
                      │ Devices      │ Tickets       │
                      │ Flags        │ Monitoring    │
                      └──────────────┬──────────────┘
                                     │
                                     │ SQL (Prisma ORM)
                                     ▼
                       ┌───────────────────────────┐
                       │       PostgreSQL DB        │
                       │   Port: 5432              │
                       │ tenants/users/devices/etc. │
                       └───────────────────────────┘

                                     │
                                     │ Optional Integrationen
                                     ▼
   ┌────────────────────────────────────┬─────────────────────────────────────────┐
   │                                    │                                         │
┌───────┐                        ┌────────────┐                           ┌────────────┐
│Netdata│                        │Zammad API  │                           │MeshCentral │
│(Metrics)                       │(Tickets)   │                           │(Remote)    │
└───────┘                        └────────────┘                           └────────────┘
```

**Entscheidung:** Verwende **NestJS** für das Backend (bessere Struktur für Multi-Tenant, Guards, Middleware).

---

## 🔐 ROLLENMODELL (RBAC)

### 1. SuperAdmin
- **Zugriff:** ALLE Tenants, ALLE Daten
- **Berechtigungen:**
  - Kunden (Tenants) erstellen/bearbeiten/löschen
  - Benutzer für alle Tenants verwalten
  - Feature Flags global setzen
  - Alle Geräte sehen
  - Alle Tickets sehen
  - System-Einstellungen

### 2. CustomerAdmin
- **Zugriff:** Nur eigener Tenant
- **Berechtigungen:**
  - Eigene Benutzer verwalten
  - Geräte im Tenant verwalten
  - Tickets erstellen/bearbeiten
  - Monitoring sehen
  - Reports exportieren

### 3. CustomerUser
- **Zugriff:** Nur eigene Daten im Tenant
- **Berechtigungen:**
  - Eigene Tickets sehen/erstellen
  - Geräte-Status sehen (read-only)
  - Basic Monitoring sehen

**Multi-Tenant-Isolation:** Pflicht. Jede Query muss Tenant-Filter haben (außer SuperAdmin).

---

## 📦 VOLLSTÄNDIGE MODULE-ÜBERSICHT

### 1. AUTH MODULE
- **Login:** E-Mail + Passwort
- **JWT:** Access Token + Refresh Token
- **Session:** Optional (für später)
- **Multi-Tenant:** Tenant wird beim Login geladen
- **Endpunkte:**
  - `POST /auth/login` → `{ email, password }` → `{ token, user, tenant }`
  - `POST /auth/refresh` → `{ refreshToken }` → `{ token }`
  - `POST /auth/logout` → Invalidate Token

### 2. TENANTS MODULE (SuperAdmin-Only)
- **CRUD:** Create, Read, Update, Delete
- **Felder:**
  - `name` (String, required)
  - `industry` (String, optional)
  - `address` (String, optional)
  - `contactPerson` (String, optional)
  - `contactEmail` (String, required)
  - `plan` (Enum: 'basic', 'premium', 'enterprise')
  - `status` (Enum: 'active', 'suspended', 'inactive')
  - `createdAt`, `updatedAt`
- **Endpunkte:**
  - `GET /tenants` → Liste aller Tenants (SuperAdmin)
  - `GET /tenants/:id` → Tenant-Details
  - `POST /tenants` → Neuen Tenant erstellen
  - `PATCH /tenants/:id` → Tenant aktualisieren
  - `DELETE /tenants/:id` → Tenant löschen (soft delete)

### 3. USERS MODULE
- **CRUD:** Mit Tenant-Isolation
- **Felder:**
  - `email` (String, unique, required)
  - `password` (String, hashed, required)
  - `firstName` (String, required)
  - `lastName` (String, required)
  - `role` (Enum: 'SuperAdmin', 'CustomerAdmin', 'CustomerUser')
  - `tenantId` (Foreign Key, nullable für SuperAdmin)
  - `isActive` (Boolean, default: true)
  - `lastLogin` (DateTime, optional)
- **Endpunkte:**
  - `GET /users?tenantId=x` → Benutzer-Liste (gefiltert nach Tenant)
  - `GET /users/:id` → Benutzer-Details
  - `POST /users` → Neuen Benutzer erstellen
  - `PATCH /users/:id` → Benutzer aktualisieren
  - `DELETE /users/:id` → Benutzer löschen (soft delete)

### 4. FEATURE FLAGS MODULE
- **Pro Tenant:** Jeder Tenant hat eigene Feature-Flags
- **Flags:**
  - `monitoring` (Boolean)
  - `tickets` (Boolean)
  - `devices` (Boolean)
  - `backups` (Boolean)
  - `reports` (Boolean)
  - `remoteAccess` (Boolean)
  - `documents` (Boolean)
- **Endpunkte:**
  - `GET /features?tenantId=x` → Feature-Flags für Tenant
  - `PATCH /features/:tenantId` → Feature-Flags aktualisieren
- **Frontend:** UI-Elemente werden basierend auf Flags ein/ausgeblendet

### 5. DEVICES MODULE
- **CRUD:** Mit Tenant-Isolation
- **Felder:**
  - `name` (String, required)
  - `tenantId` (Foreign Key, required)
  - `os` (String, optional)
  - `ipAddress` (String, optional)
  - `status` (Enum: 'online', 'offline', 'warning', 'critical')
  - `lastCheckIn` (DateTime, optional)
  - `metadata` (JSON, optional) → Zusätzliche Infos
- **Endpunkte:**
  - `GET /devices?tenantId=x` → Geräte-Liste
  - `GET /devices/:id` → Gerät-Details
  - `POST /devices` → Neues Gerät erstellen
  - `PATCH /devices/:id` → Gerät aktualisieren
  - `DELETE /devices/:id` → Gerät löschen

### 6. MONITORING MODULE (MVP: Dummy-Daten)
- **Status:** OK / Warnung / Kritisch / Offline
- **Metriken (vereinfacht):**
  - `cpu` (Number, 0-100)
  - `memory` (Number, 0-100)
  - `disk` (Number, 0-100)
  - `uptime` (Number, Sekunden)
- **Endpunkte:**
  - `GET /monitoring/status?deviceId=x` → Status für Gerät
  - `GET /monitoring/metrics?deviceId=x` → Metriken für Gerät
- **Hinweis:** MVP liefert Dummy-Daten. API-Struktur vorbereitet für Netdata/Prometheus-Integration.

### 7. TICKETS MODULE (MVP: Lokal in DB)
- **CRUD:** Mit Tenant-Isolation
- **Felder:**
  - `title` (String, required)
  - `description` (Text, required)
  - `tenantId` (Foreign Key, required)
  - `createdBy` (Foreign Key → User, required)
  - `assignedTo` (Foreign Key → User, optional)
  - `status` (Enum: 'open', 'in_progress', 'resolved', 'closed')
  - `priority` (Enum: 'low', 'medium', 'high', 'critical')
  - `createdAt`, `updatedAt`
- **Endpunkte:**
  - `GET /tickets?tenantId=x` → Ticket-Liste
  - `GET /tickets/:id` → Ticket-Details
  - `POST /tickets` → Neues Ticket erstellen
  - `PATCH /tickets/:id` → Ticket aktualisieren
  - `DELETE /tickets/:id` → Ticket löschen
- **Hinweis:** MVP lokal. API-Struktur vorbereitet für Zammad-Integration.

### 8. REPORTS MODULE
- **Export:** JSON + PDF (PDF optional)
- **Endpunkte:**
  - `GET /reports/devices?tenantId=x&format=json` → Geräte-Report
  - `GET /reports/tickets?tenantId=x&format=json` → Ticket-Report
  - `GET /reports/monitoring?tenantId=x&format=json` → Monitoring-Report

---

## 🗄️ DATABASE SCHEMA (PostgreSQL + Prisma)

Erstelle `backend/prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Tenant {
  id            String   @id @default(uuid())
  name          String
  industry      String?
  address       String?
  contactPerson String?
  contactEmail  String   @unique
  plan          String   @default("basic") // basic, premium, enterprise
  status        String   @default("active") // active, suspended, inactive
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  users    User[]
  devices  Device[]
  tickets  Ticket[]
  features FeatureFlags?

  @@map("tenants")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  password  String // hashed
  firstName String
  lastName  String
  role      String   @default("CustomerUser") // SuperAdmin, CustomerAdmin, CustomerUser
  tenantId  String?
  isActive  Boolean  @default(true)
  lastLogin DateTime?

  tenant     Tenant?  @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  createdTickets Ticket[] @relation("CreatedTickets")
  assignedTickets Ticket[] @relation("AssignedTickets")

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("users")
}

model Device {
  id          String   @id @default(uuid())
  name        String
  tenantId    String
  os          String?
  ipAddress   String?
  status      String   @default("offline") // online, offline, warning, critical
  lastCheckIn DateTime?
  metadata    Json?

  tenant Tenant @relation(fields: [tenantId], references: [id], onDelete: Cascade)

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("devices")
}

model Ticket {
  id          String   @id @default(uuid())
  title       String
  description String
  tenantId    String
  createdBy   String
  assignedTo String?
  status      String   @default("open") // open, in_progress, resolved, closed
  priority    String   @default("medium") // low, medium, high, critical

  tenant    Tenant @relation(fields: [tenantId], references: [id], onDelete: Cascade)
  creator   User    @relation("CreatedTickets", fields: [createdBy], references: [id])
  assignee  User?   @relation("AssignedTickets", fields: [assignedTo], references: [id])

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("tickets")
}

model FeatureFlags {
  id          String @id @default(uuid())
  tenantId    String @unique
  monitoring  Boolean @default(true)
  tickets     Boolean @default(true)
  devices     Boolean @default(true)
  backups     Boolean @default(false)
  reports     Boolean @default(true)
  remoteAccess Boolean @default(false)
  documents   Boolean @default(false)

  tenant Tenant @relation(fields: [tenantId], references: [id], onDelete: Cascade)

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@map("feature_flags")
}
```

---

## 📁 PROJEKT-STRUKTUR

Erstelle folgende Ordnerstruktur:

```
bit-command/
├── frontend/
│   ├── src/
│   │   ├── app/                    # Next.js App Router
│   │   │   ├── (auth)/
│   │   │   │   └── login/
│   │   │   ├── (admin)/
│   │   │   │   ├── dashboard/
│   │   │   │   ├── tenants/
│   │   │   │   ├── users/
│   │   │   │   └── settings/
│   │   │   ├── (customer)/
│   │   │   │   ├── dashboard/
│   │   │   │   ├── devices/
│   │   │   │   ├── tickets/
│   │   │   │   └── monitoring/
│   │   │   └── layout.tsx
│   │   ├── components/
│   │   │   ├── ui/                 # Reusable UI components
│   │   │   ├── layout/
│   │   │   │   ├── Navbar.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   └── Footer.tsx
│   │   │   └── features/           # Feature-specific components
│   │   ├── lib/
│   │   │   ├── api.ts              # API client
│   │   │   ├── auth.ts             # Auth utilities
│   │   │   └── utils.ts
│   │   ├── hooks/
│   │   │   ├── useAuth.ts
│   │   │   └── useTenant.ts
│   │   ├── styles/
│   │   │   ├── globals.css
│   │   │   └── branding.css
│   │   └── types/
│   │       └── index.ts
│   ├── public/
│   │   └── bit-logo.png            # Logo hier kopieren
│   ├── package.json
│   ├── next.config.js
│   ├── tailwind.config.js
│   └── tsconfig.json
│
├── backend/
│   ├── src/
│   │   ├── auth/
│   │   │   ├── auth.controller.ts
│   │   │   ├── auth.service.ts
│   │   │   ├── auth.module.ts
│   │   │   ├── guards/
│   │   │   │   ├── jwt.guard.ts
│   │   │   │   └── roles.guard.ts
│   │   │   └── strategies/
│   │   │       └── jwt.strategy.ts
│   │   ├── tenants/
│   │   │   ├── tenants.controller.ts
│   │   │   ├── tenants.service.ts
│   │   │   └── tenants.module.ts
│   │   ├── users/
│   │   ├── devices/
│   │   ├── tickets/
│   │   ├── monitoring/
│   │   ├── features/
│   │   ├── reports/
│   │   ├── common/
│   │   │   ├── decorators/
│   │   │   │   ├── roles.decorator.ts
│   │   │   │   └── tenant.decorator.ts
│   │   │   ├── guards/
│   │   │   │   └── tenant.guard.ts
│   │   │   └── interceptors/
│   │   ├── app.module.ts
│   │   └── main.ts
│   ├── prisma/
│   │   └── schema.prisma
│   ├── package.json
│   ├── tsconfig.json
│   └── Dockerfile
│
├── docker/
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   └── .env.example
│
├── docs/
│   ├── API.md
│   ├── DEPLOYMENT.md
│   └── ARCHITECTURE.md
│
├── README.md
└── .gitignore
```

---

## 🐳 DOCKER SETUP

### docker-compose.yml (Development)

```yaml
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: bit-command-db
    environment:
      POSTGRES_USER: bitcommand
      POSTGRES_PASSWORD: ${DB_PASSWORD:-change_me_in_production}
      POSTGRES_DB: bitcommand
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bitcommand"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: bit-command-api
    environment:
      DATABASE_URL: postgresql://bitcommand:${DB_PASSWORD:-change_me_in_production}@postgres:5432/bitcommand
      JWT_SECRET: ${JWT_SECRET:-change_me_in_production}
      JWT_EXPIRES_IN: 7d
      PORT: 3001
    ports:
      - "3001:3001"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./backend:/app
      - /app/node_modules
    command: npm run start:dev

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: bit-command-web
    environment:
      NEXT_PUBLIC_API_URL: http://localhost:3001
    ports:
      - "3000:3000"
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    command: npm run dev

volumes:
  postgres_data:
```

### docker-compose.prod.yml (Production)

```yaml
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: bit-command-db
    environment:
      POSTGRES_USER: bitcommand
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: bitcommand
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bitcommand"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - bit-command-net

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    container_name: bit-command-api
    environment:
      DATABASE_URL: postgresql://bitcommand:${DB_PASSWORD}@postgres:5432/bitcommand
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRES_IN: 7d
      NODE_ENV: production
      PORT: 3001
    depends_on:
      postgres:
        condition: service_healthy
    restart: always
    networks:
      - bit-command-net

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.prod
    container_name: bit-command-web
    environment:
      NEXT_PUBLIC_API_URL: ${API_URL:-http://localhost:3001}
    depends_on:
      - backend
    restart: always
    networks:
      - bit-command-net

volumes:
  postgres_data:

networks:
  bit-command-net:
    driver: bridge
```

---

## 📝 README.md

Erstelle eine professionelle README.md:

```markdown
# BIT Command

**Multi-Tenant MSP Platform & Admin Control Center**

BIT Command ist eine zentrale, skalierbare SaaS-Plattform für IT-Dienstleister.  
Sie kombiniert SuperAdmin Control Center, Kundenportal, Geräteverwaltung, Monitoring, Tickets, Feature Flags und Multi-Tenant Isolation.

## 🚀 Technologie-Stack

### Frontend
- **Next.js 14** (App Router)
- **TypeScript**
- **TailwindCSS**
- **React Query** (für API-State)

### Backend
- **NestJS** (Node.js Framework)
- **Prisma** (ORM)
- **JWT** (Authentication)
- **Passport** (Auth Strategy)

### Database
- **PostgreSQL 16**

### Deployment
- **Docker** + **docker-compose**
- **Nginx** (optional, für Production)

---

## 🔐 Rollenmodell

| Rolle | Beschreibung | Zugriff |
|------|--------------|---------|
| **SuperAdmin** | System-Administrator | Alle Tenants, volle Kontrolle |
| **CustomerAdmin** | Kunden-Administrator | Nur eigener Tenant, User-Verwaltung |
| **CustomerUser** | Kunden-Benutzer | Nur eigene Daten im Tenant |

---

## 📦 Module (MVP)

- ✅ **Auth** - Login, JWT, Session Management
- ✅ **Tenants** - Multi-Tenant-Verwaltung
- ✅ **Users** - Benutzerverwaltung mit RBAC
- ✅ **Feature Flags** - Pro-Tenant Feature-Steuerung
- ✅ **Devices** - Geräteverwaltung
- ✅ **Tickets** - Ticket-System (MVP: lokal)
- ✅ **Monitoring** - Status & Metriken (MVP: Dummy-Daten)
- ✅ **Reports** - Export (JSON + PDF optional)

---

## 🏁 Quick Start

### Development

```bash
# 1. Repository klonen
git clone <repo-url>
cd bit-command

# 2. Environment-Variablen setzen
cp docker/.env.example docker/.env
# Bearbeite docker/.env mit deinen Werten

# 3. Starten
docker-compose -f docker/docker-compose.yml up --build

# 4. Database migrieren
docker-compose exec backend npx prisma migrate dev

# 5. Access
# Frontend: http://localhost:3000
# Backend API: http://localhost:3001
# Database: localhost:5432
```

### Production (bit-admin)

```bash
# 1. Auf Server deployen
cd /srv/bit-command
git pull origin main

# 2. Environment-Variablen setzen
cp docker/.env.example docker/.env.prod
# Bearbeite .env.prod

# 3. Starten
docker-compose -f docker/docker-compose.prod.yml up -d --build

# 4. Database migrieren
docker-compose -f docker/docker-compose.prod.yml exec backend npx prisma migrate deploy
```

---

## 🖼️ Branding

- **Logo:** `/public/bit-logo.png`
- **Primärfarbe:** `#FFC300` (Goldgelb)
- **Typografie:** `Inter` (Google Fonts)

---

## 📚 API-Dokumentation

Siehe [docs/API.md](docs/API.md) für vollständige API-Spezifikation.

---

## 🔧 Systemd Service (Production)

Siehe [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) für Systemd-Service-Setup.

---

## 📄 Lizenz

MIT License

---

**BIT Command** - Die kleinste Einheit mit der grössten Wirkung.
```

---

## 🚀 SYSTEMD-SERVICE FÜR BIT-ADMIN

Erstelle `docs/DEPLOYMENT.md`:

```markdown
# Deployment-Anleitung für bit-admin

## Systemd Service Setup

### 1. Service-Datei erstellen

```bash
sudo nano /etc/systemd/system/bit-command.service
```

Inhalt:

```ini
[Unit]
Description=BIT Command Production Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=/srv/bit-command
ExecStart=/usr/bin/docker compose -f docker/docker-compose.prod.yml up -d --build
ExecStop=/usr/bin/docker compose -f docker/docker-compose.prod.yml down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 2. Service aktivieren

```bash
sudo systemctl daemon-reload
sudo systemctl enable bit-command.service
sudo systemctl start bit-command.service
```

### 3. Status prüfen

```bash
sudo systemctl status bit-command.service
docker-compose -f /srv/bit-command/docker/docker-compose.prod.yml ps
```

### 4. Logs ansehen

```bash
sudo journalctl -u bit-command.service -f
docker-compose -f /srv/bit-command/docker/docker-compose.prod.yml logs -f
```
```

---

## 🎯 IMPLEMENTIERUNGS-ANWEISUNGEN FÜR CURSOR

**WICHTIG:** Baue das Projekt in dieser Reihenfolge:

### Phase 1: Grundstruktur
1. Erstelle Projekt-Ordnerstruktur
2. Initialisiere Next.js Frontend
3. Initialisiere NestJS Backend
4. Erstelle Prisma Schema
5. Erstelle Docker-Setup

### Phase 2: Backend (NestJS)
1. **Auth Module:**
   - JWT Strategy
   - Login/Refresh Endpoints
   - Guards (JWT, Roles, Tenant)
2. **Tenants Module:**
   - CRUD Controller/Service
   - Tenant Guard (Isolation)
3. **Users Module:**
   - CRUD mit Tenant-Filter
   - Role-Based Access
4. **Devices Module:**
   - CRUD mit Tenant-Filter
5. **Tickets Module:**
   - CRUD mit Tenant-Filter
6. **Monitoring Module:**
   - Dummy-Daten Generator
   - API-Endpunkte
7. **Features Module:**
   - Feature-Flags Service
8. **Reports Module:**
   - JSON Export

### Phase 3: Frontend (Next.js)
1. **Layout:**
   - Navbar mit Logo
   - Sidebar (Admin/Customer)
   - Footer
2. **Auth:**
   - Login-Page
   - Auth Context/Hook
   - Protected Routes
3. **Admin-Bereich:**
   - Dashboard
   - Tenants-Verwaltung
   - Users-Verwaltung
   - Settings
4. **Customer-Bereich:**
   - Dashboard
   - Devices-Übersicht
   - Tickets
   - Monitoring
5. **Components:**
   - Reusable UI (Buttons, Cards, Tables)
   - Feature-Flag-basierte Rendering

### Phase 4: Integration & Testing
1. API-Client im Frontend
2. Form-Validierung
3. Error-Handling
4. Loading States
5. Responsive Design

### Phase 5: Docker & Deployment
1. Dockerfiles (Dev + Prod)
2. docker-compose.yml
3. Environment-Variablen
4. Systemd Service

---

## ✅ CHECKLISTE FÜR CURSOR

- [ ] Projekt-Ordnerstruktur erstellt
- [ ] Frontend (Next.js) initialisiert
- [ ] Backend (NestJS) initialisiert
- [ ] Prisma Schema erstellt
- [ ] Database migriert
- [ ] Auth Module implementiert
- [ ] Tenants Module implementiert
- [ ] Users Module implementiert
- [ ] Devices Module implementiert
- [ ] Tickets Module implementiert
- [ ] Monitoring Module (Dummy) implementiert
- [ ] Features Module implementiert
- [ ] Reports Module implementiert
- [ ] Frontend Login-Page
- [ ] Frontend Admin-Dashboard
- [ ] Frontend Customer-Dashboard
- [ ] Logo integriert
- [ ] Branding CSS erstellt
- [ ] Docker Setup
- [ ] README.md
- [ ] Systemd Service
- [ ] API-Dokumentation

---

## 🎨 LOGO-INTEGRATION

**WICHTIG:** Das Logo muss an folgenden Stellen erscheinen:

1. **Navbar (oben links)** - Immer sichtbar
2. **Login-Screen** - Zentriert oder oben
3. **Favicon** - `frontend/public/favicon.ico`
4. **App-Icon** - Für PWA (optional)

**Logo-Pfad:** Falls `/mnt/data/LOGO_MEDIA.png` nicht verfügbar:
- Kopiere Logo manuell nach `frontend/public/bit-logo.png`
- Verwende `<Image src="/bit-logo.png" />` in Next.js

---

## 🔥 FINALE ANWEISUNG

**Cursor, beginne jetzt mit der Erstellung:**

1. **Erstelle die komplette Projektstruktur**
2. **Implementiere Backend (NestJS) mit allen Modulen**
3. **Implementiere Frontend (Next.js) mit allen Seiten**
4. **Integriere Logo und Branding**
5. **Erstelle Docker-Setup**
6. **Erstelle Dokumentation**

**Ziel:** Ein vollständiges, lauffähiges MVP, das auf `bit-admin` deploybar ist.

**Qualität:** Production-ready Code, saubere Struktur, TypeScript, Error-Handling, Validierung.

**Los geht's! 🚀**

