import SwiftUI
import UIKit

private enum GamePhase: Equatable {
    case setup
    case preview
    case playing
    case completed
}

private struct CardGridMetrics {
    let columns: [GridItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let spacing: CGFloat
}

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
    @State private var previewTask: Task<Void, Never>?
    @State private var timerTask: Task<Void, Never>?
    @State private var gameID = UUID()
    @State private var phase = GamePhase.setup
    @State private var moves = 0
    @State private var numberOfPairs = Self.defaultNumberOfPairs
    @State private var selectedTheme = GameTheme.fruit
    @State private var elapsedSeconds = 0
    @State private var hasGameStarted = false
    @State private var achievedNewBest = false
    @State private var isShowingNewGameConfirmation = false
    @State private var isShowingSetupConfirmation = false

    init() {
        _cards = State(
            initialValue: Self.makeCards(
                numberOfPairs: Self.defaultNumberOfPairs,
                theme: .fruit
            )
        )
    }

    private var columnCount: Int {
        switch numberOfPairs {
        case 2: 2
        case 6: 3
        default: 4
        }
    }

    private var setupColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: columnCount
        )
    }

    private var cardAspectRatio: CGFloat {
        numberOfPairs >= 6 ? 0.90 : 0.86
    }

    private var cardSymbolSize: CGFloat {
        switch numberOfPairs {
        case 2: 52
        case 6: 40
        default: 35
        }
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
        GeometryReader { screen in
            ZStack {
                ThemeBackground(theme: selectedTheme)

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        Color.clear
                            .frame(height: 0)
                            .id("screenTop")

                        if phase == .setup {
                            setupContent
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            activeGameContent(screenSize: screen.size)
                                .transition(.opacity)
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollDisabled(phase == .preview)
                    .id(phase == .setup)
                    .onChange(of: phase) {
                        scrollProxy.scrollTo("screenTop", anchor: .top)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.24), value: phase == .setup)
        .onDisappear {
            cancelAsyncTasks()
        }
        .confirmationDialog(
            "Start a new game?",
            isPresented: $isShowingNewGameConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Game", role: .destructive) {
                HapticFeedback.newGame()
                startNewGame()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
        }
        .confirmationDialog(
            "Change setup?",
            isPresented: $isShowingSetupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Change Setup", role: .destructive) {
                enterSetupMode()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
        }
    }

    private var setupContent: some View {
        VStack(spacing: 18) {
            setupHeader
            setupBestScore
            setupControls
            startGameButton
            setupBoard
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 32)
    }

    private var setupHeader: some View {
        VStack(spacing: 5) {
            themedTitle(size: 42)

            Text(selectedTheme.subtitle)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color(red: 0.35, green: 0.32, blue: 0.27))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var setupBestScore: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(selectedTheme.accentColor)
                .frame(width: 38, height: 38)
                .background(selectedTheme.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text("BEST FOR \(numberOfPairs) PAIRS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(currentBestMoves == 0 ? "No score yet" : "\(currentBestMoves) moves")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.25, green: 0.22, blue: 0.18))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 19))
        .overlay {
            RoundedRectangle(cornerRadius: 19)
                .stroke(selectedTheme.accentColor.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            currentBestMoves == 0
                ? "No best score yet"
                : "Best score \(currentBestMoves) moves"
        )
    }

    private var setupControls: some View {
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
                prepareBoard(for: .setup)
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
                prepareBoard(for: .setup)
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
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 29, height: 29)
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

            Spacer(minLength: 1)

            Image(systemName: "chevron.down")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.10), radius: 8, y: 4)
    }

    private var startGameButton: some View {
        Button {
            HapticFeedback.newGame()
            startNewGame()
        } label: {
            Label("Start Game", systemImage: "play.fill")
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
        .accessibilityLabel("Start memory game")
    }

    private var setupBoard: some View {
        VStack(alignment: .leading, spacing: 11) {
            boardHeader

            LazyVGrid(columns: setupColumns, spacing: 10) {
                ForEach(cards) { card in
                    cardButton(for: card)
                        .aspectRatio(cardAspectRatio, contentMode: .fit)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: selectedTheme.primaryColor.opacity(0.09), radius: 14, y: 7)
    }

    private func activeGameContent(screenSize: CGSize) -> some View {
        let boardHeight = activeBoardHeight(for: screenSize.height)

        return VStack(spacing: 12) {
            compactHeader
            compactStats
            activeBoard(height: boardHeight)

            if phase == .completed {
                completionView
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }

            activeActions
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: phase)
    }

    private var compactHeader: some View {
        HStack {
            themedTitle(size: 31)

            Spacer(minLength: 8)

            if phase == .preview {
                Label("Memorize", systemImage: "eye.fill")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(selectedTheme.primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(selectedTheme.primaryColor.opacity(0.12), in: Capsule())
            }
        }
    }

    private func themedTitle(size: CGFloat) -> some View {
        Text(selectedTheme.displayTitle)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [selectedTheme.secondaryColor, selectedTheme.primaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.70)
    }

    private var compactStats: some View {
        HStack(spacing: 7) {
            compactStatCard(
                title: "Moves",
                value: "\(moves)",
                icon: "hand.tap.fill",
                color: selectedTheme.secondaryColor,
                accessibilityLabel: "Moves \(moves)"
            )
            compactStatCard(
                title: "Pairs",
                value: "\(matchedPairs)/\(numberOfPairs)",
                icon: "star.fill",
                color: selectedTheme.primaryColor,
                accessibilityLabel: "\(matchedPairs) of \(numberOfPairs) pairs matched"
            )
            compactStatCard(
                title: "Time",
                value: formattedElapsedTime,
                icon: "clock.fill",
                color: selectedTheme.primaryColor,
                accessibilityLabel: timerAccessibilityLabel
            )
            compactStatCard(
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

    private func compactStatCard(
        title: String,
        value: String,
        icon: String,
        color: Color,
        accessibilityLabel: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(color)

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.17))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 57)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func activeBoardHeight(for screenHeight: CGFloat) -> CGFloat {
        if phase == .completed {
            return min(max(210, screenHeight * 0.27), 260)
        }

        return min(max(390, screenHeight - 220), 540)
    }

    private func activeBoard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            boardHeader

            GeometryReader { board in
                let metrics = cardGridMetrics(in: board.size)

                LazyVGrid(columns: metrics.columns, spacing: metrics.spacing) {
                    ForEach(cards) { card in
                        cardButton(for: card)
                            .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .animation(.spring(response: 0.36, dampingFraction: 0.72), value: matchedPairs)
            }
        }
        .padding(10)
        .frame(height: height)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: selectedTheme.primaryColor.opacity(0.09), radius: 12, y: 6)
        .accessibilityHint(phase == .preview ? "Previewing cards" : "")
    }

    private var boardHeader: some View {
        HStack {
            Label(
                phase == .preview ? "Previewing cards" : "Match the pairs",
                systemImage: phase == .preview ? "eye.fill" : selectedTheme.cardBackSymbol
            )
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(selectedTheme.primaryColor)

            Spacer()

            Text("\(cards.count) cards")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func cardGridMetrics(in size: CGSize) -> CardGridMetrics {
        let rows = max(1, Int(ceil(Double(cards.count) / Double(columnCount))))
        let spacing: CGFloat = numberOfPairs >= 6 ? 8 : 10
        let totalHorizontalSpacing = CGFloat(columnCount - 1) * spacing
        let totalVerticalSpacing = CGFloat(rows - 1) * spacing
        let widthConstraint = max(1, (size.width - totalHorizontalSpacing) / CGFloat(columnCount))
        let heightConstraint = max(1, (size.height - totalVerticalSpacing) / CGFloat(rows))
        let widthFromHeight = heightConstraint * cardAspectRatio
        let cardWidth = min(widthConstraint, widthFromHeight)
        let cardHeight = cardWidth / cardAspectRatio
        let columns = Array(
            repeating: GridItem(.fixed(cardWidth), spacing: spacing),
            count: columnCount
        )

        return CardGridMetrics(
            columns: columns,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            spacing: spacing
        )
    }

    @ViewBuilder
    private func cardButton(for card: MemoryCard) -> some View {
        if card.isMatched {
            Color.clear
                .accessibilityHidden(true)
        } else {
            Button {
                selectCard(card.id)
            } label: {
                cardView(for: card)
            }
            .buttonStyle(.plain)
            .disabled(phase != .playing || isResolvingTurn || card.isFaceUp)
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

    private var completionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(selectedTheme.accentColor)

            Text("You matched them all!")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(selectedTheme.primaryColor)
                .accessibilityAddTraits(.isHeader)

            Text("\(moves) moves  •  \(formattedElapsedTime)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            if achievedNewBest {
                Label("New Best!", systemImage: "trophy.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.46, green: 0.31, blue: 0.04))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selectedTheme.accentColor.opacity(0.30), in: Capsule())
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 17)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 23))
        .overlay {
            RoundedRectangle(cornerRadius: 23)
                .stroke(selectedTheme.accentColor.opacity(0.35), lineWidth: 1.5)
        }
        .shadow(color: selectedTheme.accentColor.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var activeActions: some View {
        HStack(spacing: 10) {
            Button {
                requestChangeSetup()
            } label: {
                Label("Change Setup", systemImage: "slider.horizontal.3")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(selectedTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 17))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(selectedTheme.primaryColor.opacity(0.25), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change game settings")

            Button {
                requestNewGame()
            } label: {
                Label(
                    phase == .completed ? "Play Again" : "Reset Game",
                    systemImage: "arrow.clockwise"
                )
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [selectedTheme.primaryColor, selectedTheme.cardBackTopColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 17)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start a new shuffled game")
        }
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
        .animation(.easeInOut(duration: 0.32), value: card.isFaceUp)
    }

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [selectedTheme.cardBackTopColor, selectedTheme.cardBackBottomColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 62, height: 62)
                .offset(x: -28, y: -38)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 7)
                .frame(width: 74, height: 74)
                .offset(x: 30, y: 40)

            Image(systemName: selectedTheme.cardBackSymbol)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.42), lineWidth: 1.5)
        }
        .shadow(color: selectedTheme.primaryColor.opacity(0.20), radius: 5, y: 3)
    }

    private func cardFront(for card: MemoryCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 1.0, green: 0.985, blue: 0.93))

            Circle()
                .fill(selectedTheme.accentColor.opacity(0.12))
                .padding(7)

            Text(card.content)
                .font(.system(size: cardSymbolSize))
                .minimumScaleFactor(0.68)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
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
                : selectedTheme.primaryColor.opacity(0.13),
            radius: isResolvingTurn ? 6 : 4,
            y: 2
        )
    }

    private func selectCard(_ cardID: UUID) {
        guard phase == .playing,
              !isResolvingTurn,
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
        if phase == .playing && hasMeaningfulProgress {
            isShowingNewGameConfirmation = true
        } else {
            HapticFeedback.newGame()
            startNewGame()
        }
    }

    private func requestChangeSetup() {
        if phase == .playing && hasMeaningfulProgress {
            isShowingSetupConfirmation = true
        } else {
            enterSetupMode()
        }
    }

    private func startNewGame() {
        let newGameID = prepareBoard(for: .preview)
        beginPreview(for: newGameID)
    }

    @discardableResult
    private func prepareBoard(for newPhase: GamePhase) -> UUID {
        cancelAsyncTasks()

        let newGameID = UUID()
        gameID = newGameID
        cards = Self.makeCards(numberOfPairs: numberOfPairs, theme: selectedTheme)
        firstSelectedCardID = nil
        isResolvingTurn = false
        moves = 0
        elapsedSeconds = 0
        hasGameStarted = false
        achievedNewBest = false
        isShowingNewGameConfirmation = false
        isShowingSetupConfirmation = false
        phase = newPhase
        return newGameID
    }

    private func beginPreview(for previewGameID: UUID) {
        previewTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  gameID == previewGameID,
                  phase == .preview else {
                return
            }

            withAnimation(.easeInOut(duration: 0.32)) {
                setUnmatchedCardsFaceUp(true)
            }

            do {
                try await Task.sleep(for: .milliseconds(1_820))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  gameID == previewGameID,
                  phase == .preview else {
                return
            }

            withAnimation(.easeInOut(duration: 0.32)) {
                setUnmatchedCardsFaceUp(false)
            }

            do {
                try await Task.sleep(for: .milliseconds(320))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  gameID == previewGameID,
                  phase == .preview else {
                return
            }

            previewTask = nil
            phase = .playing
        }
    }

    private func setUnmatchedCardsFaceUp(_ isFaceUp: Bool) {
        for index in cards.indices where !cards[index].isMatched {
            cards[index].isFaceUp = isFaceUp
        }
    }

    private func enterSetupMode() {
        prepareBoard(for: .setup)
    }

    private func cancelAsyncTasks() {
        resolutionTask?.cancel()
        resolutionTask = nil
        previewTask?.cancel()
        previewTask = nil
        timerTask?.cancel()
        timerTask = nil
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

        phase = .completed
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
