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

Current backend routes:

```text
GET /                 Health check
GET /members
GET /members/:id
GET /photos
GET /photos/:id/media
POST /photos
DELETE /photos/:id
GET /albums
POST /albums
GET /ios-homepage-photos
GET /ios-homepage-photos/:id/media
POST /ios-homepage-photos
POST /ios-homepage-photos/register
PUT /ios-homepage-photos/reorder
PUT /ios-homepage-photos/:id
DELETE /ios-homepage-photos/:id
GET /documents/folders
POST /documents/folders
DELETE /documents/folders/:id
GET /documents
GET /documents/:id/download
GET /documents/:id/preview
POST /documents
DELETE /documents/:id
GET /events
GET /events/:id
POST /events
PUT /events/:id
DELETE /events/:id
POST /users/sync
GET /users/me
PUT /users/me/profile
DELETE /users/me
PUT /users/me/profile-picture
GET /users/:id/profile-picture/media
GET /users/blocked
POST /users/:id/block
DELETE /users/:id/block
GET /admin/users
POST /webhooks/authentik
GET /messages/conversations
GET /messages/conversations/:userId
PUT /messages/conversations/:userId/read
POST /messages
GET /announcements
POST /announcements
DELETE /announcements/:id
GET /group-chats
POST /group-chats
DELETE /group-chats/:id
GET /group-chats/:id/messages
POST /group-chats/:id/messages
PUT /group-chats/:id/read
GET /group-chats/:id/members
POST /group-chats/:id/members
DELETE /group-chats/:id/members/:userId
POST /reports
GET /reports
PUT /reports/:id/status
```

Routes guarded by the backend auth middleware require:

```text
Authorization: Bearer <access_token>
```

The Swift member model accepts production member groups: `active`, `pledge`, `eboard`, `chair`, and `alumni`.

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
