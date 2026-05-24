import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await present() }
    }

    private func present() async {
        let url = await extractURL()
        let root = ShareRootView(url: url) { [weak self] in
            self?.finish()
        }
        let host = UIHostingController(rootView: root)
        host.modalPresentationStyle = .formSheet
        host.isModalInPresentation = false
        present(host, animated: true)
    }

    private func extractURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url: URL = await loadItem(from: provider, typeIdentifier: UTType.url.identifier) {
                    return url
                }
            }
            // Fallback: some apps share the URL as plain text.
            for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text: String = await loadItem(from: provider, typeIdentifier: UTType.plainText.identifier),
                   let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return url
                }
            }
        }
        return nil
    }

    private func loadItem<T>(from provider: NSItemProvider, typeIdentifier: String) async -> T? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { value, _ in
                continuation.resume(returning: value as? T)
            }
        }
    }

    fileprivate func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

// MARK: - SwiftUI sheet

private struct ShareRootView: View {
    let url: URL?
    var onDone: () -> Void

    @State private var state: SaveState = .working
    @State private var manualPrefill: ManualPrefill?
    @State private var statusMessage: String = "Saving link…"

    enum SaveState {
        case working
        case saved
        case manual
        case failed
    }

    var body: some View {
        NavigationStack {
            Group {
                if let prefill = manualPrefill {
                    ScrollView {
                        ManualEntryForm(
                            prefill: prefill,
                            onCancel: { onDone() },
                            onSave: { title, desc, tags in
                                await saveManual(prefill: prefill,
                                                 title: title,
                                                 description: desc,
                                                 tagsCSV: tags)
                            }
                        )
                        .padding()
                    }
                } else {
                    statusView
                }
            }
            .navigationTitle("Linkase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDone() }
                }
            }
        }
        .task { await ingest() }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(spacing: 16) {
            switch state {
            case .working:
                ProgressView().controlSize(.large)
                Text(statusMessage).foregroundStyle(.secondary)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Saved").font(.title3)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text(statusMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case .manual:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func makeIngestor() throws -> LinkIngestor {
        let db = try AppDatabase.shared()
        return LinkIngestor(
            repository: LinkRepository(database: db),
            scraper: PageScraper(),
            extractor: MetadataExtractor()
        )
    }

    private func ingest() async {
        guard let url else {
            statusMessage = "No URL found in shared content."
            state = .failed
            return
        }

        let ingestor: LinkIngestor
        do {
            ingestor = try makeIngestor()
        } catch {
            statusMessage = "Couldn't open the Linkase database. \(error.localizedDescription)"
            state = .failed
            return
        }

        do {
            _ = try await ingestor.ingest(rawURL: url.absoluteString)
            state = .saved
            try? await Task.sleep(for: .milliseconds(700))
            onDone()
        } catch LinkIngestor.IngestError.needsManualEntry(let page, _) {
            manualPrefill = ManualPrefill(
                url: page.finalURL,
                host: page.host,
                title: page.ogTitle,
                description: page.ogDescription
            )
            state = .manual
        } catch {
            statusMessage = error.localizedDescription
            state = .failed
        }
    }

    private func saveManual(
        prefill: ManualPrefill,
        title: String,
        description: String,
        tagsCSV: String
    ) async {
        let ingestor: LinkIngestor
        do {
            ingestor = try makeIngestor()
        } catch {
            statusMessage = error.localizedDescription
            state = .failed
            return
        }
        let tags = tagsCSV
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        do {
            _ = try await ingestor.saveManual(
                url: prefill.url,
                host: prefill.host,
                title: title,
                description: description,
                tags: tags
            )
            onDone()
        } catch {
            statusMessage = error.localizedDescription
            state = .failed
        }
    }
}
