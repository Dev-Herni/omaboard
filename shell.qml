//@pragma ShellId org.omarchy.omaboard
import QtQuick
import Quickshell
import Quickshell.Io
import "ExcalidrawIO.js" as IO

// NOTE: components are instantiated via Loader URL sources instead of direct
// type names. With a directory qmldir present, implicit same-dir type
// registration races under quickshell (one random type per boot resolves as
// "is not a type"); Loader-by-URL bypasses type lookup and is deterministic.
ShellRoot {
    id: app

    // ------------------------------------------------------------------
    // State (docs/CONTRACTS.md "shell.qml owns")
    // ------------------------------------------------------------------
    property string activeTool: "select"
    property color strokeColor: Theme.foreground
    property bool userSetStroke: false
    property color fillColor: "transparent"
    property bool showGrid: false
    property bool showHelp: false
    property string currentPath: ""
    property string boardTitle: "Untitled board"
    property bool dirty: false
    property string createdISO: ""

    // Loaded component instances (null until Loader completes; all local-file
    // loaders resolve synchronously during startup).
    readonly property QtObject model: modelLoader.item
    readonly property var canvas: canvasLoader.item
    readonly property var toolbar: toolbarLoader.item
    readonly property var pickerItem: pickerLoader.item

    readonly property bool typing: canvas !== null && canvas._editingEl !== null
    readonly property bool overlayOpen: (pickerItem !== null && pickerItem.visible) || showHelp
    readonly property string windowTitle: (dirty ? "\u25CF " : "") + boardTitle + " \u2014 OmaBoard"

    // ------------------------------------------------------------------
    // Paths / config
    // ------------------------------------------------------------------
    readonly property string homeDir: (Quickshell.env("HOME") && Quickshell.env("HOME").length > 0)
                                      ? Quickshell.env("HOME") : "/tmp"
    property string vaultDir: homeDir + "/OxHenri Vault/Whiteboards"
    property string localDir: homeDir + "/Documents/Whiteboards"
    readonly property string configPath: homeDir + "/.config/omaboard/config.json"
    readonly property string cacheDir: homeDir + "/.cache/omaboard"
    readonly property string draftPath: cacheDir + "/draft.md"

    property string pendingLoadKind: ""   // "" | "file" | "draft"
    property string pendingLoadPath: ""

    function expandHome(p) {
        if (typeof p !== "string" || p.length === 0)
            return p;
        if (p === "~")
            return homeDir;
        if (p.indexOf("~/") === 0)
            return homeDir + p.substring(1);
        return p;
    }

    function applyConfig(text) {
        try {
            var cfg = JSON.parse(text);
            if (cfg && typeof cfg === "object" && !Array.isArray(cfg)) {
                if (typeof cfg.vaultDir === "string" && cfg.vaultDir.length > 0)
                    vaultDir = expandHome(cfg.vaultDir);
                if (typeof cfg.localDir === "string" && cfg.localDir.length > 0)
                    localDir = expandHome(cfg.localDir);
            }
        } catch (e) {
            // malformed config -> keep defaults
        }
        ensureDirs();
    }

    FileView {
        id: configView

        path: app.configPath
        printErrors: false
        watchChanges: false
        onLoaded: app.applyConfig(configView.text())
    }

    // ------------------------------------------------------------------
    // Small helpers
    // ------------------------------------------------------------------
    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function timestamp() {
        var d = new Date();
        return d.getFullYear() + pad2(d.getMonth() + 1) + pad2(d.getDate())
             + "-" + pad2(d.getHours()) + pad2(d.getMinutes()) + pad2(d.getSeconds());
    }

    function slugify(t) {
        var s = String(t === undefined || t === null ? "" : t).toLowerCase()
                .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        return s.length > 0 ? s : "board";
    }

    function basename(p) {
        var i = p.lastIndexOf("/");
        return i >= 0 ? p.substring(i + 1) : p;
    }

    function toastMsg(msg, kind) {
        if (toastLoader.item)
            toastLoader.item.show(msg, kind);
    }

    // ------------------------------------------------------------------
    // Scene actions (shared by shortcuts + toolbar.action)
    // ------------------------------------------------------------------
    function setTool(t) {
        activeTool = t;
    }

    function undo() {
        if (model)
            model.undo();
    }

    function redo() {
        if (model)
            model.redo();
    }

    function deleteSelection() {
        if (!model || model.selectedIds.length === 0)
            return;
        model.pushUndo();
        model.deleteSelection();
    }

    function duplicateSelection() {
        if (!model || model.selectedIds.length === 0)
            return;
        model.pushUndo();
        model.duplicateSelection();
    }

    function bringForwardSel() {
        if (!model || model.selectedIds.length === 0)
            return;
        model.pushUndo();
        model.bringForward(model.selectedIds.slice());
    }

    function sendBackwardSel() {
        if (!model || model.selectedIds.length === 0)
            return;
        model.pushUndo();
        model.sendBackward(model.selectedIds.slice());
    }

    function toggleGrid() {
        showGrid = !showGrid;
    }

    function toggleHelp() {
        showHelp = !showHelp;
    }

    function openPicker() {
        if (pickerItem)
            pickerItem.open();
    }

    function newBoard() {
        if (model)
            model.loadFromJson({ elements: [] });
        currentPath = "";
        boardTitle = "Untitled board";
        createdISO = "";
        dirty = false;
        removeDraft();
        toastMsg("New board", "info");
    }

    // ------------------------------------------------------------------
    // Serialize / save / load
    // ------------------------------------------------------------------
    function buildMarkdown() {
        var nowISO = new Date().toISOString();
        if (createdISO.length === 0)
            createdISO = nowISO;
        var els = model ? model.elements : [];
        return IO.serialize(els, {
                                title: boardTitle,
                                createdISO: createdISO,
                                modifiedISO: nowISO,
                                viewBackgroundColor: Theme.background.toString()
                            });
    }

    function saveInPlace() {
        var path = currentPath.length > 0 ? currentPath
                                          : localDir + "/" + slugify(boardTitle) + "-" + timestamp() + ".md";
        currentPath = path;
        saveWriter.writeAtomic(path, buildMarkdown(), function(ok) {
            if (ok) {
                dirty = false;
                removeDraft();
                toastMsg("Saved " + basename(path), "ok");
            } else {
                toastMsg("Save failed: " + basename(path), "warn");
            }
        });
    }

    function saveToVault() {
        var base = currentPath.length > 0 ? basename(currentPath)
                                          : slugify(boardTitle) + "-" + timestamp() + ".md";
        saveWriter.writeAtomic(vaultDir + "/" + base, buildMarkdown(), function(ok) {
            if (ok) {
                dirty = false;
                removeDraft();
                toastMsg("Saved to vault \u2302", "ok");
            } else {
                toastMsg("Vault save failed: " + base, "warn");
            }
        });
    }

    function loadFromMd(md, path) {
        var res = IO.parse(md);
        if (!res) {
            toastMsg("Not an OmaBoard/excalidraw file", "warn");
            return false;
        }
        if (model)
            model.loadFromJson({ elements: res.elements });
        boardTitle = (typeof res.title === "string" && res.title.length > 0) ? res.title : "Untitled board";
        if (typeof path === "string" && path.length > 0)
            currentPath = path;
        dirty = false;
        return true;
    }

    function loadFromPath(p) {
        pendingLoadKind = "file";
        pendingLoadPath = p;
        loaderView.path = p;
        loaderView.reload();
    }

    function writeDraftNow() {
        draftWriter.writeAtomic(draftPath, buildMarkdown(), null);
    }

    function tryRestoreDraft() {
        pendingLoadKind = "draft";
        loaderView.path = draftPath;
        loaderView.reload();
    }

    function removeDraft() {
        rmProc.exec(["rm", "-f", draftPath]);
    }

    function ensureDirs() {
        mkdirProc.exec(["mkdir", "-p", localDir, vaultDir, cacheDir]);
    }

    function checkDraft() {
        statProc.exec(["sh", "-c", 'stat -c %Y -- "$1" 2>/dev/null', "sh", draftPath]);
    }

    // ------------------------------------------------------------------
    // Processes / IO plumbing
    // ------------------------------------------------------------------
    component AtomicWriter: Process {
        id: aw

        property var _queue: []
        property var _current: null
        property bool _busy: false

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        function writeAtomic(path, content, cb) {
            _queue.push({ p: path, c: content, cb: cb });
            _pump();
        }

        function _pump() {
            if (_busy || _queue.length === 0)
                return;
            _busy = true;
            var job = _queue.shift();
            _current = job;
            stdinEnabled = true;
            exec(["sh", "-c", 'cat > "$1.tmp" && mv -f "$1.tmp" "$1"', "sh", job.p]);
            write(job.c);
            stdinEnabled = false;
        }

        onExited: function(exitCode, exitStatus) {
            var job = _current;
            _current = null;
            if (job && job.cb)
                job.cb(exitCode === 0);
            _busy = false;
            _pump();
        }
    }

    AtomicWriter {
        id: saveWriter
    }

    AtomicWriter {
        id: draftWriter
    }

    Process {
        id: mkdirProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: rmProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: statProc

        stdout: StdioCollector {
            id: statOut
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                return;
            var mt = parseInt(statOut.text.trim());
            var now = Date.now() / 1000;
            if (!isNaN(mt) && (now - mt) <= 60)
                tryRestoreDraft();
        }
    }

    FileView {
        id: loaderView

        printErrors: false
        watchChanges: false

        onLoaded: {
            var md = loaderView.text();
            var kind = pendingLoadKind;
            pendingLoadKind = "";
            if (kind === "draft") {
                if (loadFromMd(md, ""))
                    toastMsg("Draft recovered", "info");
            } else if (kind === "file") {
                if (loadFromMd(md, pendingLoadPath))
                    toastMsg("Opened " + basename(pendingLoadPath), "info");
            }
        }

        onLoadFailed: function(error) {
            pendingLoadKind = "";
            toastMsg("Could not read file", "warn");
        }
    }

    // ------------------------------------------------------------------
    // Window + layout
    // ------------------------------------------------------------------
    FloatingWindow {
        id: win

        title: app.windowTitle
        visible: true
        implicitWidth: 1200
        implicitHeight: 800
        color: Theme.background

        Loader {
            id: canvasLoader

            anchors.fill: parent
            source: "BoardCanvas.qml"
            onLoaded: {
                item.model = Qt.binding(function() { return app.model; });
                item.activeTool = Qt.binding(function() { return app.activeTool; });
                item.strokeColor = Qt.binding(function() { return app.strokeColor; });
                item.fillColor = Qt.binding(function() { return app.fillColor; });
                item.showGrid = Qt.binding(function() { return app.showGrid; });
            }
        }

        Loader {
            id: toolbarLoader

            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            source: "Toolbar.qml"
            onLoaded: {
                item.activeTool = Qt.binding(function() { return app.activeTool; });
                item.strokeColor = Qt.binding(function() { return app.strokeColor; });
                item.fillColor = Qt.binding(function() { return app.fillColor; });
                item.canUndo = Qt.binding(function() { return app.model ? app.model.canUndo : false; });
                item.canRedo = Qt.binding(function() { return app.model ? app.model.canRedo : false; });
                item.dirty = Qt.binding(function() { return app.dirty; });
                item.showGrid = Qt.binding(function() { return app.showGrid; });
                item.boardTitle = Qt.binding(function() { return app.boardTitle; });
            }
        }

        Loader {
            id: toastLoader

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 640
            height: 150
            source: "Toast.qml"
        }

        Loader {
            id: bottomLeftLoader

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 16
            anchors.bottomMargin: 14
            source: "BottomLeftBar.qml"
        }

        Loader {
            id: pickerLoader

            anchors.fill: parent
            source: "BoardPicker.qml"
            onLoaded: {
                item.vaultDir = Qt.binding(function() { return app.vaultDir; });
                item.localDir = Qt.binding(function() { return app.localDir; });
            }
        }

        Loader {
            id: helpLoader

            anchors.fill: parent
            source: "HelpOverlay.qml"
            onLoaded: {
                item.visible = Qt.binding(function() { return app.showHelp; });
            }
        }

        // --------------------------------------------------------------
        // Outbound wiring (loaded components -> app state)
        // --------------------------------------------------------------
        Connections {
            target: app.canvas

            function onBoardModified() {
                app.dirty = true;
            }
            function onRequestTool(tool) {
                app.setTool(tool);
            }
        }

        Connections {
            target: app.toolbar

            function onToolPicked(tool) {
                app.setTool(tool);
            }
            function onStrokePicked(c) {
                app.userSetStroke = true;
                app.strokeColor = c;
            }
            function onFillPicked(c) {
                app.fillColor = c;
            }
            function onAction(name) {
                switch (name) {
                case "new":
                    app.newBoard();
                    break;
                case "open":
                    app.openPicker();
                    break;
                case "save":
                    app.saveInPlace();
                    break;
                case "vault":
                    app.saveToVault();
                    break;
                case "undo":
                    app.undo();
                    break;
                case "redo":
                    app.redo();
                    break;
                case "grid":
                    app.toggleGrid();
                    break;
                case "fit":
                    if (app.canvas)
                        app.canvas.fitToContent();
                    break;
                case "help":
                    app.toggleHelp();
                    break;
                }
            }
        }

        Connections {
            target: bottomLeftLoader.item

            function onOpenRequested() {
                app.openPicker();
            }
            function onHelpRequested() {
                app.toggleHelp();
            }
        }

        Connections {
            target: app.pickerItem

            function onPicked(path) {
                app.closePicker();
                app.loadFromPath(path);
            }
            function onDismissed() {
                app.closePicker();
            }
        }

        Connections {
            target: helpLoader.item

            function onDismissed() {
                app.showHelp = false;
            }
        }

        // --------------------------------------------------------------
        // Shortcuts (window context; gated while typing / overlay open)
        // --------------------------------------------------------------
        readonly property bool gateAll: !app.typing && !app.overlayOpen
        readonly property bool gateTyping: !app.typing

        Shortcut {
            sequence: "1"
            enabled: win.gateAll
            onActivated: app.setTool("select")
        }
        Shortcut {
            sequence: "2"
            enabled: win.gateAll
            onActivated: app.setTool("rectangle")
        }
        Shortcut {
            sequence: "3"
            enabled: win.gateAll
            onActivated: app.setTool("ellipse")
        }
        Shortcut {
            sequence: "4"
            enabled: win.gateAll
            onActivated: app.setTool("diamond")
        }
        Shortcut {
            sequence: "5"
            enabled: win.gateAll
            onActivated: app.setTool("arrow")
        }
        Shortcut {
            sequence: "6"
            enabled: win.gateAll
            onActivated: app.setTool("line")
        }
        Shortcut {
            sequence: "7"
            enabled: win.gateAll
            onActivated: app.setTool("draw")
        }
        Shortcut {
            sequence: "8"
            enabled: win.gateAll
            onActivated: app.setTool("text")
        }
        Shortcut {
            sequence: "9"
            enabled: win.gateAll
            onActivated: app.setTool("eraser")
        }

        Shortcut {
            sequence: "Ctrl+S"
            enabled: win.gateTyping
            onActivated: app.saveInPlace()
        }
        Shortcut {
            sequence: "Ctrl+Shift+S"
            enabled: win.gateTyping
            onActivated: app.saveToVault()
        }
        Shortcut {
            sequence: "Ctrl+O"
            enabled: win.gateTyping
            onActivated: app.openPicker()
        }
        Shortcut {
            sequence: "Ctrl+N"
            enabled: win.gateTyping
            onActivated: app.newBoard()
        }

        Shortcut {
            sequence: "Ctrl+Z"
            enabled: win.gateAll
            onActivated: app.undo()
        }
        Shortcut {
            sequence: "Ctrl+Y"
            enabled: win.gateAll
            onActivated: app.redo()
        }
        Shortcut {
            sequence: "Delete"
            enabled: win.gateAll
            onActivated: app.deleteSelection()
        }
        Shortcut {
            sequence: "Backspace"
            enabled: win.gateAll
            onActivated: app.deleteSelection()
        }
        Shortcut {
            sequence: "Ctrl+D"
            enabled: win.gateAll
            onActivated: app.duplicateSelection()
        }
        Shortcut {
            sequence: "Ctrl+]"
            enabled: win.gateAll
            onActivated: app.bringForwardSel()
        }
        Shortcut {
            sequence: "Ctrl+["
            enabled: win.gateAll
            onActivated: app.sendBackwardSel()
        }

        Shortcut {
            sequence: "+"
            enabled: win.gateAll
            onActivated: if (app.canvas) app.canvas.zoomBy(1.25)
        }
        Shortcut {
            sequence: "-"
            enabled: win.gateAll
            onActivated: if (app.canvas) app.canvas.zoomBy(0.8)
        }
        Shortcut {
            sequence: "="
            enabled: win.gateAll
            onActivated: if (app.canvas) app.canvas.fitToContent()
        }
        Shortcut {
            sequence: "F"
            enabled: win.gateAll
            onActivated: if (app.canvas) app.canvas.fitToContent()
        }
        Shortcut {
            sequence: "Ctrl+0"
            enabled: win.gateAll
            onActivated: if (app.canvas) app.canvas.resetZoom()
        }

        Shortcut {
            sequence: "G"
            enabled: win.gateAll
            onActivated: app.toggleGrid()
        }
        Shortcut {
            sequence: "?"
            enabled: win.gateTyping
            onActivated: app.toggleHelp()
        }

        // Esc cascade: overlays close themselves (focus-based) > text edit
        // cancels internally (BoardCanvas TextArea) > here: deselect + reset tool.
        Shortcut {
            sequence: "Esc"
            enabled: win.gateAll
            onActivated: {
                if (app.model)
                    app.model.clearSelection();
                app.setTool("select");
            }
        }
    }

    function closePicker() {
        if (pickerItem)
            pickerItem.close();
    }

    // ------------------------------------------------------------------
    // Model + Theme coupling + diagnostics
    // ------------------------------------------------------------------
    Loader {
        id: modelLoader

        source: "SceneModel.qml"
        onLoaded: {
            // Wire model mutations to canvas repaints here: a static Connections
            // inside BoardCanvas would evaluate against the not-yet-loaded target.
            if (item && item.sceneChanged)
                item.sceneChanged.connect(function() {
                    if (canvas)
                        canvas.repaint();
                });
        }
    }

    Connections {
        target: Theme
        function onThemeChanged() {
            if (!app.userSetStroke)
                app.strokeColor = Theme.foreground;
            console.log("THEME:", Theme.name, Theme.accent.toString());
        }
    }

    // ------------------------------------------------------------------
    // Startup sequence
    // ------------------------------------------------------------------
    Timer {
        id: startupTimer

        interval: 350
        running: true
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            ensureDirs();
            checkDraft();
        }
    }

    Timer {
        id: autosaveTimer

        interval: 30000
        running: app.dirty
        repeat: true
        triggeredOnStart: false
        onTriggered: writeDraftNow()
    }

    // ==== INTEGRATION-HARNESS-SLOT ====
}
