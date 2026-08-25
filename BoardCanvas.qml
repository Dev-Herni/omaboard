import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var model
    property string activeTool: "select"
    property color strokeColor: Theme.foreground
    property color fillColor: "transparent"
    property real strokeWidth: 2
    property real zoom: 1.0
    property real panX: 0
    property real panY: 0
    property bool showGrid: true
    property bool spaceHeld: false

    signal boardModified()
    signal elementTextCommitted(var el)
    signal requestTool(string tool)

    property string _gesture: "none"
    property var _ghostEl: null
    property var _panLast: null
    property var _pressWorld: null
    property bool _pushedThisGesture: false
    property bool _mutatedThisGesture: false
    property real _lastMoveDx: 0
    property real _lastMoveDy: 0
    property string _resizeHandle: ""
    property var _resizeOrig: null
    property var _freehandPts: []
    property bool _erasePushed: false
    property bool _eraseAny: false
    property var _editingEl: null
    property var _editWorld: null

    readonly property int _gridSpacing: 64
    readonly property int _handleSize: 8

    function worldFromScreen(sx, sy) {
        return { x: (sx - root.panX) / root.zoom, y: (sy - root.panY) / root.zoom };
    }

    function screenFromWorld(wx, wy) {
        return { x: wx * root.zoom + root.panX, y: wy * root.zoom + root.panY };
    }

    function _clamp(v, lo, hi) {
        return Math.min(hi, Math.max(lo, v));
    }

    function cssColor(c, alpha) {
        var a = (alpha === undefined) ? c.a : alpha;
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
               + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
    }

    function resetZoom() {
        root.zoom = 1;
        root.panX = root.width / 2;
        root.panY = root.height / 2;
    }

    function zoomBy(factor) {
        root.zoomAt(root.width / 2, root.height / 2, factor);
    }

    function zoomAt(sx, sy, factor) {
        var nz = root._clamp(root.zoom * factor, 0.1, 8);
        if (nz === root.zoom)
            return;
        var wp = root.worldFromScreen(sx, sy);
        root.zoom = nz;
        root.panX = sx - wp.x * nz;
        root.panY = sy - wp.y * nz;
    }

    function contentBounds() {
        var m = root.model;
        if (!m)
            return null;
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        var any = false;
        var els = m.elements;
        for (var i = 0; i < els.length; i++) {
            if (els[i].isDeleted)
                continue;
            var b = m.elementBounds(els[i]);
            any = true;
            minX = Math.min(minX, b.x);
            minY = Math.min(minY, b.y);
            maxX = Math.max(maxX, b.x + b.width);
            maxY = Math.max(maxY, b.y + b.height);
        }
        if (!any)
            return null;
        return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
    }

    function fitToContent() {
        var b = root.contentBounds();
        if (!b) {
            root.resetZoom();
            return;
        }
        var bw = Math.max(b.width, 16), bh = Math.max(b.height, 16);
        var z = root._clamp(Math.min((root.width - 96) / bw, (root.height - 96) / bh), 0.1, 8);
        root.zoom = z;
        root.panX = (root.width - bw * z) / 2 - b.x * z;
        root.panY = (root.height - bh * z) / 2 - b.y * z;
    }

    function repaint() {
        canvasItem.requestPaint();
    }

    onZoomChanged: repaint()
    onPanXChanged: repaint()
    onPanYChanged: repaint()
    onShowGridChanged: repaint()
    Component.onCompleted: repaint()

    Connections {
        target: root.model
        function onSceneChanged() {
            canvasItem.requestPaint();
        }
    }

    Connections {
        target: Theme
        function onThemeChanged() {
            canvasItem.requestPaint();
        }
    }

    Canvas {
        id: canvasItem

        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.save();
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = root.cssColor(Theme.background, 1);
            ctx.fillRect(0, 0, width, height);
            paintGrid(ctx);
            var els = root.model ? root.model.elements : [];
            for (var i = 0; i < els.length; i++) {
                if (!els[i].isDeleted)
                    drawElement(ctx, els[i]);
            }
            paintSelection(ctx);
            if (root._ghostEl)
                drawElement(ctx, root._ghostEl);
            ctx.restore();
        }
    }

    function paintGrid(ctx) {
        if (!showGrid)
            return;
        var spacing = _gridSpacing * zoom;
        if (spacing < 12)
            return;
        ctx.lineWidth = 1;
        ctx.strokeStyle = cssColor(Theme.muted, 0.25);
        ctx.beginPath();
        var startX = (((panX % spacing) + spacing) % spacing) - spacing;
        for (var x = startX; x < width + spacing; x += spacing) {
            ctx.moveTo(Math.round(x) + 0.5, 0);
            ctx.lineTo(Math.round(x) + 0.5, height);
        }
        var startY = (((panY % spacing) + spacing) % spacing) - spacing;
        for (var y = startY; y < height + spacing; y += spacing) {
            ctx.moveTo(0, Math.round(y) + 0.5);
            ctx.lineTo(width, Math.round(y) + 0.5);
        }
        ctx.stroke();
    }

    function drawElement(ctx, el) {
        ctx.save();
        ctx.globalAlpha = _clamp((typeof el.opacity === "number" ? el.opacity : 100) / 100, 0.05, 1);
        ctx.strokeStyle = el.strokeColor || "#1e1e1e";
        ctx.lineWidth = Math.max(0.5, (typeof el.strokeWidth === "number" ? el.strokeWidth : 2) * zoom);
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        var sx = el.x * zoom + panX;
        var sy = el.y * zoom + panY;
        var bg = el.backgroundColor || "transparent";

        switch (el.type) {
        case "rectangle": {
            var w = el.width * zoom, h = el.height * zoom;
            var rx = Math.min(sx, sx + w), ry = Math.min(sy, sy + h);
            var rw = Math.abs(w), rh = Math.abs(h);
            if (bg !== "transparent") {
                ctx.fillStyle = bg;
                ctx.fillRect(rx, ry, rw, rh);
            }
            ctx.strokeRect(rx, ry, rw, rh);
            break;
        }
        case "ellipse": {
            var ew = Math.max(Math.abs(el.width * zoom), 0.5);
            var eh = Math.max(Math.abs(el.height * zoom), 0.5);
            var ecx = sx + (el.width * zoom) / 2;
            var ecy = sy + (el.height * zoom) / 2;
            ctx.beginPath();
            ctx.ellipse(ecx, ecy, ew / 2, eh / 2, 0, 0, Math.PI * 2);
            if (bg !== "transparent") {
                ctx.fillStyle = bg;
                ctx.fill();
            }
            ctx.stroke();
            break;
        }
        case "diamond": {
            var dw = el.width * zoom, dh = el.height * zoom;
            var left = Math.min(sx, sx + dw), top = Math.min(sy, sy + dh);
            var dwd = Math.abs(dw), dhd = Math.abs(dh);
            ctx.beginPath();
            ctx.moveTo(left + dwd / 2, top);
            ctx.lineTo(left + dwd, top + dhd / 2);
            ctx.lineTo(left + dwd / 2, top + dhd);
            ctx.lineTo(left, top + dhd / 2);
            ctx.closePath();
            if (bg !== "transparent") {
                ctx.fillStyle = bg;
                ctx.fill();
            }
            ctx.stroke();
            break;
        }
        case "line":
        case "draw":
        case "arrow": {
            var pts = el.points;
            if (pts && pts.length > 1) {
                ctx.beginPath();
                ctx.moveTo(sx + pts[0][0] * zoom, sy + pts[0][1] * zoom);
                for (var i = 1; i < pts.length; i++)
                    ctx.lineTo(sx + pts[i][0] * zoom, sy + pts[i][1] * zoom);
                ctx.stroke();
                if (el.type === "arrow")
                    drawArrowHead(ctx,
                                  sx + pts[pts.length - 2][0] * zoom, sy + pts[pts.length - 2][1] * zoom,
                                  sx + pts[pts.length - 1][0] * zoom, sy + pts[pts.length - 1][1] * zoom);
            } else if (pts && pts.length === 1) {
                ctx.beginPath();
                ctx.arc(sx + pts[0][0] * zoom, sy + pts[0][1] * zoom, ctx.lineWidth / 2, 0, Math.PI * 2);
                ctx.fill();
            }
            break;
        }
        case "text": {
            var fs = Math.max(1, Math.round((el.fontSize || 20) * zoom));
            var lh = (typeof el.lineHeight === "number" ? el.lineHeight : 1.25);
            ctx.fillStyle = el.strokeColor || "#1e1e1e";
            ctx.font = fs + "px sans-serif";
            ctx.textAlign = el.textAlign === "center" ? "center"
                            : el.textAlign === "right" ? "right" : "left";
            ctx.textBaseline = "top";
            var lines = String(el.text || "").split("\n");
            for (var li = 0; li < lines.length; li++)
                ctx.fillText(lines[li], sx, sy + li * fs * lh);
            break;
        }
        }
        ctx.restore();
    }

    function drawArrowHead(ctx, fromX, fromY, toX, toY) {
        var ang = Math.atan2(toY - fromY, toX - fromX);
        var len = Math.max(9, strokeWidth * 3) * zoom;
        ctx.beginPath();
        ctx.moveTo(toX, toY);
        ctx.lineTo(toX - len * Math.cos(ang - 0.4), toY - len * Math.sin(ang - 0.4));
        ctx.moveTo(toX, toY);
        ctx.lineTo(toX - len * Math.cos(ang + 0.4), toY - len * Math.sin(ang + 0.4));
        ctx.stroke();
    }

    function paintSelection(ctx) {
        var m = root.model;
        if (!m)
            return;
        var sel = m.selectedIds || [];
        for (var i = 0; i < sel.length; i++) {
            var el = m.getElement(sel[i]);
            if (!el || el.isDeleted)
                continue;
            var b = m.elementBounds(el);
            var sx = b.x * zoom + panX;
            var sy = b.y * zoom + panY;
            var sw = Math.max(b.width * zoom, 2);
            var sh = Math.max(b.height * zoom, 2);
            ctx.save();
            ctx.strokeStyle = cssColor(Theme.accent, 0.95);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 3]);
            ctx.strokeRect(sx - 3, sy - 3, sw + 6, sh + 6);
            ctx.setLineDash([]);
            if (sel.length === 1) {
                var hs = _handleSize;
                var corners = [[sx, sy], [sx + sw, sy], [sx, sy + sh], [sx + sw, sy + sh]];
                for (var c = 0; c < corners.length; c++) {
                    ctx.fillStyle = cssColor(Theme.background, 1);
                    ctx.fillRect(corners[c][0] - hs / 2, corners[c][1] - hs / 2, hs, hs);
                    ctx.strokeRect(corners[c][0] - hs / 2 + 0.5, corners[c][1] - hs / 2 + 0.5, hs - 1, hs - 1);
                }
            }
            ctx.restore();
        }
    }

    function hitHandle(mx, my) {
        var m = root.model;
        if (!m || m.selectedIds.length !== 1 || activeTool !== "select")
            return "";
        var el = m.getElement(m.selectedIds[0]);
        if (!el || el.isDeleted)
            return "";
        var b = m.elementBounds(el);
        var sx = b.x * zoom + panX;
        var sy = b.y * zoom + panY;
        var sw = Math.max(b.width * zoom, 2);
        var sh = Math.max(b.height * zoom, 2);
        var tol = _handleSize / 2 + 3;
        var handles = { nw: [sx, sy], ne: [sx + sw, sy], sw: [sx, sy + sh], se: [sx + sw, sy + sh] };
        for (var key in handles) {
            if (Math.abs(mx - handles[key][0]) <= tol && Math.abs(my - handles[key][1]) <= tol)
                return key;
        }
        return "";
    }

    MouseArea {
        id: input

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: root._gesture === "pan" ? Qt.ClosedHandCursor
                     : root.spaceHeld ? Qt.OpenHandCursor
                     : (root.activeTool === "select" || root.activeTool === "eraser") ? Qt.ArrowCursor
                     : Qt.CrossCursor

        onPressed: function(mouse) {
            input.forceActiveFocus();
            var m = root.model;
            if (!m) {
                mouse.accepted = false;
                return;
            }
            if (mouse.button === Qt.MiddleButton || root.spaceHeld) {
                root._startPan(mouse);
                return;
            }
            if (mouse.button !== Qt.LeftButton)
                return;
            root._pushedThisGesture = false;
            root._mutatedThisGesture = false;
            root._lastMoveDx = 0;
            root._lastMoveDy = 0;
            var wp = root.worldFromScreen(mouse.x, mouse.y);
            root._pressWorld = wp;
            switch (root.activeTool) {
            case "select":
                root._pressSelect(mouse, wp);
                break;
            case "rectangle":
            case "ellipse":
            case "diamond":
                root._gesture = "create";
                root._ghostEl = {
                    type: root.activeTool, x: wp.x, y: wp.y, width: 0, height: 0,
                    strokeColor: root.strokeColor.toString(),
                    backgroundColor: root.fillColor.a === 0 ? "transparent" : root.fillColor.toString(),
                    strokeWidth: root.strokeWidth
                };
                break;
            case "arrow":
            case "line":
                root._gesture = "create";
                root._ghostEl = {
                    type: root.activeTool, x: wp.x, y: wp.y, width: 0, height: 0,
                    points: [[0, 0], [0, 0]],
                    strokeColor: root.strokeColor.toString(), backgroundColor: "transparent",
                    strokeWidth: root.strokeWidth
                };
                break;
            case "draw":
                root._gesture = "freehand";
                root._freehandPts = [[wp.x, wp.y]];
                root._ghostEl = {
                    type: "draw", x: wp.x, y: wp.y, width: 0, height: 0,
                    points: [[0, 0]],
                    strokeColor: root.strokeColor.toString(), backgroundColor: "transparent",
                    strokeWidth: root.strokeWidth
                };
                break;
            case "eraser":
                root._gesture = "erase";
                root._erasePushed = false;
                root._eraseAny = false;
                root._eraseAt(wp);
                break;
            case "text":
                root._pressText(wp);
                break;
            }
            root.repaint();
        }

        onPositionChanged: function(mouse) {
            if (root._gesture === "none" || !mouse.buttons || !root.model)
                return;
            if (root._gesture === "pan") {
                root.panX += mouse.x - root._panLast.x;
                root.panY += mouse.y - root._panLast.y;
                root._panLast = { x: mouse.x, y: mouse.y };
                return;
            }
            var wp = root.worldFromScreen(mouse.x, mouse.y);
            switch (root._gesture) {
            case "move":
                root._applyMove(wp);
                break;
            case "resize":
                root._applyResize(wp, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                break;
            case "create":
                root._updateGhost(wp);
                break;
            case "freehand":
                root._updateFreehand(wp);
                break;
            case "erase":
                root._eraseAt(wp);
                break;
            }
            root.repaint();
        }

        onReleased: function(mouse) {
            switch (root._gesture) {
            case "create":
                root._commitCreate();
                break;
            case "freehand":
                root._commitFreehand();
                break;
            case "erase":
                if (root._eraseAny)
                    root.boardModified();
                break;
            case "move":
            case "resize":
                if (root._mutatedThisGesture)
                    root.boardModified();
                break;
            }
            root._gesture = "none";
            root._ghostEl = null;
            root.repaint();
        }

        onCanceled: function(mouse) {
            root._gesture = "none";
            root._ghostEl = null;
            root.repaint();
        }

        onDoubleClicked: function(mouse) {
            var m = root.model;
            if (!m || mouse.button !== Qt.LeftButton || root.activeTool !== "select")
                return;
            var wp = root.worldFromScreen(mouse.x, mouse.y);
            var hit = m.hitTest(wp.x, wp.y);
            if (hit && hit.type === "text") {
                root._gesture = "none";
                root._ghostEl = null;
                root.openTextEditor(hit, hit.x, hit.y);
            }
        }

        onWheel: function(wheel) {
            if (wheel.modifiers & Qt.ControlModifier) {
                root.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15);
            } else if (wheel.modifiers & Qt.ShiftModifier) {
                root.panX += (wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y) * 0.25;
            } else {
                root.panY += wheel.angleDelta.y * 0.25;
                if (wheel.angleDelta.x !== 0)
                    root.panX += wheel.angleDelta.x * 0.25;
            }
            wheel.accepted = true;
        }
    }

    function _startPan(mouse) {
        _gesture = "pan";
        _panLast = { x: mouse.x, y: mouse.y };
    }

    function _pressSelect(mouse, wp) {
        var m = root.model;
        var handle = hitHandle(mouse.x, mouse.y);
        if (handle !== "") {
            var el = m.getElement(m.selectedIds[0]);
            var b = m.elementBounds(el);
            _gesture = "resize";
            _resizeHandle = handle;
            _resizeOrig = { x: b.x, y: b.y, width: b.width, height: b.height };
            return;
        }
        var hit = m.hitTest(wp.x, wp.y);
        if (hit) {
            if (m.selectedIds.indexOf(hit.id) < 0)
                m.selectOnly(hit.id);
            _gesture = "move";
            _lastMoveDx = 0;
            _lastMoveDy = 0;
        } else {
            m.clearSelection();
            _gesture = "none";
        }
    }

    function _applyMove(wp) {
        var m = root.model;
        var dx = wp.x - _pressWorld.x;
        var dy = wp.y - _pressWorld.y;
        if (!_pushedThisGesture && (Math.abs(dx) > 0.001 || Math.abs(dy) > 0.001)) {
            m.pushUndo();
            _pushedThisGesture = true;
            _mutatedThisGesture = true;
        }
        if (!_pushedThisGesture)
            return;
        var ddx = dx - _lastMoveDx;
        var ddy = dy - _lastMoveDy;
        _lastMoveDx = dx;
        _lastMoveDy = dy;
        if (ddx !== 0 || ddy !== 0)
            m.moveElements(m.selectedIds.slice(), ddx, ddy);
    }

    function _applyResize(wp, aspect) {
        var m = root.model;
        var el = m.getElement(m.selectedIds[0]);
        if (!el || !_resizeOrig)
            return;
        var o = _resizeOrig;
        var ax, ay;
        if (_resizeHandle === "nw") { ax = o.x + o.width; ay = o.y + o.height; }
        else if (_resizeHandle === "ne") { ax = o.x; ay = o.y + o.height; }
        else if (_resizeHandle === "sw") { ax = o.x + o.width; ay = o.y; }
        else { ax = o.x; ay = o.y; }
        var nw = wp.x - ax;
        var nh = wp.y - ay;
        if (aspect && o.width > 0 && o.height > 0) {
            var ratio = o.width / o.height;
            if (Math.abs(nw) > Math.abs(nh) * ratio)
                nh = (nh < 0 ? -1 : 1) * Math.abs(nw) / ratio;
            else
                nw = (nw < 0 ? -1 : 1) * Math.abs(nh) * ratio;
        }
        if (!_pushedThisGesture && (Math.abs(nw) > 0.5 || Math.abs(nh) > 0.5)) {
            m.pushUndo();
            _pushedThisGesture = true;
            _mutatedThisGesture = true;
        }
        if (!_pushedThisGesture)
            return;
        m.resizeElement(el.id, Math.min(ax, ax + nw), Math.min(ay, ay + nh),
                        Math.abs(nw), Math.abs(nh));
    }

    function _updateGhost(wp) {
        var g = _ghostEl;
        if (!g)
            return;
        if (g.type === "line" || g.type === "arrow") {
            g.points = [[0, 0], [wp.x - g.x, wp.y - g.y]];
        } else {
            g.width = wp.x - g.x;
            g.height = wp.y - g.y;
        }
    }

    function _updateFreehand(wp) {
        var pts = _freehandPts;
        var last = pts[pts.length - 1];
        var ddx = wp.x - last[0];
        var ddy = wp.y - last[1];
        if (Math.sqrt(ddx * ddx + ddy * ddy) <= 2)
            return;
        pts.push([wp.x, wp.y]);
        _syncFreehandGhost();
    }

    function _syncFreehandGhost() {
        var pts = _freehandPts;
        var g = _ghostEl;
        if (!g || pts.length === 0)
            return;
        var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (var i = 0; i < pts.length; i++) {
            minX = Math.min(minX, pts[i][0]);
            minY = Math.min(minY, pts[i][1]);
            maxX = Math.max(maxX, pts[i][0]);
            maxY = Math.max(maxY, pts[i][1]);
        }
        var rel = [];
        for (var j = 0; j < pts.length; j++)
            rel.push([pts[j][0] - minX, pts[j][1] - minY]);
        g.x = minX;
        g.y = minY;
        g.width = maxX - minX;
        g.height = maxY - minY;
        g.points = rel;
    }

    function _eraseAt(wp) {
        var m = root.model;
        var hits = m.hitTestAll(wp.x, wp.y);
        if (hits.length === 0)
            return;
        if (!_erasePushed) {
            m.pushUndo();
            _erasePushed = true;
        }
        var ids = [];
        for (var i = 0; i < hits.length; i++)
            ids.push(hits[i].id);
        m.removeElements(ids);
        _eraseAny = true;
    }

    function _commitCreate() {
        var g = _ghostEl;
        var m = root.model;
        if (!g || !m)
            return;
        if (g.type === "line" || g.type === "arrow") {
            var p = g.points[1];
            if (Math.sqrt(p[0] * p[0] + p[1] * p[1]) * zoom < 3)
                return;
        } else if (Math.abs(g.width) * zoom < 3 && Math.abs(g.height) * zoom < 3) {
            return;
        }
        var props = {
            type: g.type,
            strokeColor: g.strokeColor,
            backgroundColor: g.backgroundColor,
            strokeWidth: g.strokeWidth
        };
        if (g.type === "line" || g.type === "arrow") {
            props.x = g.x;
            props.y = g.y;
            props.width = g.points[1][0];
            props.height = g.points[1][1];
            props.points = [[0, 0], [g.points[1][0], g.points[1][1]]];
        } else {
            props.x = Math.min(g.x, g.x + g.width);
            props.y = Math.min(g.y, g.y + g.height);
            props.width = Math.abs(g.width);
            props.height = Math.abs(g.height);
        }
        m.pushUndo();
        var el = m.addElement(props);
        m.selectOnly(el.id);
        boardModified();
        requestTool("select");
    }

    function _commitFreehand() {
        var m = root.model;
        var pts = _freehandPts;
        if (!m || pts.length < 2)
            return;
        _syncFreehandGhost();
        var g = _ghostEl;
        m.pushUndo();
        var el = m.addElement({
                                  type: "draw",
                                  x: g.x, y: g.y,
                                  width: g.width, height: g.height,
                                  points: JSON.parse(JSON.stringify(g.points)),
                                  strokeColor: g.strokeColor,
                                  backgroundColor: "transparent",
                                  strokeWidth: g.strokeWidth
                              });
        m.selectOnly(el.id);
        boardModified();
        requestTool("select");
    }

    function openTextEditor(existingEl, wx, wy) {
        _editingEl = existingEl;
        _editWorld = { x: wx, y: wy };
        var sp = screenFromWorld(wx, wy);
        textEditor.x = sp.x;
        textEditor.y = sp.y;
        textEditor.color = existingEl ? existingEl.strokeColor : strokeColor;
        textEditor.text = existingEl ? existingEl.text : "";
        textEditor.visible = true;
        textEditor.forceActiveFocus();
        textEditor.cursorPosition = textEditor.length;
    }

    function commitTextEditor() {
        if (!textEditor.visible)
            return;
        var txt = textEditor.text;
        var ed = _editingEl;
        var at = _editWorld;
        _editingEl = null;
        _editWorld = null;
        textEditor.visible = false;
        var m = model;
        if (ed) {
            if (txt.length > 0 && txt !== ed.text) {
                m.pushUndo();
                m.updateElement(ed.id, { text: txt });
                var up = m.getElement(ed.id);
                boardModified();
                elementTextCommitted(up);
            }
        } else if (txt.length > 0 && m && at) {
            m.pushUndo();
            var el = m.addElement({
                                      type: "text", x: at.x, y: at.y, text: txt,
                                      fontSize: 20, strokeColor: strokeColor.toString()
                                  });
            boardModified();
            elementTextCommitted(el);
        }
        repaint();
    }

    TextArea {
        id: textEditor

        visible: false
        z: 20
        background: null
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0
        wrapMode: TextArea.WrapAnywhere
        font.pixelSize: 20 * root.zoom
        font.family: "sans-serif"
        color: root.strokeColor
        selectionColor: root.cssColor(Theme.accent, 0.4)
        selectedTextColor: Theme.brightForeground
        cursorVisible: true
        persistentSelection: false

        Keys.onEscapePressed: function(event) {
            event.accepted = true;
            root.commitTextEditor();
            input.forceActiveFocus();
        }

        onActiveFocusChanged: {
            if (!activeFocus && visible)
                root.commitTextEditor();
        }
    }
}
