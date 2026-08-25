# OmaBoard

A dead-simple whiteboard that lives in your theme.

<!-- TODO: screenshot of a board floating on an Omarchy desktop -->

## Why

Every whiteboard app fights your desktop. OmaBoard doesn't:

- **Omarchy-native.** A Quickshell/QML FloatingWindow for Hyprland. No Electron, no toolkit chrome.
- **Theme-following.** Recolors itself live when you switch themes. All strokes, fills, grid, and UI come from your current palette.
- **Excalidraw-compatible.** Boards are plain Markdown files the Obsidian Excalidraw plugin opens natively.
- **Obsidian direct-save.** One shortcut drops the board straight into your vault's Whiteboards folder.

## Install

Clone to the expected spot and symlink the launcher:

```sh
git clone https://github.com/omacom-io/omaboard ~/projects/omarchy/omaboard
ln -sf ~/projects/omarchy/omaboard/bin/omaboard ~/.local/bin/
```

Requires [Quickshell](https://quickshell.outfoxxed.me) 0.3.0 or newer (`quickshell-git` or `quickshell`) and a Hyprland/Wayland session. That's it — no build step.

## Usage

Run `omaboard`. Draw. Hit `Ctrl+S` now and then.

Tools (also pickable with keys `1..9`): **select**, **rectangle**, **ellipse**, **diamond**, **arrow**, **line**, **draw**, **text**, **eraser**. Drag with space/middle mouse to pan, scroll to zoom.

### Shortcuts

| Keys         | Action               |
| ------------ | -------------------- |
| `1..9`       | tools                |
| `Ctrl+S`     | save-in-place        |
| `Ctrl+Shift+S` | vault-save         |
| `Ctrl+O`     | open picker          |
| `Ctrl+N`     | new                  |
| `Ctrl+Z` / `Y` | undo / redo        |
| `Del`        | delete               |
| `Ctrl+D`     | duplicate            |
| `Ctrl+]`     | z-forward            |
| `Ctrl+[`     | z-back               |
| `+` / `-`    | zoom                 |
| `=`          | fit                  |
| `G`          | grid                 |
| `?`          | help                 |
| `Esc`        | deselect/tool-reset  |

A draft autosaves to `~/.cache/omaboard/draft.md` every 30 seconds and is offered back on next launch.

## Files

Boards are Obsidian-Excalidraw-plugin-compatible Markdown: YAML frontmatter (`excalidraw-plugin: parsed`), human-readable text elements (so Obsidian search finds them), then the scene JSON in a fenced block under `## Drawing`. Open them in either app; neither corrupts the other.

New boards save in place to `~/Documents/Whiteboards`. `Ctrl+Shift+S` saves into your Obsidian vault at `~/OxHenri Vault/Whiteboards`.

## Configuration

One optional file, two keys — `~/.config/omaboard/config.json`:

```json
{
  "vaultDir": "~/OxHenri Vault/Whiteboards",
  "localDir": "~/Documents/Whiteboards"
}
```

Unset keys fall back to the defaults above.

## How theming works

OmaBoard reads colors from `~/.local/state/omarchy/current/theme/colors.toml` and watches it for changes. Because Omarchy swaps themes by atomically replacing the theme directory, it also watches `theme.name`; when either changes it re-resolves the path and re-reads the palette, so a live theme switch never leaves you drawing on stale colors.

## License

MIT. See [LICENSE](LICENSE).
