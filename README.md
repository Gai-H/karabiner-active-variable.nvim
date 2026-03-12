# karabiner-active-variable.nvim

Set a Karabiner-Elements variable while Neovim is active.

This plugin updates a Karabiner variable to `true` when Neovim is active, and resets it to `false` when Neovim loses focus, is suspended, or exits. It is useful when you want Karabiner rules to behave differently only while working in Neovim.

## Requirements

- macOS
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/)
- Neovim

## Installation

### lazy.nvim

Basic setup:

```lua
{
  "Gai-H/karabiner-active-variable.nvim",
  opts = {}
}
```

With options:

```lua
{
  "Gai-H/karabiner-active-variable.nvim",
  opts = {
    karabiner_variable_name = "neovim_active",
    karabiner_cli_path = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli",
  }
}
```

## Options

| Option | Type | Description | Default |
| --- | --- | --- | --- |
| `karabiner_variable_name` | `string` | Name of the variable | `neovim_active` |
| `karabiner_cli_path` | `string` | Path to the Karabiner-Elements CLI | `/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli` |

## How It Works

The plugin updates the Karabiner variable on these Neovim events:

- `VimEnter`: set `true`
- `FocusGained`: set `true`
- `VimResume`: set `true`
- `FocusLost`: set `false`
- `VimSuspend`: set `false`
- `VimLeavePre`: set `false`

Repeated updates to the same value are skipped.

## Karabiner-Elements Example

You can use the variable in a `variable_if` condition:

```json
{
  "type": "variable_if",
  "name": "neovim_active",
  "value": true
}
```

Example manipulator:

```json
{
  "description": "Use j/k as arrows only while Neovim is active",
  "manipulators": [
    {
      "type": "basic",
      "from": {
        "key_code": "j",
        "modifiers": { "mandatory": ["right_option"], "optional": ["any"] }
      },
      "to": [{ "key_code": "down_arrow" }],
      "conditions": [
        {
          "type": "variable_if",
          "name": "neovim_active",
          "value": true
        }
      ]
    },
    {
      "type": "basic",
      "from": {
        "key_code": "k",
        "modifiers": { "mandatory": ["right_option"], "optional": ["any"] }
      },
      "to": [{ "key_code": "up_arrow" }],
      "conditions": [
        {
          "type": "variable_if",
          "name": "neovim_active",
          "value": true
        }
      ]
    }
  ]
}
```

## Notes

- `FocusGained` and `FocusLost` depend on terminal focus reporting support.
- If `karabiner_cli` is not found or exits with an error, the plugin shows a warning once.
- The variable is boolean, so use `true` and `false` in your Karabiner conditions.
