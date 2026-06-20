# ktp-api

Minimal Node.js + Express + SQLite test API scaffold for the KTP app.

This project is intentionally incomplete. It only defines the folder structure, route placeholders, controller placeholders, model placeholders, and SQL starter files so backend logic can be added later.

## Install

```sh
npm install
```

## Run

```sh
npm start
```

or:

```sh
npm run dev
```

The server starts on:

```text
http://localhost:3000
```

## Planned Endpoints

Members:

```text
GET    /members
GET    /members/:id
POST   /members
PUT    /members/:id
DELETE /members/:id
```

Messages:

```text
GET    /messages
GET    /messages/:id
POST   /messages
PUT    /messages/:id
DELETE /messages/:id
```

## Notes

- Authentication is not included.
- Production deployment setup is not included.
- Route handlers currently contain TODO placeholders only.
- SQL schema files are starter files only.
