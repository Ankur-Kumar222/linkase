import Foundation

struct LinkIngestor: Sendable {
    let repository: LinkRepository
    let scraper: PageScraper
    let extractor: MetadataExtractor

    enum IngestError: Error, LocalizedError {
        case invalidURL
        case aiUnavailable(ScrapedPage, MetadataExtractor.ExtractorError)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "That doesn't look like a valid URL."
            case .aiUnavailable(_, let inner): return inner.errorDescription
            }
        }
    }

    /// Full automated path: scrape + AI extract + save.
    @discardableResult
    func ingest(rawURL: String) async throws -> LinkWithTags {
        guard let url = Self.normalize(rawURL: rawURL) else {
            throw IngestError.invalidURL
        }

        let page = try await scraper.fetch(url: url)
        let metadata: ExtractedMetadata
        do {
            metadata = try await extractor.extract(from: page)
        } catch let error as MetadataExtractor.ExtractorError {
            if case .aiUnavailable = error {
                throw IngestError.aiUnavailable(page, error)
            }
            throw error
        }

        let link = Link(
            id: nil,
            url: page.finalURL.absoluteString,
            title: metadata.title.isEmpty ? page.ogTitle : metadata.title,
            description: metadata.summary,
            host: page.host,
            createdAt: Date(),
            aiGenerated: true
        )

        let saved = try await repository.upsert(link: link, tagNames: metadata.tags)
        return LinkWithTags(link: saved, tags: metadata.tags.map { Tag(id: nil, name: $0.lowercased()) })
    }

    /// Manual path: caller provides the metadata (used when AI is unavailable or for editing).
    @discardableResult
    func saveManual(
        url: URL,
        host: String,
        title: String,
        description: String,
        tags: [String]
    ) async throws -> Link {
        let link = Link(
            id: nil,
            url: url.absoluteString,
            title: title,
            description: description,
            host: host,
            createdAt: Date(),
            aiGenerated: false
        )
        return try await repository.upsert(link: link, tagNames: tags)
    }

    /// Just scrape — used to pre-fill the manual form when AI is unavailable.
    func scrape(rawURL: String) async throws -> ScrapedPage {
        guard let url = Self.normalize(rawURL: rawURL) else { throw IngestError.invalidURL }
        return try await scraper.fetch(url: url)
    }

    // MARK: - URL normalization

    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "gclid", "fbclid", "mc_cid", "mc_eid", "ref", "ref_src"
    ]

    static func normalize(rawURL: String) -> URL? {
        var trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }

        guard var components = URLComponents(string: trimmed) else { return nil }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        if let items = components.queryItems {
            let cleaned = items.filter { !trackingParams.contains($0.name.lowercased()) }
            components.queryItems = cleaned.isEmpty ? nil : cleaned
        }
        return components.url
    }
}
