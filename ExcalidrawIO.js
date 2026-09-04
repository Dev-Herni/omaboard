.pragma library
// OmaBoard <-> Obsidian-Excalidraw markdown serialization.
// Implements docs/CONTRACTS.md "ExcalidrawIO.js" section.

var ELEMENT_TYPES = ["rectangle", "ellipse", "diamond", "arrow", "line", "draw", "text", "sticky", "image"];

function randomId() {
    var id = "";
    while (id.length < 12) {
        id += Math.floor(Math.random() * 36).toString(36);
    }
    return id;
}

function randomSeed() {
    return Math.floor(Math.random() * 4294967296);
}

// Strip null bytes and C0/C1 control characters (keep \t \n \r).
function sanitizeText(s) {
    if (typeof s !== "string") return "";
    return s.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, "");
}

function _num(props, key, dflt) {
    var v = props[key];
    return (v === undefined || v === null || typeof v !== "number") ? dflt : v;
}

function makeElement(type, props) {
    props = (props !== null && typeof props === "object") ? props : {};
    var el = {
        id: (typeof props.id === "string" && props.id.length > 0) ? props.id : randomId(),
        type: type,
        x: _num(props, "x", 0),
        y: _num(props, "y", 0),
        width: _num(props, "width", 0),
        height: _num(props, "height", 0),
        angle: _num(props, "angle", 0),
        strokeColor: (typeof props.strokeColor === "string") ? props.strokeColor : "#1e1e1e",
        backgroundColor: (typeof props.backgroundColor === "string") ? props.backgroundColor
                        : (type === "sticky") ? "#fef3c7" : "transparent",
        fillStyle: (typeof props.fillStyle === "string") ? props.fillStyle : "solid",
        strokeWidth: _num(props, "strokeWidth", 2),
        roughness: _num(props, "roughness", (type === "draw" || type === "line" || type === "arrow") ? 0 : 1),
        opacity: _num(props, "opacity", 100),
        seed: _num(props, "seed", randomSeed()),
        version: _num(props, "version", 1),
        groupIds: Array.isArray(props.groupIds) ? props.groupIds.slice() : [],
        frameId: props.frameId !== undefined ? props.frameId : null,
        roundness: props.roundness !== undefined ? props.roundness : null,
        isDeleted: props.isDeleted === true,
        updated: _num(props, "updated", Date.now())
    };

    if (type === "line" || type === "arrow" || type === "draw") {
        if (Array.isArray(props.points)) {
            el.points = [];
            for (var i = 0; i < props.points.length; i++) {
                var p = props.points[i];
                el.points.push(Array.isArray(p) ? [p[0], p[1]] : [0, 0]);
            }
            if (el.points.length === 0) el.points.push([0, 0]);
        } else {
            el.points = [[0, 0]];
        }
        if (type === "arrow") {
            el.startArrowhead = props.startArrowhead !== undefined ? props.startArrowhead : null;
            el.endArrowhead = props.endArrowhead !== undefined ? props.endArrowhead : null;
        }
    } else if (type === "text") {
        el.text = sanitizeText(props.text);
        el.fontSize = _num(props, "fontSize", 20);
        el.fontFamily = _num(props, "fontFamily", 1);
        el.textAlign = (typeof props.textAlign === "string") ? props.textAlign : "left";
        el.containerId = props.containerId !== undefined ? props.containerId : null;
        el.lineHeight = _num(props, "lineHeight", 1.25);
    } else if (type === "sticky") {
        el.text = sanitizeText(props.text);
        el.fontSize = _num(props, "fontSize", 18);
        el.fontFamily = _num(props, "fontFamily", 1);
        el.lineHeight = _num(props, "lineHeight", 1.3);
        el.roundness = 4;
    } else if (type === "image") {
        el.imageData = (typeof props.imageData === "string") ? props.imageData : "";
        el.imageWidth = _num(props, "imageWidth", 0);
        el.imageHeight = _num(props, "imageHeight", 0);
    }

    if (typeof el.label !== "string")
        el.label = "";

    return el;
}

function serialize(elements, meta) {
    meta = (meta !== null && typeof meta === "object") ? meta : {};
    var title = (typeof meta.title === "string" && meta.title.length > 0) ? meta.title : "Untitled";
    var created = (typeof meta.createdISO === "string") ? meta.createdISO : new Date().toISOString();
    var modified = (typeof meta.modifiedISO === "string") ? meta.modifiedISO : created;
    var viewBg = (typeof meta.viewBackgroundColor === "string") ? meta.viewBackgroundColor : "transparent";
    var els = Array.isArray(elements) ? elements : [];

    var textLines = [];
    for (var i = 0; i < els.length; i++) {
        var el = els[i];
        if (el && el.type === "text") {
            textLines.push(sanitizeText(el.text).replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n/g, "\\n"));
        }
    }

    var scene = {
        type: "excalidraw",
        version: 2,
        source: "omaboard",
        elements: els,
        appState: { viewBackgroundColor: viewBg, gridSize: null },
        files: {}
    };

    var md = ""
        + "---\n"
        + "excalidraw-plugin: parsed\n"
        + "tags: [excalidraw]\n"
        + "title: " + title + "\n"
        + "created: " + created + "\n"
        + "modified: " + modified + "\n"
        + "---\n"
        + "==ⓘ Edit these boards in OmaBoard==\n"
        + "\n"
        + "# Excalidraw Data\n"
        + "\n"
        + "## Text Elements\n";
    if (textLines.length > 0) {
        md += textLines.join("\n") + "\n";
    }
    // Size the fence past the longest backtick run in the payload so element
    // text containing ```json or longer fences cannot terminate it early.
    var jsonBody = JSON.stringify(scene);
    var fenceLen = 3;
    var runs = jsonBody.match(/`+/g);
    if (runs) {
        for (var r = 0; r < runs.length; r++) {
            if (runs[r].length >= fenceLen)
                fenceLen = runs[r].length + 1;
        }
    }

    md += "\n"
        + "## Drawing\n"
        + "`".repeat(fenceLen) + "json\n"
        + jsonBody
        + "\n"
        + "`".repeat(fenceLen) + "\n";

    return md;
}

function parse(markdownString) {
    if (typeof markdownString !== "string") return null;

    var drawingIdx = markdownString.indexOf("## Drawing");
    var region = drawingIdx >= 0 ? markdownString.slice(drawingIdx) : markdownString;

    var fenceRe = /(`{3,})json[ \t]*\r?\n([\s\S]*?)\r?\n\1(?!`)/g;
    var m, last = null;
    while ((m = fenceRe.exec(region)) !== null) {
        last = m;
    }
    if (!last) return null;

    var scene;
    try {
        scene = JSON.parse(last[2]);
    } catch (e) {
        return null;
    }
    if (scene === null || typeof scene !== "object" || Array.isArray(scene)) return null;

    var rawEls = Array.isArray(scene.elements) ? scene.elements : [];
    var elements = [];
    for (var i = 0; i < rawEls.length; i++) {
        var e = rawEls[i];
        if (!e || typeof e.type !== "string" || ELEMENT_TYPES.indexOf(e.type) < 0) continue;
        elements.push(makeElement(e.type, e));
    }

    var appState = { viewBackgroundColor: "transparent", gridSize: null };
    if (scene.appState && typeof scene.appState === "object" && !Array.isArray(scene.appState)) {
        for (var k in scene.appState) {
            if (Object.prototype.hasOwnProperty.call(scene.appState, k)) {
                appState[k] = scene.appState[k];
            }
        }
    }

    var title = "Untitled";
    var createdISO = "";
    var fm = markdownString.match(/^---[ \t]*\r?\n([\s\S]*?)\r?\n---/);
    if (fm) {
        var tm = fm[1].match(/^title:[ \t]*(.*)$/m);
        if (tm) title = tm[1].replace(/\r$/, "").trim();
        var cm = fm[1].match(/^created:[ \t]*(.*)$/m);
        if (cm) createdISO = cm[1].replace(/\r$/, "").trim();
    }

    return { elements: elements, appState: appState, title: title, createdISO: createdISO };
}
