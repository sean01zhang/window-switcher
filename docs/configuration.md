# Window Switcher Configuration

Window Switcher reads configuration from `~/.config/window-switcher/config.toml`. If the file is missing, it falls
back to the default config.

To see changes after making changes to the config, go to the menubar widget and click "Open Switcher".

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
