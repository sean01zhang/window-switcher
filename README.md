# Window Switcher

Window Switcher is a simple searchable window switcher for macOS. 

![demo](https://github.com/user-attachments/assets/341cbfa8-b004-4d8c-a947-72eefe3411e9)

## Usage

> [!Note]
> The app needs accessibility to get all windows and focus windows in the active space, and
> needs screen recording to get the window previews.

1. Use the configured hotkey to open the window switcher. The default is `Option+Tab`.
2. Type to search for a window, or use arrow keys to move your selection.
3. Press `enter` to switch to the selected window.
4. Use the menu bar extra toggle to have Window Switcher launch on startup.

## Configuration

Window Switcher reads optional configuration from `~/.config/window-switcher/config.toml`.

Full configuration docs live in [docs/configuration.md](docs/configuration.md).

```toml
[trigger]
key = "tab"
modifiers = ["option"]
```

Supported trigger modifiers are `command`, `option`, `control`, and `shift`. If the file is missing or invalid, Window Switcher falls back to the default `Option+Tab` trigger.

Configuration is loaded on app launch and reloaded the next time the switcher is opened. The app does not watch the file for live updates.

## Installation

### Homebrew

This app is also available as a cask on Homebrew.

```sh
brew install --cask sean01zhang/formulae/window-switcher
```

### Manually

1. Go to [releases](https://github.com/sean01zhang/window-switcher/releases) and download the latest version. The zip (`window-switcher-v#.#.#.zip`) can be found under the assets section.
2. Unzip the downloaded file. It is recommended to move the app to the Applications folder.
3. Open the app. You may need to give the app permissions to access accessibility and screen recording. 

## Upgrading

### Homebrew

```sh
brew upgrade window-switcher
```

## Features

- [x] Fuzzy-search for windows
- [x] Switch to windows
- [x] List windows in current space
- [ ] List windows in all spaces
- [x] Get window previews
- [x] User-defined hotkey bindings
- [x] Fuzzy-search for applications
- [x] Launch on startup
