import Foundation
import GRDB

@MainActor
@Observable
final class LinkListViewModel {
    var links: [LinkWithTags] = []
    var search: String = ""
    var selection: SidebarSelection? = .all

    private var observationTask: Task<Void, Never>?
    let repository: LinkRepository

    init(repository: LinkRepository) {
        self.repository = repository
    }

    func startObserving() {
        observationTask?.cancel()
        let tagId: Int64? = {
            if case .tag(let t) = selection { return t.id }
            return nil
        }()
        let q = search
        let repo = repository
        observationTask = Task { [weak self] in
            do {
                for try await rows in repo.linksObservation(search: q, tagId: tagId)
                    .values(in: repo.database.writer) {
                    self?.links = rows
                }
            } catch {
                self?.links = []
            }
        }
    }

    func delete(_ link: LinkWithTags) async {
        guard let id = link.link.id else { return }
        try? await repository.delete(linkId: id)
    }
}
