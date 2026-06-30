# KTP_LIFE_UGA

Native iOS app for the UGA Kappa Theta Pi chapter. The app talks to a separate backend over HTTP — configure the base URL in `Secrets.plist` (see below). This repo contains the SwiftUI client only; the API is maintained outside this project.

## Getting started

### Prerequisites

- Xcode (open `KTPLIFE/KTPLIFE.xcodeproj`)
- A running KTP backend that exposes the endpoints listed below

### Configure the API URL

1. Copy the secrets template (once per machine):
   ```powershell
   cd KTPLIFE/KTPLIFE
   copy Secrets.example.plist Secrets.plist
   ```
2. Edit `Secrets.plist` and set `API_BASE_URL` to your backend:
   - **Simulator (API on same Mac):** `http://127.0.0.1:3000/`
   - **Physical iPhone:** your server or Mac LAN IP, e.g. `http://192.168.1.10:3000/`
   - **Hosted backend:** your deployed URL, e.g. `https://api.example.com/`

`Secrets.plist` is gitignored. `Secrets.example.plist` is the committed template.

### Run the app

1. Open `KTPLIFE/KTPLIFE.xcodeproj` and run on the **Simulator** or a device.
2. Sign in (auth is still in progress) and use the tab bar to navigate.
3. **Messages → Directory** loads members from `GET /members` when the backend is reachable.

### Key files

| File | Role |
|------|------|
| `KTPLIFE/KTPLIFE/Secrets.example.plist` | Committed template for `API_BASE_URL` |
| `KTPLIFE/KTPLIFE/Secrets.plist` | Local API URL (gitignored; copy from example) |
| `KTPLIFE/KTPServices/APIConfig.swift` | Loads `API_BASE_URL` from Secrets plist |
| `KTPLIFE/KTPServices/MemberAPIService.swift` | Fetches `/members` |
| `KTPLIFE/KTPServices/PhotoService.swift` | Fetches `/photos` |
| `KTPLIFE/KTPServices/CalendarNetwork.swift` | Fetches `/events` |
| `KTPLIFE/KTPModels/DirectoryMember.swift` | Swift model matching member JSON |
| `KTPLIFE/KTPLIFE/MessagesView.swift` | Messages tab + directory routing |

### API contract (`GET /members`)

The directory expects an array of objects shaped like:

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

Other tabs use `GET /events`, `GET /photos`, and (planned) `GET /messages` against the same `API_BASE_URL`.

### Troubleshooting

**Directory or other tabs show a load error** — confirm `API_BASE_URL` in `Secrets.plist` is correct, the backend is running, and the device can reach that host (Simulator vs physical device use different URLs).

**Physical device cannot connect** — `127.0.0.1` only works on the Simulator. Use your Mac’s LAN IP or a hosted API URL on a real iPhone.

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
