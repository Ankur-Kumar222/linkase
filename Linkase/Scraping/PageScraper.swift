import Foundation
import SwiftSoup

struct ScrapedPage: Sendable {
    var url: URL
    var finalURL: URL
    var host: String
    var ogTitle: String
    var ogDescription: String
    var plainText: String
}

struct PageScraper: Sendable {
    enum ScrapeError: Error, LocalizedError {
        case invalidURL
        case notHTML(String?)
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .notHTML(let kind): return "Unsupported content type\(kind.map { ": \($0)" } ?? "")"
            case .emptyContent: return "No readable content found"
            }
        }
    }

    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    func fetch(url: URL) async throws -> ScrapedPage {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        let finalURL = response.url ?? url

        if let http = response as? HTTPURLResponse,
           let contentType = http.value(forHTTPHeaderField: "Content-Type"),
           !contentType.contains("html") {
            throw ScrapeError.notHTML(contentType)
        }

        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw ScrapeError.emptyContent
        }

        let doc = try SwiftSoup.parse(html, finalURL.absoluteString)

        for selector in ["script", "style", "noscript", "nav", "footer", "aside", "header", "form", "iframe"] {
            try doc.select(selector).remove()
        }

        let docTitle = (try? doc.title()) ?? ""
        let ogTitle = (try? doc.select("meta[property=og:title]").attr("content")) ?? ""
        let ogDesc = (try? doc.select("meta[property=og:description]").attr("content")) ?? ""
        let metaDesc = (try? doc.select("meta[name=description]").attr("content")) ?? ""

        let chosenTitle = ogTitle.nonEmpty ?? docTitle.nonEmpty ?? finalURL.absoluteString
        let chosenDesc = ogDesc.nonEmpty ?? metaDesc.nonEmpty ?? ""

        let mainBody: Element? =
            (try? doc.select("article").first())
            ?? (try? doc.select("main").first())
            ?? doc.body()

        var text = (try? mainBody?.text()) ?? ""
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ScrapedPage(
            url: url,
            finalURL: finalURL,
            host: finalURL.host() ?? "",
            ogTitle: chosenTitle,
            ogDescription: chosenDesc,
            plainText: text
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
