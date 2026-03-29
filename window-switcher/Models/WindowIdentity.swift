import AppKit

struct WindowTitleKey: Hashable {
    let appPID: Int32
    let title: String
}

struct WindowSizeKey: Hashable {
    let width: Int
    let height: Int

    init(_ frame: CGRect?) {
        width = Int((frame?.size.width ?? 0).rounded())
        height = Int((frame?.size.height ?? 0).rounded())
    }

    init(_ size: CGSize) {
        width = Int(size.width.rounded())
        height = Int(size.height.rounded())
    }
}

struct WindowRecentUseKey: Hashable {
    let titleKey: WindowTitleKey
    let sizeKey: WindowSizeKey

    init(appPID: Int32, title: String, frame: CGRect?) {
        titleKey = WindowTitleKey(appPID: appPID, title: title)
        sizeKey = WindowSizeKey(frame)
    }

    init(appPID: Int32, title: String, size: CGSize) {
        titleKey = WindowTitleKey(appPID: appPID, title: title)
        sizeKey = WindowSizeKey(size)
    }
}

struct WindowRecentUseSnapshotEntry: Hashable {
    let titleKey: WindowTitleKey
    let recentUseKey: WindowRecentUseKey
}

struct WindowRecentUseSeedCandidate: Hashable {
    let titleKey: WindowTitleKey?
    let recentUseKey: WindowRecentUseKey?
}

extension Window {
    var windowTitleKey: WindowTitleKey {
        WindowTitleKey(appPID: appPID, title: name)
    }

    var recentUseKey: WindowRecentUseKey {
        WindowRecentUseKey(appPID: appPID, title: name, frame: frame)
    }

    var recentUseSnapshotEntry: WindowRecentUseSnapshotEntry {
        WindowRecentUseSnapshotEntry(
            titleKey: windowTitleKey,
            recentUseKey: recentUseKey
        )
    }
}

enum WindowRecentUse {
    static func orderedWindows(_ windows: [Window], recentKeys: [WindowRecentUseKey]) -> [Window] {
        var remainingIndicesByKey: [WindowRecentUseKey: [Int]] = [:]
        for (index, window) in windows.enumerated() {
            remainingIndicesByKey[window.recentUseKey, default: []].append(index)
        }

        var consumedIndices: Set<Int> = []
        var orderedWindows: [Window] = []

        for key in recentKeys {
            guard var remainingIndices = remainingIndicesByKey[key],
                  let index = remainingIndices.first else {
                continue
            }

            remainingIndices.removeFirst()
            if remainingIndices.isEmpty {
                remainingIndicesByKey.removeValue(forKey: key)
            } else {
                remainingIndicesByKey[key] = remainingIndices
            }

            consumedIndices.insert(index)
            orderedWindows.append(windows[index])
        }

        for (index, window) in windows.enumerated() where !consumedIndices.contains(index) {
            orderedWindows.append(window)
        }

        return orderedWindows
    }

    static func reconcile(_ recentKeys: [WindowRecentUseKey], with availableKeys: [WindowRecentUseKey]) -> [WindowRecentUseKey] {
        var remainingCounts: [WindowRecentUseKey: Int] = [:]
        for key in availableKeys {
            remainingCounts[key, default: 0] += 1
        }

        var reconciledKeys: [WindowRecentUseKey] = []

        func appendIfAvailable(_ key: WindowRecentUseKey) {
            guard let count = remainingCounts[key], count > 0 else {
                return
            }

            reconciledKeys.append(key)
            if count == 1 {
                remainingCounts.removeValue(forKey: key)
            } else {
                remainingCounts[key] = count - 1
            }
        }

        for key in recentKeys {
            appendIfAvailable(key)
        }

        for key in availableKeys {
            appendIfAvailable(key)
        }

        return reconciledKeys
    }

    static func movingToFront(_ key: WindowRecentUseKey, in recentKeys: [WindowRecentUseKey]) -> [WindowRecentUseKey] {
        var reorderedKeys = recentKeys
        if let existingIndex = reorderedKeys.firstIndex(of: key) {
            reorderedKeys.remove(at: existingIndex)
        }
        reorderedKeys.insert(key, at: 0)
        return reorderedKeys
    }

    static func seededKeys(
        snapshot: [WindowRecentUseSnapshotEntry],
        from candidates: [WindowRecentUseSeedCandidate]
    ) -> [WindowRecentUseKey] {
        seededIndices(snapshot: snapshot, from: candidates).map { snapshot[$0].recentUseKey }
    }

    static func seededIndices(
        snapshot: [WindowRecentUseSnapshotEntry],
        from candidates: [WindowRecentUseSeedCandidate]
    ) -> [Int] {
        var indicesByRecentUseKey: [WindowRecentUseKey: [Int]] = [:]
        var indicesByTitleKey: [WindowTitleKey: [Int]] = [:]

        for (index, entry) in snapshot.enumerated() {
            indicesByRecentUseKey[entry.recentUseKey, default: []].append(index)
            indicesByTitleKey[entry.titleKey, default: []].append(index)
        }

        var matchedIndices: Set<Int> = []
        var seededIndices: [Int] = []

        for candidate in candidates {
            if let recentUseKey = candidate.recentUseKey,
               let index = uniqueIndex(for: recentUseKey, from: indicesByRecentUseKey, excluding: matchedIndices) {
                matchedIndices.insert(index)
                seededIndices.append(index)
                continue
            }

            if let titleKey = candidate.titleKey,
               let index = uniqueIndex(for: titleKey, from: indicesByTitleKey, excluding: matchedIndices) {
                matchedIndices.insert(index)
                seededIndices.append(index)
            }
        }

        for (index, _) in snapshot.enumerated() where !matchedIndices.contains(index) {
            seededIndices.append(index)
        }

        return seededIndices
    }

    private static func uniqueIndex<Key: Hashable>(
        for key: Key,
        from indicesByKey: [Key: [Int]],
        excluding matchedIndices: Set<Int>
    ) -> Int? {
        let candidateIndices = (indicesByKey[key] ?? []).filter { !matchedIndices.contains($0) }
        guard candidateIndices.count == 1 else {
            return nil
        }

        return candidateIndices[0]
    }
}
