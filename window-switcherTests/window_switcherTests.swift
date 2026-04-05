import AppKit
import Testing
#if canImport(window_switcher_dev)
@testable import window_switcher_dev
#else
@testable import window_switcher
#endif

struct window_switcherTests {
    @Test func defaultConfigIncludesNavigationBindings() {
        let config = ConfigLoader.load(from: Data(ConfigLoader.defaultConfigContents.utf8))

        #expect(config.trigger == .default)
        #expect(config.navigation == .default)
        #expect(config.resultListItem == .default)
    }

    @Test func configAllowsRemappingNavigationBindings() {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "tab"
        modifiers = ["option"]

        [navigation.next]
        key = "n"
        modifiers = ["control", "shift"]

        [navigation.previous]
        key = "p"
        modifiers = ["control"]

        [navigation.enter_selection]
        key = "y"
        modifiers = ["control", "shift"]
        """.utf8))

        #expect(config.navigation.next == [TriggerShortcut(key: .n, modifiers: [.control, .shift])])
        #expect(config.navigation.previous == [TriggerShortcut(key: .p, modifiers: [.control])])
        #expect(config.navigation.enterSelection == [TriggerShortcut(key: .y, modifiers: [.control, .shift])])
    }

    @Test func configAllowsMultipleNavigationBindingsPerAction() {
        let config = ConfigLoader.load(from: Data("""
        [navigation]
        next = [
          { key = "j", modifiers = ["control"] },
          { key = "n", modifiers = ["control"] }
        ]
        previous = [
          { key = "k", modifiers = ["control"] },
          { key = "p", modifiers = ["control", "shift"] }
        ]
        enter_selection = [
          { key = "y", modifiers = ["control"] },
          { key = "return", modifiers = ["command"] }
        ]
        """.utf8))

        #expect(
            config.navigation.next == [
                TriggerShortcut(key: .j, modifiers: [.control]),
                TriggerShortcut(key: .n, modifiers: [.control])
            ]
        )
        #expect(
            config.navigation.previous == [
                TriggerShortcut(key: .k, modifiers: [.control]),
                TriggerShortcut(key: .p, modifiers: [.control, .shift])
            ]
        )
        #expect(
            config.navigation.enterSelection == [
                TriggerShortcut(key: .y, modifiers: [.control]),
                TriggerShortcut(key: .return, modifiers: [.command])
            ]
        )
    }

    @Test func invalidNavigationBindingDoesNotDropOtherValidConfig() {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "space"
        modifiers = ["command"]

        [navigation.next]
        key = "bad-key"
        modifiers = ["control"]

        [navigation.previous]
        key = "u"
        modifiers = ["control"]

        [navigation.enter_selection]
        key = "y"
        modifiers = ["control"]
        """.utf8))

        #expect(config.trigger == TriggerShortcut(key: .space, modifiers: [.command]))
        #expect(config.navigation.next == NavigationConfig.default.next)
        #expect(config.navigation.previous == [TriggerShortcut(key: .u, modifiers: [.control])])
        #expect(config.navigation.enterSelection == [TriggerShortcut(key: .y, modifiers: [.control])])
    }

    @Test func configAllowsCustomResultListItemFormatting() {
        let config = ConfigLoader.load(from: Data("""
        [result.window]
        template = "{title} [{app_name}]"

        [result.app]
        template = "{name} at {path}"
        """.utf8))

        #expect(config.resultListItem.window == ResultListItemTemplate(template: "{title} [{app_name}]"))
        #expect(config.resultListItem.app == ResultListItemTemplate(template: "{name} at {path}"))
    }

    @Test func blankResultListItemTemplateFallsBackToDefaults() {
        let config = ConfigLoader.load(from: Data("""
        [result.window]
        template = ""
        """.utf8))

        #expect(config.resultListItem.window == ResultListItemConfig.default.window)
    }

    @Test func resultListItemFormatterUsesConfiguredWindowProperties() {
        let window = makeWindow(pid: 601, appName: "Mail", title: "Inbox")
        let item = SearchItem.window(window)
        let config = ResultListItemConfig(
            window: ResultListItemTemplate(template: "{title} [{app_name}]"),
            app: ResultListItemConfig.default.app
        )

        let text = ResultListItemTextFormatter.text(for: item, config: config)

        #expect(text == "Inbox [Mail]")
    }

    @Test func resultListItemFormatterUsesConfiguredAppProperties() {
        let application = Application(
            name: "Notes",
            url: URL(fileURLWithPath: "/Applications/Notes.app")
        )
        let item = SearchItem.application(application)
        let config = ResultListItemConfig(
            window: ResultListItemConfig.default.window,
            app: ResultListItemTemplate(template: "{name} -> {path}")
        )

        let text = ResultListItemTextFormatter.text(for: item, config: config)

        #expect(text == "Notes -> /Applications/Notes.app")
    }

    @Test func resultListItemFormatterLeavesUnknownPlaceholdersUntouched() {
        let window = makeWindow(pid: 602, appName: "Mail", title: "Inbox")
        let item = SearchItem.window(window)
        let config = ResultListItemConfig(
            window: ResultListItemTemplate(template: "{app_name} {missing}"),
            app: ResultListItemConfig.default.app
        )

        let text = ResultListItemTextFormatter.text(for: item, config: config)

        #expect(text == "Mail {missing}")
    }

    @Test func resultListItemFormatterDoesNotReexpandInsertedValues() {
        let window = makeWindow(pid: 603, appName: "Mail", title: "Draft {app_name}")
        let item = SearchItem.window(window)
        let config = ResultListItemConfig(
            window: ResultListItemTemplate(template: "{title}"),
            app: ResultListItemConfig.default.app
        )

        let text = ResultListItemTextFormatter.text(for: item, config: config)

        #expect(text == "Draft {app_name}")
    }

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
