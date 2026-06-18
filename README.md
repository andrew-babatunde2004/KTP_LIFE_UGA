# KTP_LIFE_UGA

## UI Conventions

- New cards, filters, headers, buttons, and page controls should use matte surfaces that visually match the current page background.
- Do not add glass styling to new elements unless it is explicitly requested.
- Exception: the bottom app tab bar is allowed to remain glass.
- When adding a new page, create a separate `...View.swift`, add the case to `AppTab`, route it in `ContentView`, and keep page-specific UI inside that page file.
- App backgrounds should be solid colors, not gradients.
- Change the default blue background in `KTPLIFE/KTPLIFE/AppTab.swift` at `PageTheme.defaultBlue`.
- Change the Opportunities background in `KTPLIFE/KTPLIFE/AppTab.swift` at `PageTheme.opportunities`.
