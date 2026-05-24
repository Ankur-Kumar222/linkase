import Foundation
import FoundationModels

struct MetadataExtractor: Sendable {
    enum ExtractorError: Error, LocalizedError {
        case aiUnavailable(SystemLanguageModel.Availability.UnavailableReason?)
        case modelFailed(String)

        var errorDescription: String? {
            switch self {
            case .aiUnavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "This device doesn't support Apple Intelligence."
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence is not enabled in System Settings."
                case .modelNotReady:
                    return "Apple Intelligence is still downloading. Try again shortly."
                case .none:
                    return "Apple Intelligence is unavailable."
                @unknown default:
                    return "Apple Intelligence is unavailable."
                }
            case .modelFailed(let message):
                return message
            }
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var unavailableReason: SystemLanguageModel.Availability.UnavailableReason? {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            return reason
        }
        return nil
    }

    func extract(from page: ScrapedPage) async throws -> ExtractedMetadata {
        guard Self.isAvailable else {
            throw ExtractorError.aiUnavailable(Self.unavailableReason)
        }

        let truncated = String(page.plainText.prefix(7000))
        let instructions = """
        You are a meticulous librarian. Given the text of a web page, produce a clean title, \
        a short neutral summary, and 3–6 lowercase topical tags. Tags should be single words \
        or hyphenated phrases — never contain spaces, hashes, or punctuation other than '-'.
        """

        let prompt = """
        URL: \(page.finalURL.absoluteString)
        Host: \(page.host)
        Page <title>: \(page.ogTitle)
        Meta description: \(page.ogDescription)

        Page text:
        \(truncated)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: ExtractedMetadata.self)
            return response.content
        } catch {
            throw ExtractorError.modelFailed(error.localizedDescription)
        }
    }
}
