import Foundation

enum SearchItemDescriptors {
    static func sortLabel(for item: SearchItem) -> String {
        switch item {
        case .window(let window):
            return FuzzySearch.normalize(window.fullyQualifiedName)
        case .application(let application):
            return FuzzySearch.normalize(application.name)
        }
    }
}
