//
//  window_switcherTests.swift
//  window-switcherTests
//
//  Created by Sean Zhang on 2024-12-27.
//

import Testing
import AppKit
import SwiftUI
@testable import window_switcher_dev

struct window_switcherTests {
    @Test func missingConfigUsesDefault() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.toml", isDirectory: false)

        let config = ConfigLoader.load(from: tempURL)
        #expect(config == .default)
    }

    @Test func ensureMissingConfigWritesDefaultTemplate() async throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempURL = tempDirectoryURL.appendingPathComponent("config.toml", isDirectory: false)

        let createdURL = try ConfigLoader.ensureConfigFileExists(at: tempURL)

        #expect(createdURL == tempURL)
        let contents = try String(contentsOf: tempURL, encoding: .utf8)
        #expect(contents == ConfigLoader.defaultConfigContents)
        #expect(ConfigLoader.load(from: tempURL) == .default)
    }

    @Test func validDefaultTriggerConfigDecodes() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "tab"
        modifiers = ["option"]
        """.utf8))

        #expect(config == .default)
    }

    @Test func validAlternateTriggerConfigDecodes() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "j"
        modifiers = ["command"]
        """.utf8))

        #expect(config.trigger == TriggerShortcut(key: .j, modifiers: [.command]))
    }

    @Test func invalidKeyFallsBackToDefault() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "not-a-key"
        modifiers = ["option"]
        """.utf8))

        #expect(config == .default)
    }

    @Test func emptyModifierListFallsBackToDefault() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "tab"
        modifiers = []
        """.utf8))

        #expect(config == .default)
    }

    @Test func unknownModifierFallsBackToDefault() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "tab"
        modifiers = ["hyper"]
        """.utf8))

        #expect(config == .default)
    }

    @Test func duplicateModifiersAreNormalized() async throws {
        let config = ConfigLoader.load(from: Data("""
        [trigger]
        key = "tab"
        modifiers = ["option", "option", "shift"]
        """.utf8))

        #expect(config.trigger == TriggerShortcut(key: .tab, modifiers: [.option, .shift]))
    }

    @Test func menuShortcutExistsForCommonKeys() async throws {
        #expect(TriggerShortcut.default.menuShortcut != nil)
        #expect(TriggerShortcut(key: .j, modifiers: [.command]).menuShortcut != nil)
    }

    @Test func triggerMatchesExpectedKeyAndModifiers() async throws {
        let trigger = TriggerShortcut(key: .j, modifiers: [.command, .shift])
        #expect(trigger.matches(key: "j", characters: "j", modifiers: [.command, .shift]))
        #expect(!trigger.matches(key: "j", characters: "j", modifiers: [.command]))
        #expect(!trigger.matches(key: "k", characters: "k", modifiers: [.command, .shift]))
    }
}
