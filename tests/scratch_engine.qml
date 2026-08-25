import QtQuick
import Quickshell
import "engine"

ShellRoot {
    FloatingWindow {
        id: win

        title: "OmaBoard engine scratch"
        visible: true
        implicitWidth: 1100
        implicitHeight: 720
        color: Theme.background

        property int fails: 0
        property string rectId: ""
        property string ellipseId: ""

        function check(name, cond) {
            console.log(cond ? "PASS " + name : "FAIL " + name);
            if (!cond)
                win.fails++;
        }

        function liveCount() {
            var n = 0;
            for (var i = 0; i < model.elements.length; i++)
                if (!model.elements[i].isDeleted)
                    n++;
            return n;
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background

            BoardCanvas {
                id: canvas

                anchors.fill: parent
                model: model
                activeTool: "select"
                showGrid: true

                onBoardModified: console.log("ENGINE boardModified")
                onRequestTool: function(tool) {
                    console.log("ENGINE requestTool:", tool);
                    canvas.activeTool = tool;
                }
                onElementTextCommitted: function(el) {
                    console.log("ENGINE textCommitted:", el.text);
                }
            }
        }

        SceneModel {
            id: model
        }

        Component.onCompleted: console.log("ENGINE started")

        Timer {
            interval: 1000
            running: true
            repeat: false
            onTriggered: {
                if (!model || !canvas) {
                    win.check("harness-loaded", false);
                    return;
                }
                var r = model.addElement({ type: "rectangle", x: 100, y: 100, width: 200, height: 150 });
                win.rectId = r.id;
                win.check("add-rect-normalized", !!r.id && r.version === 1 && typeof r.seed === "number" && r.isDeleted === false);
                var hit = model.hitTest(150, 150);
                win.check("hit-inside-rect", hit !== null && hit.id === r.id);
                win.check("hit-outside-null", model.hitTest(400, 400) === null);
            }
        }

        Timer {
            interval: 1500
            running: true
            repeat: false
            onTriggered: {
                var e = model.addElement({ type: "ellipse", x: 180, y: 120, width: 160, height: 140 });
                win.ellipseId = e.id;
                var top = model.hitTest(280, 220);
                win.check("topmost-is-ellipse", top !== null && top.type === "ellipse" && top.id === e.id);
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: false
            onTriggered: {
                var d = model.addElement({
                                             type: "draw", x: 400, y: 300,
                                             width: 200, height: 50,
                                             points: [[0, 0], [100, 50], [200, 0]],
                                             strokeWidth: 2
                                         });
                var mid = model.hitTest(450, 325);
                win.check("draw-hit-mid", mid !== null && mid.id === d.id);
                win.check("draw-miss-offpath", model.hitTest(450, 360) === null);
            }
        }

        Timer {
            interval: 2500
            running: true
            repeat: false
            onTriggered: {
                var tx = model.addElement({ type: "text", x: 600, y: 400, text: "hello" });
                var found = model.hitTest(605, 405);
                win.check("text-found", found !== null && found.id === tx.id);
                win.check("text-fields-complete", tx.fontSize === 20 && tx.lineHeight === 1.25 && typeof tx.fontFamily === "number");
            }
        }

        Timer {
            interval: 3000
            running: true
            repeat: false
            onTriggered: {
                model.selectOnly(win.rectId);
                var before = model.getElement(win.rectId);
                var w0 = before.width, h0 = before.height;
                var after = model.resizeElement(win.rectId, 100, 100, 300, 200);
                win.check("resize-wh-changed", after.width === 300 && after.height === 200 && after.width !== w0 && after.height !== h0);
            }
        }

        Timer {
            interval: 3500
            running: true
            repeat: false
            onTriggered: {
                model.selectOnly(win.rectId);
                model.pushUndo();
                win.check("canUndo-after-push", model.canUndo);
                model.deleteSelection();
                win.check("deleted-gone", model.getElement(win.rectId) === null);
                win.check("selection-cleared-by-delete", model.selectedIds.indexOf(win.rectId) < 0);
                model.undo();
                win.check("undo-restored", model.getElement(win.rectId) !== null && model.canRedo);
                model.redo();
                win.check("redo-redeleted", model.getElement(win.rectId) === null);
                model.undo();
                win.check("undo2-restored", model.getElement(win.rectId) !== null);
            }
        }

        Timer {
            interval: 4000
            running: true
            repeat: false
            onTriggered: {
                model.selectOnly(win.rectId);
                var before = win.liveCount();
                var ids = model.duplicateSelection();
                win.check("dup-returns-new-id", ids.length === 1 && ids[0] !== win.rectId);
                win.check("dup-count-grows", win.liveCount() === before + 1);
                var dup = model.getElement(ids[0]);
                win.check("dup-offset-16", dup.x === 116 && dup.y === 116);
                win.check("dup-selected-and-fresh-seed", model.selectedIds.indexOf(ids[0]) >= 0 && typeof dup.seed === "number");
            }
        }

        Timer {
            interval: 4500
            running: true
            repeat: false
            onTriggered: {
                var js = model.toJson();
                win.check("json-nonempty-string", typeof js === "string" && js.length > 0);
                var countBefore = win.liveCount();
                var parsed = JSON.parse(js);
                win.check("json-is-excalidraw-scene", parsed.type === "excalidraw" && Array.isArray(parsed.elements));
                model.loadFromJson(parsed);
                win.check("roundtrip-count", win.liveCount() === countBefore);
                win.check("roundtrip-ids-preserved", model.getElement(win.rectId) !== null && model.getElement(win.ellipseId) !== null);
            }
        }

        Timer {
            interval: 5500
            running: true
            repeat: false
            onTriggered: {
                var a = model.addElement({ type: "rectangle", x: 800, y: 80, width: 40, height: 40 });
                var b = model.addElement({ type: "rectangle", x: 900, y: 80, width: 40, height: 40 });
                var n = model.elements.length;
                win.check("order-initial-ab", model.elements[n - 2].id === a.id && model.elements[n - 1].id === b.id);
                model.moveElements([b.id], 10, -5);
                win.check("moveElements-shifts", model.getElement(b.id).x === 910 && model.getElement(b.id).y === 75);
                model.bringForward([a.id]);
                win.check("bringForward-swaps", model.elements[n - 1].id === a.id && model.elements[n - 2].id === b.id);
                model.sendBackward([a.id]);
                win.check("sendBackward-swaps-back", model.elements[n - 2].id === a.id && model.elements[n - 1].id === b.id);
                win.check("canvas-alive", canvas.model === model && canvas.width > 0);
            }
        }

        Timer {
            interval: 8500
            running: true
            repeat: false
            onTriggered: {
                if (win.fails === 0)
                    console.log("ENGINE ALL PASS");
                else
                    console.log("ENGINE FAILED: " + win.fails + " check(s)");
            }
        }
    }
}
