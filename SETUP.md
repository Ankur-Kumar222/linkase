# Linkase setup — manual Xcode steps

Most of the app builds and runs out of the box (the `Linkase` group is a `PBXFileSystemSynchronizedRootGroup`, so any source file added under `Linkase/` is picked up automatically). The items below **require Xcode UI changes** that can't be made from source.

## 1. App Group capability (required for share extension + multi-process DB)

In Xcode, with the `Linkase` target selected:

1. Signing & Capabilities → **+ Capability** → **App Groups**.
2. Add group: `group.com.AnkurKumar.Linkase`.

This must match the `AppGroup.identifier` constant in `Linkase/Shared/AppGroup.swift`. Until you add it, the DB falls back to `~/Library/Application Support/Linkase/Linkase.sqlite` on macOS (sandboxed container) — the app still runs, but the share extension won't see the same database.

## 2. Foundation Models framework

`FoundationModels` is a system framework — it should link automatically via the `import FoundationModels` statements. If you get a linker error, add it to the target's **Frameworks, Libraries, and Embedded Content** list (status: *Do Not Embed*).

## 3. Share Extension target (iOS)

Not wired yet — needs a target add in Xcode:

1. File → New → Target → **Share Extension** (name: `LinkaseShareExtension`).
2. Enable the same App Group on the new target.
3. Activation rule in `Info.plist`:
   ```xml
   <key>NSExtensionAttributes</key>
   <dict>
     <key>NSExtensionActivationRule</key>
     <dict>
       <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
       <integer>1</integer>
     </dict>
   </dict>
   ```
4. Make these source files members of **both** the app and the share-extension target (target membership inspector in Xcode):
   - `Linkase/Shared/AppGroup.swift`
   - `Linkase/Models/*.swift`
   - `Linkase/Database/*.swift`
   - `Linkase/Scraping/PageScraper.swift`
   - `Linkase/AI/*.swift`
   - `Linkase/Ingestion/LinkIngestor.swift`
5. Replace the share extension's default view with a tiny SwiftUI sheet that extracts the URL from `NSExtensionContext.inputItems`, calls `LinkIngestor.ingest(rawURL:)`, and dismisses. If it throws `aiUnavailable`, present the same manual-entry form used in the main app.

## 4. Apple Intelligence testing

- **macOS**: Apple Silicon Mac, System Settings → Apple Intelligence & Siri → enable.
- **iOS**: iPhone 15 Pro / 16+ on iOS 26, Apple Intelligence enabled in Settings.
- To test the **manual-entry fallback** without disabling AI, you can temporarily flip `MetadataExtractor.isAvailable` to `false` in `Linkase/AI/MetadataExtractor.swift`.

## 5. Build & run

```sh
xcodebuild -scheme Linkase -destination 'platform=macOS,arch=arm64' build
# or open the project in Xcode and ⌘R
```

## What works today

- Paste URL → scrape → AI metadata → save → search (FTS5) → tag filter sidebar → detail view with edit/delete.
- Manual-entry fallback when Apple Intelligence is unavailable (form pre-filled from scrape).
- Multi-process-safe DB via GRDB DatabasePool (ready for the share extension once the target is added).
