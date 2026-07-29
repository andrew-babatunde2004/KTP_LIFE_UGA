# KTP_LIFE_UGA

Native iOS app for the UGA Kappa Theta Pi chapter. The app talks to the production KTP API at `https://api2.ugaktp.com` by default. This repo contains the SwiftUI client only; the API is maintained outside this project.

## Getting started

### Prerequisites

- Xcode (open `KTPLIFE/KTPLIFE.xcodeproj`)
- The KTP backend at `https://api2.ugaktp.com`
- An Authentik login on `https://auth.ugaktp.com/application/o/ktpapp/`

### Configure the API URL

1. Copy the secrets template (once per machine):
   ```sh
   cd KTPLIFE/KTPLIFE
   cp Secrets.example.plist Secrets.plist
   ```
2. Edit `Secrets.plist` and set `API_BASE_URL` if you need to override production:
   - **Production:** `https://api2.ugaktp.com`
   - **Internal server/LXC network:** `http://10.0.0.53:4000`
3. The app now performs native Authentik SSO. No manual access token is needed for normal use.

`Secrets.plist` is gitignored. `Secrets.example.plist` is the committed template.

### Run the app

1. Open `KTPLIFE/KTPLIFE.xcodeproj` and run on the **Simulator** or a device.
2. Sign in with SSO on the initial login screen.
3. Complete your profile if prompted.
4. Use the tab bar to navigate. Protected screens load members from `GET /members` after the app stores and refreshes your Authentik tokens.

### Key files

| File | Role |
|------|------|
| `KTPLIFE/KTPLIFE/Secrets.example.plist` | Committed template for `API_BASE_URL` |
| `KTPLIFE/KTPLIFE/Secrets.plist` | Local API override file (gitignored; copy from example) |
| `KTPLIFE/KTPServices/APIConfig.swift` | Loads API config from Secrets plist |
| `KTPLIFE/KTPServices/AuthConfiguration.swift` | Central Authentik issuer, client ID, redirect URI, and scopes |
| `KTPLIFE/KTPServices/OIDCAuthService.swift` | Native OIDC login and token refresh |
| `KTPLIFE/KTPServices/MemberAPIService.swift` | Fetches protected `/members` and `/messages` with a Bearer token |
| `KTPLIFE/KTPViewModels/AuthManager.swift` | Coordinates login, token refresh, and profile gating |
| `KTPLIFE/KTPServices/PhotoService.swift` | Fetches, uploads, deletes, and loads media from protected `/photos` |
| `KTPLIFE/KTPServices/CalendarNetwork.swift` | Fetches `/events` |
| `KTPLIFE/KTPModels/DirectoryMember.swift` | Swift model matching member JSON |
| `KTPLIFE/KTPLIFE/ContentView.swift` | Routes the app between SSO login, profile completion, and the main shell |

### API contract

Full request/response detail, auth rules, and body shapes live in `ktp-api`'s own README — this list is the route surface only.

```text
GET    /                                        Health check

# Directory
GET    /members
GET    /members/:id

# Public roster (no auth — backs the public "meet the chapter" page)
GET    /roster
GET    /roster/:id/media

# Profile & account
POST   /users/sync
GET    /users/me
PUT    /users/me/profile
PUT    /users/me/profile-picture
DELETE /users/me
GET    /users/:id/profile-picture/media
GET    /users/blocked
POST   /users/:id/block
DELETE /users/:id/block

# Events / calendar
GET    /events
GET    /events/:id
POST   /events
PUT    /events/:id
DELETE /events/:id

# Attendance (QR check-in)
GET    /events/:id/attendance/code
GET    /events/:id/attendance
PUT    /events/:id/attendance/:userId
POST   /checkin/:eventId/:token

# Committees
GET    /committees
POST   /committees
DELETE /committees/:id
POST   /committees/:id/join
DELETE /committees/:id/leave
GET    /committees/:id/members
PUT    /committees/:id/members/:userId/role

# Polls
GET    /polls
POST   /polls
DELETE /polls/:id
PUT    /polls/:id/close
POST   /polls/:id/vote
GET    /polls/:id/stats

# Announcements
GET    /announcements
POST   /announcements
PUT    /announcements/:id
DELETE /announcements/:id

# Direct messages
GET    /messages/unread-count
GET    /messages/conversations
GET    /messages/conversations/:userId
PUT    /messages/conversations/:userId/read
POST   /messages
GET    /messages/:messageId/attachment
POST   /messages/:messageId/reactions
DELETE /messages/:messageId

# Group chats
GET    /group-chats
GET    /group-chats/unread-count
POST   /group-chats
DELETE /group-chats/:id
PUT    /group-chats/:id/photo
GET    /group-chats/:id/photo/media
GET    /group-chats/:id/members
POST   /group-chats/:id/members
DELETE /group-chats/:id/members/:userId
GET    /group-chats/:id/messages
POST   /group-chats/:id/messages
GET    /group-chats/:id/messages/:messageId/attachment
POST   /group-chats/:id/messages/:messageId/reactions
DELETE /group-chats/:id/messages/:messageId
PUT    /group-chats/:id/read

# Photos & albums
GET    /photos
GET    /photos/:id/media
POST   /photos
DELETE /photos/:id
GET    /albums
POST   /albums
DELETE /albums/:id

# Documents
GET    /documents/folders
POST   /documents/folders
DELETE /documents/folders/:id
GET    /documents
GET    /documents/:id/download
GET    /documents/:id/preview
POST   /documents
POST   /documents/link
DELETE /documents/:id

# iOS homepage slideshow
GET    /ios-homepage-photos
GET    /ios-homepage-photos/:id/media
POST   /ios-homepage-photos
POST   /ios-homepage-photos/register
PUT    /ios-homepage-photos/reorder
PUT    /ios-homepage-photos/:id
DELETE /ios-homepage-photos/:id

# Public homepage gallery (website's marketing gallery — distinct from the slideshow above)
GET    /homepage-photos
GET    /homepage-photos/:id/media
POST   /homepage-photos
POST   /homepage-photos/register
PUT    /homepage-photos/reorder
DELETE /homepage-photos/:id

# Reports & moderation
POST   /reports
GET    /reports
PUT    /reports/:id/status

# Push notifications
POST   /notifications/devices
DELETE /notifications/devices/:token
GET    /notifications/preferences
PUT    /notifications/preferences

# Admin (eboard only)
GET    /admin/users
PUT    /admin/users/:authentikId/group
PUT    /admin/users/:authentikId/exec-title

# Authentik integration
POST   /webhooks/authentik
```

Routes guarded by the backend auth middleware require:

```text
Authorization: Bearer <access_token>
```

The Swift member model accepts production member groups: `active`, `pledge`, `eboard`, `chair`, and `alumni`.

Two endpoints are public and take no token: `GET /roster` and `GET /roster/:id/media`. `GET /events` accepts a token optionally — anonymous callers get only untargeted public events, which is what keeps the calendar working before sign-in.

### Attendance & check-in

Events can opt into attendance tracking (`requiresAttendance`). When enabled, the API generates a one-time `attendance_token` for the event, retrievable only via `GET /events/:id/attendance/code` by an eboard member or the event's creator. That pair encodes into a QR code pointing at `<site>/checkin/:eventId/:token`.

Scanning it while signed in hits `POST /checkin/:eventId/:token`, which validates the token against the event's real one and that the current time falls inside the event window plus a 30-minute grace period. Outside that window, or with a stale token, it 403s.

Members have no attendance UI beyond the confirmation screen after a scan. Viewing the roster of who checked in, and manually correcting a status, is limited to eboard and the event creator.

### Messaging capabilities

Both DMs and group chat messages support **emoji reactions** (`POST .../reactions` toggles), **file attachments** (multipart on send, streamed back from the `/attachment` route), and **deletion** — a sender can always delete their own message, and eboard can delete any message within a conversation they're already part of.

Message sends are rate-limited to 20/minute per user and run through a basic content filter, so a `400` on send isn't necessarily a client bug. Blocking is enforced server-side: a blocked user's messages are hidden from the blocker's view and new conversations can't start in either direction.

### Reports and moderation

Members can report a directory profile, a direct or group message, or a chapter photo from the relevant detail screen. The report sheet sends `content_type`, the applicable `content_id`, the known `reported_user_id`, a reason, and optional details to `POST /reports`.

Eboard members can review the backend-authorized queue from **Profile → Review Reports**. The queue supports filtering by report status and updating a report to `resolved` or `dismissed` with an optional moderator response. The client only exposes this entry point for the `eboard` member group; the API remains the authorization authority.

### Troubleshooting

**Directory shows a sign-in screen** — complete the SSO flow first. The app stores Authentik tokens and refreshes them automatically.

**Public tabs show a load error** — confirm `API_BASE_URL` in `Secrets.plist` is correct and the device can reach that host.

**App Transport Security** — local HTTP is allowed via `NSAllowsLocalNetworking` in `Info.plist`. Production HTTPS endpoints do not need extra ATS changes.

## UI Conventions

- New cards, filters, headers, buttons, and page controls should use matte surfaces that visually match the current page background.
- Do not add glass styling to new elements unless it is explicitly requested.
- Exception: the bottom app tab bar is allowed to remain glass.
- When adding a new page, create a separate `...View.swift`, add the case to `AppTab`, route it in `ContentView`, and keep page-specific UI inside that page file.
- App backgrounds should be solid colors, not gradients.
- Change page backgrounds in `KTPLIFE/KTPLIFE/AppTab.swift` (`PageTheme.defaultBlue`, `PageTheme.defaultWhite`, `PageTheme.opportunities`).
- When creating new elements or pages, unless specified do not add any emojis or icons; if it is an image file being used leave it be. The design should be clean and simple, relying on typography and layout rather than decorative elements.
- The KTP logo is an allowed brand image on Home, Sign Up, and Authentication screens. Use `KTPLogoMark` from `KTPLIFE/KTPLIFE/SharedViews.swift` instead of duplicating logo image code.
- Make sure when adding new pages or elements that proper documentation is being used as your context alone does not help others who are working on the project.
- Make sure that all new pages or elements are tested in both light and dark mode. Test on multiple devices and screen sizes to ensure a consistent experience across devices.

## Typography

- App text should use `AppFont` from `KTPLIFE/KTPLIFE/AppTypography.swift`, not direct `.system(...)` font calls.
- The current app font is Avenir Next, configured in `AppTypography.swift`.
- To use a downloaded font, add the `.ttf` or `.otf` files to `KTPLIFE/KTPLIFE`, make sure the `KTPLIFE` target is checked, add the file names under `Fonts provided by application` in `Info.plist`, then replace the PostScript names in `AppFont.regularName`, `mediumName`, `semiboldName`, and `boldName`.
- The font name used in `AppTypography.swift` must be the font's internal PostScript name, not necessarily the file name.
- The app tab bar may still use `.system(...)` for SF Symbol sizing.
