import SwiftUI

struct ContentView: View {
    private static let symbols = ["🍎", "🍋", "🍇", "🍉", "🍒", "🥝", "🍓", "🍊"]
    private static let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 4
    )

    @State private var cards: [MemoryCard]
    @State private var firstSelectedCardID: UUID?
    @State private var isResolvingTurn = false
    @State private var resolutionTask: Task<Void, Never>?
    @State private var moves = 0

    init() {
        _cards = State(initialValue: Self.makeCards())
    }

    private var gameIsComplete: Bool {
        !cards.isEmpty && cards.allSatisfy(\.isMatched)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Memory Game")
                .font(.largeTitle.bold())

            Text("Moves: \(moves)")
                .font(.headline)

            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(cards) { card in
                    if card.isMatched {
                        Color.clear
                            .aspectRatio(2 / 3, contentMode: .fit)
                            .accessibilityHidden(true)
                    } else {
                        Button {
                            selectCard(card.id)
                        } label: {
                            cardView(for: card)
                        }
                        .buttonStyle(.plain)
                        .disabled(isResolvingTurn || card.isFaceUp)
                        .accessibilityLabel(
                            card.isFaceUp
                                ? "Card showing \(card.content)"
                                : "Face-down memory card"
                        )
                    }
                }
            }

            if gameIsComplete {
                Text("You matched them all!")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                    .accessibilityAddTraits(.isHeader)
            }

            Button("New Game") {
                startNewGame()
            }
            .buttonStyle(.borderedProminent)
            .font(.headline)
        }
        .padding()
        .onDisappear {
            resolutionTask?.cancel()
        }
    }

    private func cardView(for card: MemoryCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(card.isFaceUp ? Color.white : Color.blue)

            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: 3)

            Text(card.isFaceUp ? card.content : "?")
                .font(.system(size: 34))
                .fontWeight(card.isFaceUp ? .regular : .bold)
                .foregroundStyle(card.isFaceUp ? Color.primary : Color.white)
        }
        .aspectRatio(2 / 3, contentMode: .fit)
    }

    private func selectCard(_ cardID: UUID) {
        guard !isResolvingTurn,
              let selectedIndex = cards.firstIndex(where: { $0.id == cardID }),
              !cards[selectedIndex].isMatched,
              !cards[selectedIndex].isFaceUp,
              firstSelectedCardID != cardID else {
            return
        }

        cards[selectedIndex].isFaceUp = true

        guard let firstCardID = firstSelectedCardID,
              let firstIndex = cards.firstIndex(where: { $0.id == firstCardID }) else {
            firstSelectedCardID = cardID
            return
        }

        isResolvingTurn = true
        moves += 1

        if cards[firstIndex].content == cards[selectedIndex].content {
            cards[firstIndex].isMatched = true
            cards[selectedIndex].isMatched = true
            firstSelectedCardID = nil
            isResolvingTurn = false
        } else {
            resolveMismatch(firstCardID: firstCardID, secondCardID: cardID)
        }
    }

    private func resolveMismatch(firstCardID: UUID, secondCardID: UUID) {
        resolutionTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(800))
            } catch {
                return
            }

            guard let firstIndex = cards.firstIndex(where: { $0.id == firstCardID }),
                  let secondIndex = cards.firstIndex(where: { $0.id == secondCardID }) else {
                return
            }

            cards[firstIndex].isFaceUp = false
            cards[secondIndex].isFaceUp = false
            firstSelectedCardID = nil
            isResolvingTurn = false
            resolutionTask = nil
        }
    }

    private func startNewGame() {
        resolutionTask?.cancel()
        resolutionTask = nil
        cards = Self.makeCards()
        firstSelectedCardID = nil
        isResolvingTurn = false
        moves = 0
    }

    private static func makeCards() -> [MemoryCard] {
        symbols.prefix(4)
            .flatMap { symbol in
                [MemoryCard(content: symbol), MemoryCard(content: symbol)]
            }
            .shuffled()
    }
}

#Preview {
    ContentView()
}
