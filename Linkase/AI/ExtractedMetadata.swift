import Foundation
import FoundationModels

@Generable
struct ExtractedMetadata: Equatable, Sendable {
    @Guide(description: "Concise, human-readable page title. Max ~80 characters. No site name suffix.")
    var title: String

    @Guide(description: "A neutral 1–2 sentence summary of what the page is about.")
    var summary: String

    @Guide(description: "3 to 6 lowercase topical tags. Single words or hyphenated phrases. No '#'. No spaces inside a tag.")
    var tags: [String]
}
