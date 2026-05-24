import Foundation

@MainActor
@Observable
final class AddLinkViewModel {
    enum Phase: Equatable {
        case idle
        case working
        case manualEntry(prefill: ManualPrefill)
        case error(String)
    }

    var input: String = ""
    var phase: Phase = .idle

    let ingestor: LinkIngestor
    init(ingestor: LinkIngestor) { self.ingestor = ingestor }

    func submit() async {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        phase = .working
        do {
            _ = try await ingestor.ingest(rawURL: raw)
            input = ""
            phase = .idle
        } catch LinkIngestor.IngestError.aiUnavailable(let page, _) {
            phase = .manualEntry(prefill: ManualPrefill(
                url: page.finalURL,
                host: page.host,
                title: page.ogTitle,
                description: page.ogDescription
            ))
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func saveManual(title: String, description: String, tagsCSV: String) async {
        guard case .manualEntry(let prefill) = phase else { return }
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
            input = ""
            phase = .idle
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func cancelManual() {
        phase = .idle
    }
}
