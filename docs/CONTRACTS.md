# OmaBoard Component Contracts

All agents MUST follow these interfaces exactly. Flat file layout: all `.qml`/`.js` live in the repo root (same-dir type resolution, no imports needed for components).

## Runtime
- Quickshell 0.3.0 (`qs -p <repo-root>`), Qt6 QML, Wayland/Hyprland.
- Entry: `shell.qml` at root.
- JS engine is modern ES but keep conservative syntax (no decorators; `??`/`?.` OK).

## Theme.qml  (pragma Singleton + qmldir)
Reads `~/.local/state/omarchy/current/theme/colors.toml` and `theme.name`, live-reloads on change.
Because omarchy atomically swaps the theme dir, ALSO watch `theme.name`; on any change re-resolve and re-read colors path.

```qml
pragma Singleton
import Quickshell.Io   // FileView; if watchChanges misbehaves, fallback Timer(1500ms)->reload()
// properties:
property string name        // theme slug from theme.name
property bool dark          // colors.toml mode == "dark"
property color background   // canvas bg
property color darkBackground
property color darkerBackground
property color lighterBackground
property color foreground   // default stroke/text
property color darkForeground
property color lightForeground
property color brightForeground
property color accent       // selection/highlight
property color selection
property color muted        // grid/handles
property color red, yellow, orange, green, cyan, blue, magenta, brown
readonly property var palette  // [{name:"accent",c:color}, red, yellow, green, cyan, blue, magenta, foreground]
signal themeChanged()          // emitted after any re-read
```
colors.toml keys (flat `key = "#hex"`, plus `mode = "dark"|"light"`): mode accent selection muted background dark_background darker_background lighter_background foreground dark_foreground light_foreground bright_foreground red yellow orange green cyan blue magenta brown bright_* variants. Parse with simple regex per line; ignore unknown keys.

## Element model (plain JS objects, excalidraw-compatible field names)
Common: `{ id, type, x, y, width, height, angle:0, strokeColor, backgroundColor,
fillStyle:"solid", strokeWidth:2, roughness:0, opacity:100, seed, version,
groupIds:[], frameId:null, roundness:null, isDeleted:false, updated }`
- `rect→type:"rectangle"`, `"ellipse"`, `"diamond"`: bbox only.
- `"line" | "arrow" | "draw"`: + `points:[[rx,ry],...]` RELATIVE to x,y;
  arrow also `startArrowhead:null, endArrowhead:null`.
- `"text"`: + `text, fontSize:20, fontFamily:1, textAlign:"left", containerId:null, lineHeight:1.25`.

## SceneModel.qml  (QtObject)
```qml
property var elements: []            // array of element objects
property var selectedIds: []         // array of id strings
signal sceneChanged()                // after any mutation
signal historyChanged()              // canUndo/canRedo flip
readonly property bool canUndo / canRedo
function addElement(el) -> el
function updateElement(id, patch)    // merges, bumps version+updated
function removeElements(ids)
function getElement(id)
function hitTest(wx, wy)             // topmost element or null
function selectOnly(id) / clearSelection()
function pushUndo()                  // snapshot BEFORE a mutation batch
function undo() / redo()
function toJson(appState)            // excalidraw scene object
function loadFromJson(sceneObj)      // replaces contents
```

## BoardCanvas.qml  (Item)
```qml
property var model                   // SceneModel
property string activeTool           // "select"|"rectangle"|"ellipse"|"diamond"|"arrow"|"line"|"draw"|"text"|"eraser"
property color strokeColor / fillColor
property real zoom / panX / panY     // world->screen: sx = (wx*zoom)+panX
signal boardModified()               // any committed mutation (dirty flag)
signal elementTextCommitted(el)
function fitToContent()
function resetZoom()                 // zoom=1, pan centers origin
function zoomBy(factor)
function worldFromScreen(sx, sy) / screenFromWorld(wx, wy)
```
Owns its MouseAreas, in-progress draw ghosting, resize handles (4 corners), text editing overlay (TextArea; Enter=newline, Esc or focus-loss commits via updateElement), eraser drag, space/middle-drag pan, wheel zoom. Grid drawn when `showGrid` true (property). All colors from Theme singleton.

## ExcalidrawIO.js  (`.pragma library`)
```js
.pragma library
function makeElement(type, props)    // fills all contract defaults incl random seed
function serialize(elements, meta)   // meta:{title, createdISO, modifiedISO, viewBackgroundColor}
                                     // -> markdown string (format below)
function parse(markdownString)       // -> {elements:[...], appState:{...}, title} | null
```
Markdown format (Obsidian-Excalidraw-plugin compatible "parsed" layout):
```
---
excalidraw-plugin: parsed
tags: [excalidraw]
title: <title>
created: <ISO>
modified: <ISO>
---
==ⓘ Edit these boards in OmaBoard==

# Excalidraw Data

## Text Elements
<one line per text element content>      ← plain text so Obsidian search finds it

## Drawing
```json
{ "type":"excalidraw", "version":2, "source":"omaboard",
  "elements":[...], "appState":{"viewBackgroundColor":"...", "gridSize":null}, "files":{} }
```
```
Parser: frontmatter optional-tolerant; find fenced ```json block after `## Drawing`; JSON.parse; tolerate missing fields via defaults.

## Toolbar.qml  (Item, floating pill)
```qml
property string activeTool
property color strokeColor / fillColor
property bool canUndo / canRedo / dirty / showGrid
property string boardTitle
signal toolPicked(string tool)
signal strokePicked(color c) / fillPicked(color c)
signal action(string name)   // "new"|"open"|"save"|"vault"|"undo"|"redo"|"grid"|"fit"|"help"
```
Icons = Unicode geometric glyphs (no font deps): ▭ ◯ ◇ ╱ ➚ ✎ 𝐀 ▩ ⌫ etc. First cluster is New + Open. Swatches from Theme.palette popover. Tooltips w/ shortcut hints.

## shell.qml owns
FloatingWindow (title `● title — OmaBoard` dirty dot, app-id org.omarchy.omaboard), SceneModel{id:model}, BoardCanvas{id:canvas}, Toolbar anchored top-center, Toast overlay, Help overlay (? key), board picker panel (lists localDir + vaultDir .md files), Shortcuts, save/load logic, config (~/.config/omaboard/config.json → {vaultDir, localDir}; defaults: `~/OxHenri Vault/Whiteboards`, `~/Documents/Whiteboards`), autosave draft timer (30s → ~/.cache/omaboard/draft.md, restore prompt on launch).

Shortcuts: 1..9 tools · Ctrl+S save-in-place · Ctrl+Shift+S vault-save · Ctrl+O open picker · Ctrl+N new · Ctrl+Z/Y/Ctrl+Shift+Z undo redo · Del delete · Ctrl+D duplicate · Ctrl+] z-forward · Ctrl+[ z-back · +/- zoom · = fit · G grid · ? help · Esc deselect/tool-reset.

Launcher (`bin/omaboard`): if an instance is already running, `qs ipc -p <root> call omaboard …` (targets: `focus`, `newBoard`, `picker`, `openFile(path)`, `ping`) and exit. Otherwise launch with `OMABOARD_ACTION` / `OMABOARD_PATH`. Flags: `--new`, `--picker`, `--open PATH`, `--status`.

IpcHandler `{ target: "omaboard" }` lives on ShellRoot. `focusWindow()` raises the FloatingWindow and `hyprctl dispatch focuswindow title:OmaBoard`.

Draft restore window is 7 days (`~/.cache/omaboard/draft.md`).

## Verification every agent must run
`timeout 12 qs -p ~/Projects/Omarchy/omaboard 2>&1 | grep -iE "error|warning|cannot|failed"` → must be empty (or explain). Window may flash on desktop — fine. Also `qmllint *.qml` — fix errors, ignore style warnings.
NO git commands by agents. Do not edit files outside your scope.
