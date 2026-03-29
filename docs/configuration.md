# Window Switcher Configuration

Window Switcher reads optional configuration from `~/.config/window-switcher/config.toml`.

If the file does not exist, Window Switcher uses built-in defaults. The menu bar's `Open Config...` action creates the file with the default contents before opening it.

## Default Config

```toml
[trigger]
key = "tab"
modifiers = ["option"]
```

## Config Keys

| Section | Key | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `trigger` | `key` | `string` | `"tab"` | The key used to open the switcher. |
| `trigger` | `modifiers` | `array<string>` | `["option"]` | Modifier keys pressed with `trigger.key`. |

## Supported Modifier Values

- `command`
- `option`
- `control`
- `shift`

## Behavior

- If the config file is missing, Window Switcher falls back to `Option+Tab`.
- If the config file is invalid, Window Switcher falls back to `Option+Tab` and logs a warning.
- Configuration is loaded on app launch and reloaded the next time the switcher is opened.
- Window Switcher does not watch the config file for live updates while the switcher is already open.
