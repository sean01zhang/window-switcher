import Foundation

enum SearchItem: Hashable {
    case window(Window)
    case application(Application)

    var sortLabel: String {
        switch self {
        case .window(let window):
            return FuzzySearch.normalize(window.fqn())
        case .application(let application):
            return FuzzySearch.normalize(application.name)
        }
    }
}
