import SwiftUI
import UIKit

struct ContentView: View {
    private static let pairCountOptions = [2, 4, 6, 8]
    private static let defaultNumberOfPairs = 4

    @AppStorage("bestMoves2") private var bestMoves2 = 0
    @AppStorage("bestMoves4") private var bestMoves4 = 0
    @AppStorage("bestMoves6") private var bestMoves6 = 0
    @AppStorage("bestMoves8") private var bestMoves8 = 0
    @State private var cards: [MemoryCard]
    @State private var firstSelectedCardID: UUID?
    @State private var isResolvingTurn = false
    @State private var resolutionTask: Task<Void, Never>?
    @State private var moves = 0
    @State private var numberOfPairs = Self.defaultNumberOfPairs
    @State private var selectedTheme = GameTheme.fruit
    @State private var elapsedSeconds = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var hasGameStarted = false
    @State private var achievedNewBest = false
    @State private var isShowingNewGameConfirmation = false

    init() {
        _cards = State(
            initialValue: Self.makeCards(
                numberOfPairs: Self.defaultNumberOfPairs,
                theme: .fruit
            )
        )
    }

    private var columns: [GridItem] {
        let columnCount = switch numberOfPairs {
        case 2: 2
        case 6: 3
        default: 4
        }

        return Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: columnCount
        )
    }

    private var matchedPairs: Int {
        cards.filter(\.isMatched).count / 2
    }

    private var gameIsComplete: Bool {
        !cards.isEmpty && matchedPairs == numberOfPairs
    }

    private var currentBestMoves: Int {
        switch numberOfPairs {
        case 2: bestMoves2
        case 4: bestMoves4
        case 6: bestMoves6
        case 8: bestMoves8
        default: 0
        }
    }

    private var formattedElapsedTime: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private var timerAccessibilityLabel: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return "Elapsed time \(minutes) minutes \(seconds) seconds"
    }

    private var hasMeaningfulProgress: Bool {
        moves > 0 || firstSelectedCardID != nil || matchedPairs > 0 || hasGameStarted
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Memory Game")
                .font(.largeTitle.bold())

            Picker("Game Size", selection: $numberOfPairs) {
                ForEach(Self.pairCountOptions, id: \.self) { pairCount in
                    Text("\(pairCount) Pairs")
                        .tag(pairCount)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Game Size")
            .onChange(of: numberOfPairs) {
                startNewGame()
            }

            Picker("Theme", selection: $selectedTheme) {
                ForEach(GameTheme.allCases) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Card theme")
            .onChange(of: selectedTheme) {
                startNewGame()
            }

            VStack(spacing: 8) {
                HStack {
                    Text("Moves: \(moves)")
                        .accessibilityLabel("Moves \(moves)")

                    Spacer()

                    Text("Pairs: \(matchedPairs)/\(numberOfPairs)")
                        .accessibilityLabel("\(matchedPairs) of \(numberOfPairs) pairs matched")
                }

                HStack {
                    Text("Time: \(formattedElapsedTime)")
                        .accessibilityLabel(timerAccessibilityLabel)

                    Spacer()

                    Text(currentBestMoves == 0 ? "Best: —" : "Best: \(currentBestMoves) moves")
                        .accessibilityLabel(
                            currentBestMoves == 0
                                ? "No best score yet"
                                : "Best score \(currentBestMoves) moves"
                        )
                }
            }
            .font(.headline)

            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: columns, spacing: 10) {
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
                        VStack(spacing: 6) {
                            Text("You matched them all!")
                                .font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)

                            Text("\(moves) moves in \(formattedElapsedTime)")

                            if achievedNewBest {
                                Text("New Best!")
                                    .font(.headline.bold())
                            }
                        }
                        .foregroundStyle(.green)
                        .accessibilityElement(children: .combine)
                    }

                    Button("New Game") {
                        requestNewGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
                    .accessibilityLabel("Start a new shuffled game")
                }
            }
        }
        .padding()
        .onDisappear {
            resolutionTask?.cancel()
            timerTask?.cancel()
        }
        .confirmationDialog(
            "Start a new game?",
            isPresented: $isShowingNewGameConfirmation,
            titleVisibility: .visible
        ) {
            Button("New Game", role: .destructive) {
                HapticFeedback.newGame()
                startNewGame()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
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

        startTimerIfNeeded()
        HapticFeedback.cardFlip()
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

            if gameIsComplete {
                finishGame()
            } else {
                HapticFeedback.match()
            }
        } else {
            HapticFeedback.mismatch()
            resolveMismatch(firstCardID: firstCardID, secondCardID: cardID)
        }
    }

    private func startTimerIfNeeded() {
        guard !hasGameStarted else { return }

        hasGameStarted = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                elapsedSeconds += 1
            }
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

    private func requestNewGame() {
        if hasMeaningfulProgress {
            isShowingNewGameConfirmation = true
        } else {
            HapticFeedback.newGame()
            startNewGame()
        }
    }

    private func startNewGame() {
        resolutionTask?.cancel()
        resolutionTask = nil
        timerTask?.cancel()
        timerTask = nil
        cards = Self.makeCards(numberOfPairs: numberOfPairs, theme: selectedTheme)
        firstSelectedCardID = nil
        isResolvingTurn = false
        moves = 0
        elapsedSeconds = 0
        hasGameStarted = false
        achievedNewBest = false
        isShowingNewGameConfirmation = false
    }

    private func finishGame() {
        timerTask?.cancel()
        timerTask = nil

        if currentBestMoves == 0 || moves < currentBestMoves {
            setCurrentBestMoves(moves)
            achievedNewBest = true
        } else {
            achievedNewBest = false
        }

        HapticFeedback.win()
    }

    private func setCurrentBestMoves(_ score: Int) {
        switch numberOfPairs {
        case 2: bestMoves2 = score
        case 4: bestMoves4 = score
        case 6: bestMoves6 = score
        case 8: bestMoves8 = score
        default: break
        }
    }

    private static func makeCards(numberOfPairs: Int, theme: GameTheme) -> [MemoryCard] {
        theme.symbols.shuffled()
            .prefix(numberOfPairs)
            .flatMap { symbol in
                [MemoryCard(content: symbol), MemoryCard(content: symbol)]
            }
            .shuffled()
    }
}

private enum HapticFeedback {
    static func cardFlip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func match() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func mismatch() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func newGame() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

#Preview {
    ContentView()
}
