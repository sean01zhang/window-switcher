//
//  Windows.swift
//  window-switcher
//
//  Created by Sean Zhang on 2024-12-27.
//

import AppKit

struct Window: Hashable {
    var id: Int
    var appName: String
    var appPID: Int32
    var name: String
    var element: AXUIElement

    func hash(into hasher: inout Hasher) {
        element.hash(into: &hasher)
    }

    static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.element == rhs.element
    }

    func fqn() -> String {
        "\(appName): \(name)"
    }
}

final class Windows {
    static func search(_ query: String, _ windows: [Window]) -> [(Int16, Window)] {
       if query.isEmpty {
           return windows.map({ (0, $0) })
       }

       var results: [(Int16, Window)] = []

       for window in windows {
           let score = FuzzyCompare(query.lowercased(), window.fqn().lowercased())
           if score > 3 {
               results.append((score, window))
           }
       }

       results.sort(by: { $0.0 > $1.0 })
       return results
   }
}
