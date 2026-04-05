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
enter_selection = [
  { key = "y", modifiers = ["control"] }
]

[result.window]
template = "{app_name}: {title}"

[result.app]
template = "Open {name}"
```

## Config Keys

| Section | Key | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `trigger` | `key` | `string` | `"tab"` | The key used to open the switcher. |
| `trigger` | `modifiers` | `array<string>` | `["option"]` | Modifier keys pressed with `trigger.key`. |
| `navigation` | `next` | `array<table>` | `[{ key = "j", modifiers = ["control"] }, { key = "n", modifiers = ["control"] }]` | One or more shortcuts that move to the next result. |
| `navigation` | `previous` | `array<table>` | `[{ key = "k", modifiers = ["control"] }, { key = "p", modifiers = ["control"] }]` | One or more shortcuts that move to the previous result. |
| `navigation` | `enter_selection` | `array<table>` | `[{ key = "y", modifiers = ["control"] }]` | One or more shortcuts that enter the currently selected result. |
| `result.window` | `template` | `string` | `"{app_name}: {title}"` | Window row template. Use `{property_name}` placeholders. |
| `result.app` | `template` | `string` | `"Open {name}"` | App row template. Use `{property_name}` placeholders. |

The default navigation bindings add `Control+J` and `Control+N` for next, plus `Control+K` and `Control+P` for previous. Arrow keys still work, and `Tab`
still advances to the next result. `Return` still enters the selected result, and `Control+Y` is configured as an additional default binding.

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
enter_selection = [
  { key = "y", modifiers = ["control"] }
]
```

For backward compatibility, a single binding can still be written as a table:

```toml
[navigation.next]
key = "j"
modifiers = ["control"]
```

## Result List Item Formatting

Window and app rows can be customized independently with `{property_name}` placeholders.

```toml
[result.window]
template = "{title} [{app_name}]"

[result.app]
template = "{name} -> {path}"
```

Supported window properties:

- `app_name`
- `title`
- `name`
- `fqn`
- `id`
- `app_pid`
- `x`
- `y`
- `width`
- `height`

Supported app properties:

- `name`
- `path`

Unknown placeholders are left unchanged.

Frame-based window properties (`x`, `y`, `width`, `height`) resolve to `0` when the window frame is unavailable.

## Supported Modifier Values

- `command`
- `option`
- `control`
- `shift`
