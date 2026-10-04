import Foundation

struct MemoryCard: Identifiable, Equatable {
    let id: UUID
    let content: String
    var isFaceUp: Bool
    var isMatched: Bool

    init(
        id: UUID = UUID(),
        content: String,
        isFaceUp: Bool = false,
        isMatched: Bool = false
    ) {
        self.id = id
        self.content = content
        self.isFaceUp = isFaceUp
        self.isMatched = isMatched
    }
}
