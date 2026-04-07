import Foundation

enum SearchItemDescriptors {
    static func sortLabel(for item: SearchItem) -> String {
        switch item {
        case .window(let window):
            return FuzzySearch.normalize(fullyQualifiedWindowName(window))
        case .application(let application):
            return FuzzySearch.normalize(application.name)
        }
    }
}
