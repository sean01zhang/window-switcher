# Window Switcher Configuration

Window Switcher reads configuration from `~/.config/window-switcher/config.toml`. If the file is missing, it falls
back to the default config.

To see changes after making changes to the config, go to the menubar widget and click "Open Switcher".

## Default Config

```toml
[trigger]
key = "tab"
modifiers = ["option"]

[navigation]
next = [
  { key = "j", modifiers = ["control"] },
  { key = "n", modifiers = ["control"] }
]
previous = [
  { key = "k", modifiers = ["control"] },
  { key = "p", modifiers = ["control"] }
]
```

## Config Keys

| Section | Key | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `trigger` | `key` | `string` | `"tab"` | The key used to open the switcher. |
| `trigger` | `modifiers` | `array<string>` | `["option"]` | Modifier keys pressed with `trigger.key`. |
| `navigation` | `next` | `array<table>` | `[{ key = "j", modifiers = ["control"] }, { key = "n", modifiers = ["control"] }]` | One or more shortcuts that move to the next result. |
| `navigation` | `previous` | `array<table>` | `[{ key = "k", modifiers = ["control"] }, { key = "p", modifiers = ["control"] }]` | One or more shortcuts that move to the previous result. |

The default navigation bindings add `Control+J` and `Control+N` for next, plus `Control+K` and `Control+P` for previous. Arrow keys still work, and `Tab`
still advances to the next result.

You can bind multiple shortcuts to the same action:

```toml
[navigation]
next = [
  { key = "j", modifiers = ["control"] },
  { key = "n", modifiers = ["control"] }
]
previous = [
  { key = "k", modifiers = ["control"] },
  { key = "p", modifiers = ["control"] }
]
```

For backward compatibility, a single binding can still be written as a table:

```toml
[navigation.next]
key = "j"
modifiers = ["control"]
```

## Supported Modifier Values

- `command`
- `option`
- `control`
- `shift`
