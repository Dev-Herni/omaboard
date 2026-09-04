import QtQuick
import "ExcalidrawIO.js" as IO

QtObject {
    id: root

    property var elements: []
    property var selectedIds: []

    signal sceneChanged()
    signal historyChanged()

    readonly property bool canUndo: _undoStack.length > 0
    readonly property bool canRedo: _redoStack.length > 0

    property var _undoStack: []
    property var _redoStack: []
    property bool _batching: false
    readonly property int _hitPad: 4
    readonly property int _maxHistory: 100

    function beginBatch() {
        if (root._batching)
            return;
        root._batching = true;
        root._takeSnapshot();
    }

    function endBatch() {
        root._batching = false;
    }

    function _takeSnapshot() {
        var stack = root._undoStack.slice();
        stack.push(JSON.parse(JSON.stringify(root.elements)));
        if (stack.length > root._maxHistory)
            stack.shift();
        root._undoStack = stack;
        root._redoStack = [];
        root.historyChanged();
    }

    function pushUndo() {
        if (root._batching)
            return;
        root._takeSnapshot();
    }

    function undo() {
        if (root._undoStack.length === 0)
            return;
        var ustack = root._undoStack.slice();
        var snap = ustack.pop();
        root._undoStack = ustack;
        var rstack = root._redoStack.slice();
        rstack.push(JSON.parse(JSON.stringify(root.elements)));
        if (rstack.length > root._maxHistory)
            rstack.shift();
        root._redoStack = rstack;
        root.elements = snap;
        root.selectedIds = [];
        root.sceneChanged();
        root.historyChanged();
    }

    function redo() {
        if (root._redoStack.length === 0)
            return;
        var rstack = root._redoStack.slice();
        var snap = rstack.pop();
        root._redoStack = rstack;
        var ustack = root._undoStack.slice();
        ustack.push(JSON.parse(JSON.stringify(root.elements)));
        if (ustack.length > root._maxHistory)
            ustack.shift();
        root._undoStack = ustack;
        root.elements = snap;
        root.selectedIds = [];
        root.sceneChanged();
        root.historyChanged();
    }

    function getElement(id) {
        var els = root.elements;
        for (var i = 0; i < els.length; i++)
            if (els[i].id === id)
                return els[i];
        return null;
    }

    function addElement(el) {
        if (!el || typeof el.type !== "string")
            return null;
        var norm = IO.makeElement(el.type, el);
        var arr = root.elements.slice();
        arr.push(norm);
        root.elements = arr;
        root.sceneChanged();
        return norm;
    }

    function updateElement(id, patch) {
        var el = root.getElement(id);
        if (!el || !patch)
            return;
        for (var k in patch) {
            if (!Object.prototype.hasOwnProperty.call(patch, k))
                continue;
            var v = patch[k];
            el[k] = Array.isArray(v) ? JSON.parse(JSON.stringify(v)) : v;
        }
        el.version = (typeof el.version === "number" ? el.version : 0) + 1;
        el.updated = Date.now();
        root.sceneChanged();
    }

    function removeElements(ids) {
        if (!ids || ids.length === 0)
            return;
        var gone = {};
        for (var i = 0; i < ids.length; i++)
            gone[ids[i]] = true;
        var kept = [];
        var els = root.elements;
        for (var j = 0; j < els.length; j++)
            if (!gone[els[j].id])
                kept.push(els[j]);
        root.elements = kept;
        var sel = [];
        for (var s = 0; s < root.selectedIds.length; s++)
            if (!gone[root.selectedIds[s]])
                sel.push(root.selectedIds[s]);
        root.selectedIds = sel;
        root.sceneChanged();
    }

    function deleteSelection() {
        root.removeElements(root.selectedIds.slice());
    }

    function _textBounds(el) {
        var lines = String(el.text || "").split("\n");
        var maxLen = 1;
        for (var i = 0; i < lines.length; i++)
            maxLen = Math.max(maxLen, lines[i].length);
        var fs = typeof el.fontSize === "number" ? el.fontSize : 20;
        var lh = typeof el.lineHeight === "number" ? el.lineHeight : 1.25;
        return { width: maxLen * fs * 0.6, height: lines.length * fs * lh };
    }

    function elementBounds(el) {
        if (el.points) {
            var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            for (var i = 0; i < el.points.length; i++) {
                var px = el.x + el.points[i][0];
                var py = el.y + el.points[i][1];
                if (px < minX) minX = px;
                if (py < minY) minY = py;
                if (px > maxX) maxX = px;
                if (py > maxY) maxY = py;
            }
            if (minX === Infinity)
                return { x: el.x, y: el.y, width: el.width, height: el.height };
            return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
        }
        if (el.type === "text") {
            var tb = root._textBounds(el);
            return { x: el.x, y: el.y, width: tb.width, height: tb.height };
        }
        return { x: el.x, y: el.y, width: el.width, height: el.height };
    }

    function _segDist(px, py, ax, ay, bx, by) {
        var dx = bx - ax, dy = by - ay;
        var lenSq = dx * dx + dy * dy;
        var t = lenSq === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / lenSq;
        t = Math.max(0, Math.min(1, t));
        var ex = px - (ax + t * dx);
        var ey = py - (ay + t * dy);
        return Math.sqrt(ex * ex + ey * ey);
    }

    function _hitsElement(el, wx, wy) {
        if (el.type === "line" || el.type === "arrow" || el.type === "draw") {
            var thresh = Math.max(8, (typeof el.strokeWidth === "number" ? el.strokeWidth : 2) * 3);
            var pts = el.points;
            if (!pts || pts.length === 0)
                return false;
            if (pts.length === 1)
                return Math.sqrt(Math.pow(wx - (el.x + pts[0][0]), 2)
                                 + Math.pow(wy - (el.y + pts[0][1]), 2)) <= thresh;
            for (var i = 0; i < pts.length - 1; i++)
                if (root._segDist(wx, wy,
                                  el.x + pts[i][0], el.y + pts[i][1],
                                  el.x + pts[i + 1][0], el.y + pts[i + 1][1]) <= thresh)
                    return true;
            return false;
        }
        var pad = root._hitPad;
        var b = root.elementBounds(el);
        if (wx < b.x - pad || wx > b.x + b.width + pad
                || wy < b.y - pad || wy > b.y + b.height + pad)
            return false;
        if (el.type === "diamond" || el.type === "ellipse") {
            var rw = Math.max(b.width / 2 + pad, 0.5);
            var rh = Math.max(b.height / 2 + pad, 0.5);
            var dx = (wx - (b.x + b.width / 2)) / rw;
            var dy = (wy - (b.y + b.height / 2)) / rh;
            if (el.type === "ellipse")
                return dx * dx + dy * dy <= 1;
            return Math.abs(dx) + Math.abs(dy) <= 1;
        }
        return true;
    }

    function hitTest(wx, wy) {
        var els = root.elements;
        for (var i = els.length - 1; i >= 0; i--) {
            var el = els[i];
            if (el.isDeleted)
                continue;
            if (root._hitsElement(el, wx, wy))
                return el;
        }
        return null;
    }

    function hitTestAll(wx, wy) {
        var out = [];
        var els = root.elements;
        for (var i = els.length - 1; i >= 0; i--) {
            var el = els[i];
            if (el.isDeleted)
                continue;
            if (root._hitsElement(el, wx, wy))
                out.push(el);
        }
        return out;
    }

    function clearSelection() {
        if (root.selectedIds.length === 0)
            return;
        root.selectedIds = [];
        root.sceneChanged();
    }

    function selectOnly(id) {
        if (root.selectedIds.length === 1 && root.selectedIds[0] === id)
            return;
        root.selectedIds = [id];
        root.sceneChanged();
    }

    function toggleSelect(id) {
        var sel = root.selectedIds.slice();
        var idx = sel.indexOf(id);
        if (idx >= 0)
            sel.splice(idx, 1);
        else
            sel.push(id);
        root.selectedIds = sel;
        root.sceneChanged();
    }

    function moveElements(ids, dx, dy) {
        if (!ids || ids.length === 0 || (dx === 0 && dy === 0))
            return;
        var set = {};
        for (var i = 0; i < ids.length; i++)
            set[ids[i]] = true;
        var now = Date.now();
        var arr = root.elements.slice();
        for (var j = 0; j < arr.length; j++) {
            var el = arr[j];
            if (set[el.id]) {
                var copy = JSON.parse(JSON.stringify(el));
                copy.x += dx;
                copy.y += dy;
                copy.version = (typeof el.version === "number" ? el.version : 0) + 1;
                copy.updated = now;
                arr[j] = copy;
            }
        }
        root.elements = arr;
        root.sceneChanged();
    }

    function resizeElement(id, x, y, width, height) {
        var el = root.getElement(id);
        if (!el)
            return null;
        var ow = el.width, oh = el.height;
        el.x = x;
        el.y = y;
        el.width = width;
        el.height = height;
        if (el.points && ow > 0 && oh > 0) {
            var sx = width / ow, sy = height / oh;
            var np = [];
            for (var i = 0; i < el.points.length; i++)
                np.push([el.points[i][0] * sx, el.points[i][1] * sy]);
            el.points = np;
        }
        if (el.type === "text") {
            var tb = root._textBounds(el);
            if (tb.height > 0) {
                var fs = el.fontSize * (height / tb.height);
                el.fontSize = Math.min(96, Math.max(8, Math.round(fs)));
            }
        }
        el.version = (typeof el.version === "number" ? el.version : 0) + 1;
        el.updated = Date.now();
        root.sceneChanged();
        return el;
    }

    function duplicateSelection() {
        var newIds = [];
        var sel = root.selectedIds.slice();
        var arr = root.elements.slice();
        for (var i = 0; i < sel.length; i++) {
            var el = root.getElement(sel[i]);
            if (!el)
                continue;
            var copy = JSON.parse(JSON.stringify(el));
            delete copy.id;
            delete copy.seed;
            copy.x += 16;
            copy.y += 16;
            copy.version = 1;
            copy.updated = Date.now();
            var dup = IO.makeElement(el.type, copy);
            arr.push(dup);
            newIds.push(dup.id);
        }
        if (newIds.length > 0) {
            root.elements = arr;
            root.selectedIds = newIds;
            root.sceneChanged();
        }
        return newIds;
    }

    function _indexOfElement(id) {
        for (var i = 0; i < root.elements.length; i++)
            if (root.elements[i].id === id)
                return i;
        return -1;
    }

    function bringForward(ids) {
        if (!ids || ids.length === 0)
            return;
        var moved = false;
        for (var i = 0; i < ids.length; i++) {
            var idx = root._indexOfElement(ids[i]);
            if (idx >= 0 && idx < root.elements.length - 1) {
                var tmp = root.elements[idx];
                root.elements[idx] = root.elements[idx + 1];
                root.elements[idx + 1] = tmp;
                moved = true;
            }
        }
        if (moved)
            root.sceneChanged();
    }

    function sendBackward(ids) {
        if (!ids || ids.length === 0)
            return;
        var moved = false;
        for (var i = 0; i < ids.length; i++) {
            var idx = root._indexOfElement(ids[i]);
            if (idx > 0) {
                var tmp = root.elements[idx];
                root.elements[idx] = root.elements[idx - 1];
                root.elements[idx - 1] = tmp;
                moved = true;
            }
        }
        if (moved)
            root.sceneChanged();
    }

    function toJson(appState) {
        var els = [];
        for (var i = 0; i < root.elements.length; i++)
            if (!root.elements[i].isDeleted)
                els.push(root.elements[i]);
        var state = { viewBackgroundColor: "transparent", gridSize: null };
        if (appState && typeof appState === "object")
            for (var k in appState)
                if (Object.prototype.hasOwnProperty.call(appState, k))
                    state[k] = appState[k];
        var scene = {
            type: "excalidraw",
            version: 2,
            source: "omaboard",
            elements: JSON.parse(JSON.stringify(els)),
            appState: state,
            files: {}
        };
        return JSON.stringify(scene);
    }

    function loadFromJson(sceneObj) {
        var obj = sceneObj;
        if (typeof obj === "string") {
            try {
                obj = JSON.parse(obj);
            } catch (e) {
                return false;
            }
        }
        if (!obj || typeof obj !== "object" || Array.isArray(obj))
            return false;
        var raw = Array.isArray(obj.elements) ? obj.elements : [];
        var els = [];
        for (var i = 0; i < raw.length; i++) {
            var e = raw[i];
            if (e && typeof e.type === "string")
                els.push(IO.makeElement(e.type, e));
        }
        root.elements = els;
        root.selectedIds = [];
        root._undoStack = [];
        root._redoStack = [];
        root.sceneChanged();
        root.historyChanged();
        return true;
    }
}
