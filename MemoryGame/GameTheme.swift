import SwiftUI

enum GameTheme: String, CaseIterable, Identifiable {
    case fruit = "Fruit"
    case animals = "Animals"
    case nature = "Nature"

    var id: Self { self }

    var displayName: String { rawValue }

    var displayTitle: String {
        switch self {
        case .fruit: "Fruit Pairs"
        case .animals: "Animal Pairs"
        case .nature: "Nature Pairs"
        }
    }

    var subtitle: String {
        switch self {
        case .fruit: "Find all the matching fruits!"
        case .animals: "Find all the matching animals!"
        case .nature: "Match all the nature pairs!"
        }
    }

    var primaryColor: Color {
        switch self {
        case .fruit: Color(red: 0.22, green: 0.48, blue: 0.25)
        case .animals: Color(red: 0.66, green: 0.35, blue: 0.18)
        case .nature: Color(red: 0.14, green: 0.39, blue: 0.27)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .fruit: Color(red: 0.89, green: 0.34, blue: 0.27)
        case .animals: Color(red: 0.12, green: 0.51, blue: 0.49)
        case .nature: Color(red: 0.25, green: 0.52, blue: 0.68)
        }
    }

    var accentColor: Color {
        switch self {
        case .fruit: Color(red: 0.91, green: 0.65, blue: 0.16)
        case .animals: Color(red: 0.88, green: 0.61, blue: 0.20)
        case .nature: Color(red: 0.89, green: 0.70, blue: 0.18)
        }
    }

    var cardBackTopColor: Color {
        switch self {
        case .fruit: Color(red: 0.28, green: 0.58, blue: 0.30)
        case .animals: Color(red: 0.78, green: 0.42, blue: 0.22)
        case .nature: Color(red: 0.16, green: 0.45, blue: 0.33)
        }
    }

    var cardBackBottomColor: Color {
        switch self {
        case .fruit: Color(red: 0.13, green: 0.37, blue: 0.18)
        case .animals: Color(red: 0.08, green: 0.45, blue: 0.44)
        case .nature: Color(red: 0.19, green: 0.43, blue: 0.59)
        }
    }

    var cardBackSymbol: String {
        switch self {
        case .fruit: "leaf.fill"
        case .animals: "pawprint.fill"
        case .nature: "mountain.2.fill"
        }
    }

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
