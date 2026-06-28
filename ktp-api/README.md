# ktp-api

Node.js + Express + PostgreSQL API for the KTP iOS app.

## Prerequisites

- PostgreSQL running locally
- Database `ktp_life` and user `ktp_user` created in pgAdmin or psql

## Setup

```sh
cp .env.example .env
npm install
npm run db:init
```

`db:init` runs `db/schema.sql` (tables) and `db/seed.sql` (sample members).

Other scripts:

```sh
npm run db:schema   # schema only
npm run db:seed     # seed only
```

## Run

```sh
npm start
```

Server: `http://192.168.1.174:3000`

## Endpoints

Members (used by the iOS directory):

```text
GET    /members          — list all members (live in app)
GET    /members/:id      — single member
POST   /members          — create member
PUT    /members/:id      — update member
DELETE /members/:id      — delete member
```

Messages (not yet wired in the app):

```text
GET    /messages
GET    /messages/:id
POST   /messages
PUT    /messages/:id
DELETE /messages/:id
```

## Response shape for members

The iOS app expects this JSON from `GET /members`:

```json
[
  {
    "id": "1",
    "name": "Andrew Babatunde",
    "role": "Computer Science",
    "year": "2027",
    "group": "activeMembers"
  }
]
```

Mapping is handled in `models/memberModel.js` via `toDirectoryJSON()`.

## Notes

- Authentication is not included.
- See the root `README.md` for full iOS + API development workflow.
