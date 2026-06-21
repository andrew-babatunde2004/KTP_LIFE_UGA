# KTP_LIFE_UGA

## Backend and iOS API connection

The member directory in the Messages tab loads live data from the Node API in `ktp-api`.

### Run the stack locally

1. **PostgreSQL** — database `ktp_life` with user `ktp_user` (see pgAdmin setup).
2. **API env** — copy `ktp-api/.env.example` to `ktp-api/.env` and adjust credentials if needed.
3. **Install and seed**:
   ```powershell
   cd ktp-api
   npm install
   npm run db:init
   ```
4. **Start the API**:
   ```powershell
   npm start
   ```
   Server runs at `http://localhost:3000`. Verify with:
   ```powershell
   curl.exe http://localhost:3000/members
   ```

### Run the iOS app against the API

1. Keep `npm start` running in `ktp-api`.
2. Open `KTPLIFE/KTPLIFE.xcodeproj` and run on the **Simulator**.
3. In the app, go to **Messages → Directory**. Members load from `GET /members`.

### Key files

| File | Role |
|------|------|
| `ktp-api/models/memberModel.js` | Postgres queries; maps rows to JSON |
| `KTPLIFE/KTPServices/MemberAPIService.swift` | Fetches `/members` |
| `KTPLIFE/KTPModels/DirectoryMember.swift` | Swift model matching API JSON |
| `KTPLIFE/KTPLIFE/MessagesView.swift` | Directory UI; calls `KTPAPIService` |

### JSON contract (`GET /members`)

```json
{
  "id": "1",
  "name": "Andrew Babatunde",
  "role": "Computer Science",
  "year": "2027",
  "group": "activeMembers"
}
```

`group` must be one of: `activeMembers`, `pledges`, `eBoard`, `alumni`.

### Troubleshooting

**Port 3000 already in use** (when starting the API):
```powershell
netstat -ano | findstr :3000
taskkill /PID <PID_FROM_ABOVE> /F
```

**Directory shows an error in the app** — confirm Postgres is running, `npm start` is active, and `curl.exe http://localhost:3000/members` returns JSON.

**Physical device testing** — the Simulator uses `127.0.0.1`. On a real iPhone, update the base URL in `KTPAPIService` to your Mac's LAN IP (for example `http://192.168.1.10:3000/`).

## UI Conventions

- New cards, filters, headers, buttons, and page controls should use matte surfaces that visually match the current page background.
- Do not add glass styling to new elements unless it is explicitly requested.
- Exception: the bottom app tab bar is allowed to remain glass.
- When adding a new page, create a separate `...View.swift`, add the case to `AppTab`, route it in `ContentView`, and keep page-specific UI inside that page file.
- App backgrounds should be solid colors, not gradients.
- Change the default blue background in `KTPLIFE/KTPLIFE/AppTab.swift` at `PageTheme.defaultBlue`.
- Change the Opportunities background in `KTPLIFE/KTPLIFE/AppTab.swift` at `PageTheme.opportunities`.
- When creating new elements or pages, unless specified do not add any emojis or icons, if it is an image file being used leave it be. The design should be clean and simple, relying on typography and layout rather than decorative elements.
- The KTP logo is an allowed brand image on Home, Sign Up, and Authentication screens. Use `KTPLogoMark` from `KTPLIFE/KTPLIFE/SharedViews.swift` instead of duplicating logo image code.
- Make sure when adding new pages or elements that proper documentation is being used as your context alone does not help others who are working on the project
- Make sure that all new pages or elements are tested in both light and dark mode. Test on multiple devices and screen sizes to ensure a consistent experience across devices.

## Typography

- App text should use `AppFont` from `KTPLIFE/KTPLIFE/AppTypography.swift`, not direct `.system(...)` font calls.
- The current app font is Avenir Next, configured in `AppTypography.swift`.
- To use a downloaded font, add the `.ttf` or `.otf` files to `KTPLIFE/KTPLIFE`, make sure the `KTPLIFE` target is checked, add the file names under `Fonts provided by application` in `Info.plist`, then replace the PostScript names in `AppFont.regularName`, `mediumName`, `semiboldName`, and `boldName`.
- The font name used in `AppTypography.swift` must be the font's internal PostScript name, not necessarily the file name.
- The app tab bar may still use `.system(...)` for SF Symbol sizing.
