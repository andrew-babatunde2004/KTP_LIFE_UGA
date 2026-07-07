# KTP_LIFE_UGA

Native iOS app for the UGA Kappa Theta Pi chapter. The app talks to the production KTP API at `https://api2.ugaktp.com` by default. This repo contains the SwiftUI client only; the API is maintained outside this project.

## Getting started

### Prerequisites

- Xcode (open `KTPLIFE/KTPLIFE.xcodeproj`)
- The KTP backend at `https://api2.ugaktp.com`
- An Authentik access token for protected routes such as `/members`

### Configure the API URL

1. Copy the secrets template (once per machine):
   ```sh
   cd KTPLIFE/KTPLIFE
   cp Secrets.example.plist Secrets.plist
   ```
2. Edit `Secrets.plist` and set `API_BASE_URL` if you need to override production:
   - **Production:** `https://api2.ugaktp.com`
   - **Internal server/LXC network:** `http://10.0.0.53:4000`
3. Optional for temporary local testing: set `API_ACCESS_TOKEN` to a valid Authentik access token. This is only a development bridge until the iOS Authentik login flow stores the token in the app.

`Secrets.plist` is gitignored. `Secrets.example.plist` is the committed template.

### Run the app

1. Open `KTPLIFE/KTPLIFE.xcodeproj` and run on the **Simulator** or a device.
2. Sign in (auth is still in progress) and use the tab bar to navigate.
3. **Messages → Directory** loads members from protected `GET /members` when a valid Authentik access token is available.

### Key files

| File | Role |
|------|------|
| `KTPLIFE/KTPLIFE/Secrets.example.plist` | Committed template for `API_BASE_URL` and optional dev `API_ACCESS_TOKEN` |
| `KTPLIFE/KTPLIFE/Secrets.plist` | Local API override/token file (gitignored; copy from example) |
| `KTPLIFE/KTPServices/APIConfig.swift` | Loads API config from Secrets plist |
| `KTPLIFE/KTPServices/MemberAPIService.swift` | Fetches protected `/members` with a Bearer token |
| `KTPLIFE/KTPServices/PhotoService.swift` | Fetches `/photos` |
| `KTPLIFE/KTPServices/CalendarNetwork.swift` | Fetches `/events` |
| `KTPLIFE/KTPModels/DirectoryMember.swift` | Swift model matching member JSON |
| `KTPLIFE/KTPLIFE/MessagesView.swift` | Messages tab + directory routing |

### API contract

Public endpoints:

```text
GET /                 Health check
GET /events           Public events
GET /events/:id       Single public event
GET /photos           Public photo metadata
```

Protected endpoints require:

```text
Authorization: Bearer <access_token>
```

The directory uses:

```text
GET /members
GET /members?group=active
GET /members/:id
```

The Swift member model accepts production member groups: `active`, `pledge`, `eboard`, `chair`, and `alumni`.

### Troubleshooting

**Directory shows “Sign in with Authentik”** — `/members` is protected. Wire the real Authentik login flow or temporarily set `API_ACCESS_TOKEN` in local `Secrets.plist`.

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
