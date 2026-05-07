# 🎓 Smart Attendance System — Backend API

> NestJS + MongoDB + JWT — University attendance management with RFID scanning

---

## 📋 Table of Contents

- [Architecture](#architecture)
- [Installation](#installation)
- [Environment Variables](#environment-variables)
- [Authentication Flows](#authentication-flows)
- [Role Permissions Matrix](#role-permissions-matrix)
- [API Endpoints](#api-endpoints)
- [Database Schema](#database-schema)

---

## Architecture

```
src/
├── auth/                   # Authentication (JWT, OTP, Guards)
│   ├── decorators/         # @Roles() decorator
│   ├── guards/             # JwtAuthGuard, RolesGuard
│   ├── dto/                # Login/Register DTOs
│   ├── auth.service.ts     # Auth business logic
│   ├── auth.controller.ts  # Public auth endpoints
│   ├── jwt.strategy.ts     # JWT token validation
│   ├── mail.service.ts     # OTP email via Nodemailer
│   └── auth.module.ts
├── teacher/                # Teacher CRUD (Admin only)
├── student/                # Student CRUD (Admin creates, auto-password)
├── module/                 # Academic modules/subjects
├── schedule/               # Fixed weekly timetable
├── session/                # Actual class sessions
├── attendance/             # RFID scan records
├── app.module.ts           # Root module
└── main.ts                 # Entry point + Swagger
```

### 🧪 Testing Structure
```
test/
├── app.e2e-spec.ts         # Massive Real API End-to-End Test Suite
└── jest-e2e.json           # Jest E2E configuration
```

---

## Installation

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd backend

# 2. Install dependencies
npm install

# 3. Configure environment variables (see below)
cp .env.example .env

# 4. Start development server
npm run start:dev
```

**Open Swagger:** http://localhost:3000/api

---

## Testing (End-to-End)

The backend features a comprehensive E2E test suite that runs against a real MongoDB database and hits real API endpoints. It covers 9 continuous phases (Admin Auth, Teacher Registration & OTP via DB extraction, Student Auto-Hashing, CRUD, and RFID Simulations).

```bash
# 1. Start the API Server first
npm run start:dev

# 2. Run the full E2E Test Suite
npm run test:e2e
```
*Note: The test suite strictly complies with the latest Mongoose updates and emits zero deprecation warnings (uses `{ returnDocument: 'after' }`)*

---

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `mongo_uri` | MongoDB Atlas connection string | `mongodb+srv://...` |
| `JWT_SECRET` | Secret key for JWT signing | `your-secret-key` |
| `PORT` | Server port | `3000` |
| `ADMIN_EMAIL` | Admin login email | `admin@admin.com` |
| `ADMIN_PASSWORD` | Admin login password | `admin123` |
| `SMTP_HOST` | SMTP server host | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_USER` | SMTP email address | `your-email@gmail.com` |
| `SMTP_PASS` | SMTP app password | `your-app-password` |

---

## Authentication Flows

### 👨‍🏫 Teacher Registration
1. `POST /auth/teacher/register` — provide fullName, email, password, department
2. System sends a 6-digit OTP to the email
3. `POST /auth/teacher/verify-otp` — provide email + OTP code
4. Account activated → JWT token returned

### 👨‍🏫 Teacher Login
- `POST /auth/teacher/login` — email + password → JWT token

### 👨‍🎓 Student Login
- `POST /auth/student/login` — studentId + password (birthday in `DDMMYYYY` format)
- Students are registered by the Admin. Password is auto-generated from their birthday.

### 🔑 Admin Login
- `POST /auth/admin/login` — email + password (from `.env` config)
- Admin has full access to all endpoints.

---

## 💻 Frontend Developer Guide

A comprehensive API guide covering the full Teacher workflow, endpoints, JWT authentication, and session lifecycle is available in the **[Teacher Frontend Guide](./TEACHER_FRONTEND_GUIDE.md)** file.

---
## Role Permissions Matrix

| Endpoint | Admin | Teacher | Student |
|---|:---:|:---:|:---:|
| **Auth (register/login/otp)** | — | ✅ Public | ✅ Public |
| `POST /teachers` | ✅ | ❌ | ❌ |
| `GET /teachers` | ✅ | ❌ | ❌ |
| `GET /teachers/:id` | ✅ | ✅ | ❌ |
| `PATCH/DELETE /teachers` | ✅ | ❌ | ❌ |
| `POST /students` | ✅ | ❌ | ❌ |
| `GET /students` | ✅ | ✅ | ❌ |
| `GET /students/:id` | ✅ | ✅ | ✅ |
| `PATCH/DELETE /students` | ✅ | ❌ | ❌ |
| `POST /modules` | ✅ | ✅ | ❌ |
| `GET /modules` | ✅ | ✅ | ✅ |
| `PATCH/DELETE /modules` | ✅ | ✅ | ❌ |
| `POST /schedules` | ✅ | ✅ | ❌ |
| `GET /schedules` | ✅ | ✅ | ✅ |
| `PATCH/DELETE /schedules` | ✅ | ✅ | ❌ |
| `POST /sessions` | ✅ | ✅ | ❌ |
| `GET /sessions` | ✅ | ✅ | ✅ |
| `PATCH /sessions/:id/status` | ✅ | ✅ | ❌ |
| `DELETE /sessions` | ✅ | ❌ | ❌ |
| `POST /attendance/scan` | ✅ | ✅ | ❌ |
| `GET /attendance/session/:id` | ✅ | ✅ | ❌ |
| `GET /attendance/student/:id` | ✅ | ✅ | ✅ |
| `DELETE /attendance` | ✅ | ❌ | ❌ |

---

## API Endpoints

### 🔓 Auth (Public)
| Method | Route | Description |
|---|---|---|
| `POST` | `/auth/teacher/register` | Teacher registration + OTP |
| `POST` | `/auth/teacher/verify-otp` | Verify OTP code |
| `POST` | `/auth/teacher/login` | Teacher login |
| `POST` | `/auth/student/login` | Student login |
| `POST` | `/auth/admin/login` | Admin login |

### 👨‍🏫 Teachers
| Method | Route | Description |
|---|---|---|
| `POST` | `/teachers` | Create teacher (Admin) |
| `GET` | `/teachers` | List all teachers (Admin) |
| `GET` | `/teachers/:id` | Get teacher by ID |
| `PATCH` | `/teachers/:id` | Update teacher (Admin) |
| `DELETE` | `/teachers/:id` | Delete teacher (Admin) |

### 👨‍🎓 Students
| Method | Route | Description |
|---|---|---|
| `POST` | `/students` | Create student (Admin — auto-password) |
| `GET` | `/students?group=2A&year=L2` | List students (filterable) |
| `GET` | `/students/rfid/:rfidCode` | Find by RFID |
| `GET` | `/students/:id` | Get student by ID |
| `PATCH` | `/students/:id` | Update student (Admin) |
| `DELETE` | `/students/:id` | Delete student (Admin) |

### 📚 Modules
| Method | Route | Description |
|---|---|---|
| `POST` | `/modules` | Create module |
| `GET` | `/modules` | List all modules |
| `GET` | `/modules/teacher/:teacherId` | Modules by teacher |
| `GET` | `/modules/:id` | Get module by ID |
| `PATCH` | `/modules/:id` | Update module |
| `DELETE` | `/modules/:id` | Delete module |

### 📅 Schedules
| Method | Route | Description |
|---|---|---|
| `POST` | `/schedules` | Create schedule |
| `GET` | `/schedules` | List all schedules |
| `GET` | `/schedules/teacher/:teacherId` | Schedules by teacher |
| `GET` | `/schedules/:id` | Get schedule by ID |
| `PATCH` | `/schedules/:id` | Update schedule |
| `DELETE` | `/schedules/:id` | Delete schedule |

### ⏱️ Sessions
| Method | Route | Description |
|---|---|---|
| `POST` | `/sessions` | Create session |
| `GET` | `/sessions?date=2026-04-28` | List sessions (filterable) |
| `GET` | `/sessions/teacher/:teacherId` | Sessions by teacher |
| `GET` | `/sessions/:id` | Get session by ID |
| `PATCH` | `/sessions/:id/status` | Update status |
| `PATCH` | `/sessions/:id` | Update session |
| `DELETE` | `/sessions/:id` | Delete session (Admin) |

### ✅ Attendance
| Method | Route | Description |
|---|---|---|
| `POST` | `/attendance/scan` | Record RFID scan |
| `GET` | `/attendance/session/:sessionId` | Attendance by session |
| `GET` | `/attendance/student/:studentId` | Attendance by student |
| `GET` | `/attendance/:id` | Get record by ID |
| `DELETE` | `/attendance/:id` | Delete record (Admin) |

---

## Database Schema

| Collection | Key Fields |
|---|---|
| **Teacher** | fullName, email, password (hashed), department, isVerified, otp |
| **Student** | fullName, email, birthday (DDMMYYYY), password (auto-hashed), studentId, rfidCode, qrCode, group, year, speciality |
| **Module** | name, teacherId (ref), year |
| **Schedule** | teacherId, moduleId, type (cours/td/tp), year, group, dayOfWeek, startTime, endTime, room |
| **Session** | scheduleId, teacherId, moduleId, date, type, status (planned/active/closed), isReplacement |
| **Attendance** | sessionId, studentId, status (present/late/absent), scanTime |

---

## Tech Stack

- **Runtime:** Node.js + NestJS 11
- **Database:** MongoDB Atlas + Mongoose
- **Auth:** JWT + Passport + bcrypt
- **Email:** Nodemailer (SMTP)
- **Docs:** Swagger UI (`/api`)
- **Validation:** class-validator + class-transformer
#
