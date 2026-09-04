# OmaBoard bar widget

Bar button for [OmaBoard](https://github.com/omacom-io/omaboard). The glyph is
a drawn whiteboard (board + ink), not a nerd-font presentation stand.

| Click | Action |
| ----- | ------ |
| Left | Recents — new board, search, open a saved board |
| Middle | New board |
| Right | Open the app |

`N` starts a new board, `/` jumps to search. Recents is one row per board
(newest file wins if the same name exists in both vault and local).

## Install

```bash
cp -r integrations/omarchy-bar ~/.config/omarchy/plugins/oxhenri.omaboard
```

Then add `{"id": "oxhenri.omaboard"}` to a `bar.layout` section in
`~/.config/omarchy/shell.json`. Saved plugin files hot-reload.

The `omaboard` launcher must be on `PATH` (see the app README). Repeat
clicks focus the existing window instead of spawning another.
