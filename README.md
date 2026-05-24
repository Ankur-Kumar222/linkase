# Linkase

A native bookmarks app for iOS and macOS that turns any URL you paste into a clean, tagged, searchable entry — entirely on-device. No backend, no cloud sync, no API keys.

## How it works

1. You paste a URL (or share one into the app from Safari).
2. Linkase fetches the page, parses the HTML with SwiftSoup, and strips out scripts, nav, footers, and other noise.
3. The cleaned text is handed to Apple's on-device **Foundation Models** framework (Apple Intelligence), which returns a structured `(title, summary, tags)` via a `@Generable` Swift type.
4. The result is saved into a local SQLite database via GRDB, with an FTS5 mirror that powers full-text search across every saved link.

If Apple Intelligence is unavailable (older device, AI disabled, model still downloading, unsupported language detected), Linkase falls back to a manual-entry form pre-filled from the page's scraped title and meta description.

## Tech stack

- **SwiftUI** — Multiplatform target (iOS / macOS / visionOS, deployment 26.0)
- **GRDB.swift** — SQLite with FTS5 full-text search and `ValueObservation`
- **SwiftSoup** — HTML scraping and parsing
- **FoundationModels** — on-device LLM for metadata extraction (`@Generable` structured output)
- **Swift Concurrency** — `async/await` throughout, `@Observable` view models
- **MVVM** — feature-folder layout (`Features/<Name>/{View, ViewModel}`)

## Features

- Paste a URL → AI-generated title, summary, and tags, saved to a local DB.
- `NavigationSplitView` with a tag-filter sidebar, a searchable link list, and a detail/edit view.
- FTS5-powered search across title, description, and URL.
- iOS **Share Extension** so any app's share sheet can save into Linkase.
- App Group container so the main app and extension share one SQLite file.
- Manual-entry fallback when on-device AI isn't available.
- URL normalization (drops `utm_*`, `fbclid`, fragments).

## Project layout

```
Linkase/
├── App/                  # @main, RootView, AppContainer (DI)
├── Shared/AppGroup.swift # Shared SQLite container URL
├── Models/               # Link, Tag, LinkTag, TagWithCount (GRDB records)
├── Database/             # AppDatabase, Migrations, LinkRepository
├── Scraping/             # PageScraper (URLSession + SwiftSoup)
├── AI/                   # MetadataExtractor + @Generable ExtractedMetadata
├── Ingestion/            # LinkIngestor (URL normalize -> scrape -> AI -> save)
└── Features/
    ├── AddLink/          # Paste bar + manual-entry form
    ├── LinkList/         # Searchable list + view model
    ├── LinkDetail/       # Edit/delete/open
    └── Sidebar/          # Tag filter sidebar

LinkaseShareExtension/    # iOS share extension target
```

## Running it

Requirements:
- Xcode 26
- For full AI behavior on macOS: Apple Silicon Mac with Apple Intelligence enabled in System Settings.
- For full AI behavior on iOS: iPhone 15 Pro / 16+ on iOS 26 with Apple Intelligence enabled.

```sh
git clone https://github.com/Ankur-Kumar222/linkase.git
cd linkase
open Linkase.xcodeproj
```

Pick the **Linkase** scheme + your destination (`My Mac` or an iOS device/simulator) and ⌘R.

> Note: Apple Intelligence is not available in the iOS simulator. Every save in the simulator will route through the manual-entry form — that's the expected fallback path.

For Xcode-side setup details (App Group capability, share extension target membership, etc.), see [SETUP.md](SETUP.md).

## Status

Single-developer side project, currently:

- ✅ End-to-end working on macOS with Apple Intelligence
- ✅ Share Extension target wired and compiling for iOS
- 🚧 Polish: favicons, empty states, toasts, language-detection fallback

## License

Personal project — no license declared yet.
