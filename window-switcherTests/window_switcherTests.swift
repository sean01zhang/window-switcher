import AppKit
import Testing
#if canImport(window_switcher_dev)
@testable import window_switcher_dev
#else
@testable import window_switcher
#endif

struct window_switcherTests {
    @Test func blankQueryUsesRecentWindowOrder() {
        let first = makeWindow(pid: 101, appName: "Mail", title: "Inbox")
        let second = makeWindow(pid: 102, appName: "Notes", title: "Today")
        let third = makeWindow(pid: 103, appName: "Terminal", title: "shell")

        let ordered = WindowRecentUse.orderedWindows(
            [first, second, third],
            recentKeys: [third.recentUseKey, first.recentUseKey, second.recentUseKey]
        )

        #expect(ordered.map(\.name) == ["shell", "Inbox", "Today"])
    }

    @Test func blankQuerySelectionSkipsMostRecentWindow() {
        let selectedIndex = SwitcherSearchResults.initialSelectionIndex(
            resultCount: 3,
            mode: .blankQuery
        )

        #expect(selectedIndex == 1)
    }

    @Test func blankQuerySelectionKeepsSingleWindowSelected() {
        let selectedIndex = SwitcherSearchResults.initialSelectionIndex(
            resultCount: 1,
            mode: .blankQuery
        )

        #expect(selectedIndex == 0)
    }

    @Test func nonEmptyQueryStillRanksByFuzzyScore() {
        let windows = [
            makeWindow(pid: 201, appName: "Safari", title: "Documentation"),
            makeWindow(pid: 202, appName: "Terminal", title: "Terminal")
        ]

        let results = Windows.search("terminal", windows)

        #expect(results.map(\.1.name) == ["Terminal"])
    }

    @Test func fuzzySearchPrefersPrefixOverLooseSubsequence() {
        let prefix = FuzzySearch.match("saf", against: "Safari")
        let loose = FuzzySearch.match("saf", against: "Debug Safari Window")

        #expect(prefix.score > loose.score)
        #expect(prefix.isPrefixMatch)
    }

    @Test func fuzzySearchRewardsTokenPrefixMatches() {
        let tokenPrefix = FuzzySearch.match("chr", against: "Google Chrome")
        let loose = FuzzySearch.match("chr", against: "Archive Browser")

        #expect(tokenPrefix.score > loose.score)
        #expect(tokenPrefix.isTokenPrefixMatch)
    }

    @Test func fuzzySearchIsDiacriticInsensitive() {
        let match = FuzzySearch.match("cafe", against: "Café")

        #expect(match.matched)
        #expect(match.score > 0)
    }

    @Test func windowSearchPrefersTitleMatchOverAppNameOnlyMatch() {
        let windows = [
            makeWindow(pid: 211, appName: "Terminal", title: "Build Logs"),
            makeWindow(pid: 212, appName: "Notes", title: "Terminal Migration")
        ]

        let results = Windows.search("terminal", windows)

        #expect(results.map(\.1.name) == ["Terminal Migration", "Build Logs"])
    }

    @Test func equalScoresPreferWindowsOverApplications() {
        let window = makeWindow(pid: 301, appName: "Notes", title: "Meeting Notes")
        let application = Application(
            name: "Notes",
            url: URL(fileURLWithPath: "/Applications/Notes.app")
        )

        let ordered = SwitcherSearchResults.orderedItems(
            from: [
                (10, .application(application)),
                (10, .window(window))
            ],
            mode: .searchQuery
        )

        #expect(ordered == [.window(window), .application(application)])
    }

    @Test func equalScoreWindowsSortDeterministically() {
        let alpha = makeWindow(pid: 311, appName: "App", title: "Alpha")
        let beta = makeWindow(pid: 312, appName: "App", title: "Beta")

        let ordered = SwitcherSearchResults.orderedItems(
            from: [
                (10, .window(beta)),
                (10, .window(alpha))
            ],
            mode: .searchQuery
        )

        #expect(ordered == [.window(alpha), .window(beta)])
    }

    @Test func reconcileDropsMissingWindowsAndAppendsNewOnes() {
        let first = WindowRecentUseKey(appPID: 401, title: "One", size: CGSize(width: 600, height: 400))
        let second = WindowRecentUseKey(appPID: 402, title: "Two", size: CGSize(width: 700, height: 500))
        let third = WindowRecentUseKey(appPID: 403, title: "Three", size: CGSize(width: 800, height: 600))

        let reconciled = WindowRecentUse.reconcile(
            [second, first],
            with: [first, third]
        )

        #expect(reconciled == [first, third])
    }

    @Test func seedPreservesSnapshotOrderForAmbiguousDuplicates() {
        let duplicateKey = WindowRecentUseKey(appPID: 501, title: "Notes", size: CGSize(width: 900, height: 700))
        let duplicateTitle = duplicateKey.titleKey
        let uniqueKey = WindowRecentUseKey(appPID: 502, title: "Terminal", size: CGSize(width: 1000, height: 700))

        let snapshot = [
            WindowRecentUseSnapshotEntry(titleKey: duplicateTitle, recentUseKey: duplicateKey),
            WindowRecentUseSnapshotEntry(titleKey: duplicateTitle, recentUseKey: duplicateKey),
            WindowRecentUseSnapshotEntry(titleKey: uniqueKey.titleKey, recentUseKey: uniqueKey)
        ]

        let seededIndices = WindowRecentUse.seededIndices(
            snapshot: snapshot,
            from: [
                WindowRecentUseSeedCandidate(titleKey: duplicateTitle, recentUseKey: duplicateKey),
                WindowRecentUseSeedCandidate(titleKey: uniqueKey.titleKey, recentUseKey: uniqueKey)
            ]
        )

        #expect(seededIndices == [2, 0, 1])
    }
}

private func makeWindow(
    pid: Int32,
    appName: String,
    title: String,
    frame: CGRect = CGRect(x: 10, y: 10, width: 800, height: 600)
) -> Window {
    Window(
        id: Int(pid),
        appName: appName,
        appPID: pid,
        name: title,
        frame: frame,
        element: AXUIElementCreateApplication(pid)
    )
}
