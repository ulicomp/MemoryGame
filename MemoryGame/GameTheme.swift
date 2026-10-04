enum GameTheme: String, CaseIterable, Identifiable {
    case fruit = "Fruit"
    case animals = "Animals"
    case nature = "Nature"

    var id: Self { self }

    var displayName: String { rawValue }

    var symbols: [String] {
        switch self {
        case .fruit:
            ["🍎", "🍋", "🍇", "🍉", "🍒", "🥝", "🍓", "🍊"]
        case .animals:
            ["🐶", "🐱", "🐼", "🦊", "🐸", "🐵", "🐰", "🦁"]
        case .nature:
            ["🌸", "🌻", "🍀", "🌵", "🍁", "🌈", "🌙", "⭐️"]
        }
    }
}
