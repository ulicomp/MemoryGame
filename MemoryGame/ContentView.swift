import SwiftUI
import UIKit

struct ContentView: View {
    private static let pairCountOptions = [2, 4, 6, 8]
    private static let defaultNumberOfPairs = 4
    private static let statColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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

    private var cardSymbolSize: CGFloat {
        switch numberOfPairs {
        case 2: 54
        case 6: 42
        default: 36
        }
    }

    var body: some View {
        ZStack {
            ThemeBackground(theme: selectedTheme)

            ScrollView {
                VStack(spacing: 18) {
                    headerView
                    controlsView
                    statsView
                    boardView

                    if gameIsComplete {
                        completionView
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                    }

                    resetButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.48, dampingFraction: 0.78), value: gameIsComplete)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.light)
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

    private var headerView: some View {
        VStack(spacing: 5) {
            Text(selectedTheme.displayTitle)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [selectedTheme.secondaryColor, selectedTheme.primaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(selectedTheme.subtitle)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color(red: 0.35, green: 0.32, blue: 0.27))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var controlsView: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Game Size", selection: $numberOfPairs) {
                    ForEach(Self.pairCountOptions, id: \.self) { pairCount in
                        Text("\(pairCount) Pairs")
                            .tag(pairCount)
                    }
                }
            } label: {
                controlLabel(
                    icon: "square.grid.2x2.fill",
                    title: "Size",
                    value: "\(numberOfPairs) Pairs",
                    color: selectedTheme.primaryColor
                )
            }
            .accessibilityLabel("Game size, \(numberOfPairs) pairs")
            .onChange(of: numberOfPairs) {
                startNewGame()
            }
            .frame(maxWidth: .infinity)

            Menu {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(GameTheme.allCases) { theme in
                        Text(theme.displayName)
                            .tag(theme)
                    }
                }
            } label: {
                controlLabel(
                    icon: "paintpalette.fill",
                    title: "Theme",
                    value: selectedTheme.displayName,
                    color: selectedTheme.secondaryColor
                )
            }
            .accessibilityLabel("Card theme, \(selectedTheme.displayName)")
            .onChange(of: selectedTheme) {
                startNewGame()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func controlLabel(
        icon: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.23, blue: 0.20))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Image(systemName: "chevron.down")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.10), radius: 8, y: 4)
    }

    private var statsView: some View {
        LazyVGrid(columns: Self.statColumns, spacing: 12) {
            statCard(
                title: "Moves",
                value: "\(moves)",
                icon: "hand.tap.fill",
                color: selectedTheme.secondaryColor,
                accessibilityLabel: "Moves \(moves)"
            )

            statCard(
                title: "Pairs",
                value: "\(matchedPairs)/\(numberOfPairs)",
                icon: "star.fill",
                color: selectedTheme.primaryColor,
                accessibilityLabel: "\(matchedPairs) of \(numberOfPairs) pairs matched"
            )

            statCard(
                title: "Time",
                value: formattedElapsedTime,
                icon: "clock.fill",
                color: selectedTheme.primaryColor,
                accessibilityLabel: timerAccessibilityLabel
            )

            statCard(
                title: "Best",
                value: currentBestMoves == 0 ? "—" : "\(currentBestMoves)",
                icon: "trophy.fill",
                color: selectedTheme.accentColor,
                accessibilityLabel: currentBestMoves == 0
                    ? "No best score yet"
                    : "Best score \(currentBestMoves) moves"
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        icon: String,
        color: Color,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.17))
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.10), radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var boardView: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Match the pairs", systemImage: selectedTheme.cardBackSymbol)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(selectedTheme.primaryColor)

                Spacer()

                Text("\(cards.count) cards")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

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
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .scale(scale: 0.82).combined(with: .opacity)
                            )
                        )
                    }
                }
            }
            .animation(.spring(response: 0.36, dampingFraction: 0.72), value: matchedPairs)
        }
        .padding(12)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: selectedTheme.primaryColor.opacity(0.09), radius: 14, y: 7)
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(selectedTheme.accentColor)
                .frame(width: 58, height: 58)
                .background(selectedTheme.accentColor.opacity(0.14), in: Circle())

            Text("You matched them all!")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(selectedTheme.primaryColor)
                .accessibilityAddTraits(.isHeader)

            Text("\(moves) moves  •  \(formattedElapsedTime)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            if achievedNewBest {
                Label("New Best!", systemImage: "trophy.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.31, blue: 0.04))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedTheme.accentColor.opacity(0.30), in: Capsule())
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(selectedTheme.accentColor.opacity(0.35), lineWidth: 1.5)
        }
        .shadow(color: selectedTheme.accentColor.opacity(0.18), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
    }

    private var resetButton: some View {
        Button {
            requestNewGame()
        } label: {
            Label("Reset Game", systemImage: "arrow.clockwise")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [selectedTheme.primaryColor, selectedTheme.cardBackTopColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: selectedTheme.primaryColor.opacity(0.26), radius: 10, y: 6)
        .accessibilityLabel("Start a new shuffled game")
    }

    private func cardView(for card: MemoryCard) -> some View {
        ZStack {
            cardBack
                .opacity(card.isFaceUp ? 0 : 1)
                .rotation3DEffect(
                    .degrees(card.isFaceUp ? 90 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.55
                )

            cardFront(for: card)
                .opacity(card.isFaceUp ? 1 : 0)
                .rotation3DEffect(
                    .degrees(card.isFaceUp ? 0 : -90),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.55
                )
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .animation(.easeInOut(duration: 0.32), value: card.isFaceUp)
    }

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    LinearGradient(
                        colors: [selectedTheme.cardBackTopColor, selectedTheme.cardBackBottomColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 68, height: 68)
                .offset(x: -30, y: -42)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 8)
                .frame(width: 82, height: 82)
                .offset(x: 34, y: 46)

            Image(systemName: selectedTheme.cardBackSymbol)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(.white.opacity(0.42), lineWidth: 1.5)
        }
        .shadow(color: selectedTheme.primaryColor.opacity(0.22), radius: 6, y: 4)
    }

    private func cardFront(for card: MemoryCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(red: 1.0, green: 0.985, blue: 0.93))

            Circle()
                .fill(selectedTheme.accentColor.opacity(0.12))
                .padding(9)

            Text(card.content)
                .font(.system(size: cardSymbolSize))
                .minimumScaleFactor(0.72)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    isResolvingTurn
                        ? Color(red: 0.88, green: 0.30, blue: 0.25)
                        : selectedTheme.accentColor.opacity(0.58),
                    lineWidth: isResolvingTurn ? 2.5 : 1.5
                )
        }
        .shadow(
            color: isResolvingTurn
                ? Color(red: 0.88, green: 0.30, blue: 0.25).opacity(0.20)
                : selectedTheme.primaryColor.opacity(0.14),
            radius: isResolvingTurn ? 7 : 5,
            y: 3
        )
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

private struct ThemeBackground: View {
    let theme: GameTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.975, blue: 0.90),
                        Color(red: 0.98, green: 0.94, blue: 0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(theme.secondaryColor.opacity(0.07))
                    .frame(width: 230, height: 230)
                    .position(x: proxy.size.width + 30, y: 70)

                Ellipse()
                    .fill(theme.primaryColor.opacity(0.08))
                    .frame(width: 170, height: 76)
                    .rotationEffect(.degrees(-28))
                    .position(x: 15, y: proxy.size.height - 30)

                Circle()
                    .stroke(theme.accentColor.opacity(0.10), lineWidth: 18)
                    .frame(width: 115, height: 115)
                    .position(x: proxy.size.width - 22, y: proxy.size.height * 0.58)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
