import AppKit

struct Window: Hashable {
    var id: Int
    var appName: String
    var appPID: Int32
    var name: String
    var frame: CGRect?
    var element: AXUIElement

    var fullyQualifiedName: String {
        "\(appName): \(name)"
    }

    func hash(into hasher: inout Hasher) {
        element.hash(into: &hasher)
    }

    static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.element == rhs.element
    }
}
