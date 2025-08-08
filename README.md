# Window Switcher

Window Switcher is a simple searchable window switcher for macOS. 

![demo](https://github.com/user-attachments/assets/341cbfa8-b004-4d8c-a947-72eefe3411e9)

## Usage

> [!Note]
> The app needs accessibility to get all windows and focus windows in the active space, and
> needs screen recording to get the window previews.

1. Use hotkey (option + tab) to open the window switcher.
2. Type to search for a window, or use arrow keys to move your selection.
3. Press `enter` to switch to the selected window.

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

> [!Warning]
> Due to packaging limitations, you must **remove** any previously granted Accessibility and Screen Recording permissions **before** launching the updated app, and then **re-grant** them after the new version starts.

### Homebrew

```sh
brew upgrade window-switcher
```

After upgrading, open **System Settings → Privacy & Security**, remove the app from both **Accessibility** and **Screen Recording**, then launch the app and grant the permissions again when prompted.

## Features

- [x] Fuzzy-search for windows
- [x] Switch to windows
- [x] List windows in current space
- [ ] List windows in all spaces
- [x] Get window previews
- [ ] User-defined hotkey bindings
- [x] Fuzzy-search for applications
