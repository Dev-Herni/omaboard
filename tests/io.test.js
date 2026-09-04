"use strict";
// Node-compatible tests for ExcalidrawIO.js (QML .pragma library file).
// Run: node tests/io.test.js

const fs = require("fs");
const path = require("path");

const SRC = path.join(__dirname, "..", "ExcalidrawIO.js");
const TMP = "/tmp/opencode/ExcalidrawIO.mjs";
let failures = 0;
let count = 0;

function check(name, cond, detail) {
    count++;
    if (cond) {
        console.log("PASS: " + name);
    } else {
        failures++;
        console.log("FAIL: " + name + (detail !== undefined ? "  -> " + detail : ""));
    }
}

async function loadModule() {
    const raw = fs.readFileSync(SRC, "utf8");
    const stripped = raw
        .split("\n")
        .filter((line) => !/^\s*\.pragma/.test(line))
        .join("\n");
    fs.mkdirSync(path.dirname(TMP), { recursive: true });
    fs.writeFileSync(TMP, stripped + "\nexport { makeElement, serialize, parse };\n");
    return import("file://" + TMP);
}

(async () => {
    const { makeElement, serialize, parse } = await loadModule();

    // ---------- a. makeElement defaults for all 8 types ----------
    function commonDefaultsOk(el, type) {
        return el !== null && typeof el === "object"
            && el.type === type
            && el.angle === 0
            && el.fillStyle === "solid"
            && el.strokeWidth === 2
            && (el.roughness === 0 || el.roughness === 1)
            && el.opacity === 100
            && Number.isInteger(el.seed)
            && el.version === 1
            && Array.isArray(el.groupIds) && el.groupIds.length === 0
            && el.frameId === null
            && el.roundness === null
            && el.isDeleted === false
            && typeof el.updated === "number" && el.updated > 0
            && typeof el.id === "string" && /^[0-9a-z]+$/.test(el.id)
            && typeof el.x === "number" && typeof el.y === "number"
            && typeof el.width === "number" && typeof el.height === "number"
            && typeof el.strokeColor === "string"
            && typeof el.backgroundColor === "string";
    }

    for (const t of ["rectangle", "ellipse", "diamond"]) {
        const el = makeElement(t, {});
        check(`a: makeElement("${t}") fills common defaults`, commonDefaultsOk(el, t));
        check(`a: makeElement("${t}") bbox only`, el.points === undefined && el.text === undefined);
    }
    for (const t of ["line", "draw"]) {
        const el = makeElement(t, { x: 3, y: 4 });
        check(`a: makeElement("${t}") common defaults + points`, commonDefaultsOk(el, t)
            && Array.isArray(el.points) && el.points.length > 0 && Array.isArray(el.points[0]));
    }
    const arrow = makeElement("arrow", {});
    check('a: makeElement("arrow") arrowheads null', commonDefaultsOk(arrow, "arrow")
        && Array.isArray(arrow.points)
        && arrow.startArrowhead === null && arrow.endArrowhead === null);
    const text = makeElement("text", {});
    check('a: makeElement("text") text defaults', commonDefaultsOk(text, "text")
        && text.text === "" && text.fontSize === 20 && text.fontFamily === 1
        && text.textAlign === "left" && text.containerId === null && text.lineHeight === 1.25);

    const seeded = makeElement("rectangle", { id: "fixed1", seed: 42, opacity: 77 });
    check("a: props override defaults", seeded.id === "fixed1" && seeded.seed === 42 && seeded.opacity === 77);

    // ---------- b. round-trip preserves fields ----------
    const orig = [
        makeElement("line", {
            x: 5, y: 6, width: 10, height: -3,
            points: [[0, 0], [10, -3], [7.5, 2.25]],
            strokeColor: "#ff0000", backgroundColor: "#00ff00",
            fillStyle: "hachure", opacity: 55, strokeWidth: 4,
            roughness: 2, version: 3, groupIds: ["gA"], seed: 123456789,
        }),
        makeElement("text", {
            x: 1, y: 2, width: 80, height: 50,
            text: "hello\nworld\n\ttabbed", fontSize: 24, fontFamily: 2,
            textAlign: "center", lineHeight: 1.25,
            strokeColor: "#1056d6", opacity: 90,
        }),
    ];
    const mdRT = serialize(orig, {
        title: "Round Trip", createdISO: "2026-01-01T00:00:00.000Z",
        modifiedISO: "2026-01-02T12:34:56.000Z", viewBackgroundColor: "#123456",
    });
    const parsed = parse(mdRT);
    check("b: parse returns object", parsed !== null && typeof parsed === "object");
    if (parsed) {
        check("b: element count preserved", parsed.elements.length === 2, String(parsed.elements.length));
        const [pl, pt] = parsed.elements;
        check("b: points array preserved exactly",
            JSON.stringify(pl.points) === JSON.stringify([[0, 0], [10, -3], [7.5, 2.25]]),
            JSON.stringify(pl.points));
        check("b: embedded newline in text preserved", pt.text === "hello\nworld\n\ttabbed", JSON.stringify(pt.text));
        check("b: colors preserved", pl.strokeColor === "#ff0000" && pl.backgroundColor === "#00ff00"
            && pt.strokeColor === "#1056d6");
        check("b: opacity preserved", pl.opacity === 55 && pt.opacity === 90);
        check("b: strokeWidth preserved", pl.strokeWidth === 4);
        check("b: misc fields preserved", pl.groupIds.join() === "gA" && pl.seed === 123456789
            && pl.version === 3 && pl.fillStyle === "hachure" && pl.roughness === 2
            && pt.fontSize === 24 && pt.textAlign === "center" && pt.fontFamily === 2);
        check("b: title/appState from meta", parsed.title === "Round Trip"
            && parsed.appState.viewBackgroundColor === "#123456" && parsed.appState.gridSize === null);
    }

    // ---------- c. parser tolerance ----------
    const jsonBody = JSON.stringify({
        type: "excalidraw", version: 2, source: "omaboard",
        elements: [{ type: "rectangle", x: 8, foo: "bar", nested: { unknown: true } }],
        appState: { viewBackgroundColor: "#abcdef" }, files: {},
    });

    const noFm = "==ⓘ Edit these boards in OmaBoard==\n\n# Excalidraw Data\n\n## Drawing\n```json\n"
        + jsonBody + "\n```\n";
    const pNoFm = parse(noFm);
    check("c: missing frontmatter tolerated", pNoFm !== null && pNoFm.elements.length === 1
        && pNoFm.title === "Untitled" && pNoFm.appState.viewBackgroundColor === "#abcdef");

    const noTextSection = mdRT.replace(/## Text Elements[\s\S]*?(?=## Drawing)/, "");
    const pNoText = parse(noTextSection);
    check("c: missing Text Elements section tolerated", pNoText !== null && pNoText.elements.length === 2);

    const withUnknown = parse(mdRT.replace('"elements":[', '"topLevelJunk":{"n":1},"elements":[{ "type":"ellipse","wobble":1 },'));
    check("c: extra unknown JSON fields tolerated", withUnknown !== null && withUnknown.elements.length === 3
        && withUnknown.elements[0].type === "ellipse"
        && withUnknown.elements[1].type === "line" && withUnknown.elements[1].strokeColor === "#ff0000");

    const emptyScene = "---\nexcalidraw-plugin: parsed\ntags: [excalidraw]\ntitle: Empty\ncreated: x\nmodified: y\n---\n"
        + "==ⓘ Edit these boards in OmaBoard==\n\n# Excalidraw Data\n\n## Text Elements\n\n## Drawing\n```json\n"
        + JSON.stringify({ type: "excalidraw", version: 2, source: "omaboard", elements: [], appState: {}, files: {} })
        + "\n```\n";
    const pEmpty = parse(emptyScene);
    check("c: empty elements array tolerated", pEmpty !== null && pEmpty.elements.length === 0 && pEmpty.title === "Empty");

    check("c: no json fence returns null", parse("# nothing here\njust prose\n") === null);
    check("c: broken json fence returns null",
        parse("## Drawing\n```json\n{oops:\n```\n") === null);
    check("c: non-string input returns null", parse(null) === null && parse(42) === null);

    // ---------- d. required markers ----------
    const mdMark = serialize([makeElement("rectangle", {})], { title: "Marks" });
    check("d: has '## Drawing'", mdMark.includes("## Drawing"));
    check("d: has 'excalidraw-plugin: parsed'", mdMark.includes("excalidraw-plugin: parsed"));
    check("d: has valid ```json fence",
        /```json\r?\n[\s\S]+?\r?\n```/.test(mdMark) && parse(mdMark) !== null);
    check("d: has frontmatter + banner + data header",
        mdMark.startsWith("---\n") && mdMark.includes("==ⓘ Edit these boards in OmaBoard==")
        && mdMark.includes("# Excalidraw Data"));
    check("d: compact JSON (no pretty-print newlines inside fence)",
        (() => {
            const m = mdMark.match(/```json\r?\n([\s\S]*?)\r?\n```/);
            return m !== null && !m[1].includes("\n");
        })());

    // ---------- e. realistic 10-element scene, byte-identical round-trip ----------
    const scene = [
        makeElement("rectangle", { x: 40, y: 40, width: 160, height: 90, strokeColor: "#e03131", backgroundColor: "#ffc9c9", fillStyle: "solid", roundness: { type: 3 } }),
        makeElement("ellipse", { x: 260, y: 60, width: 120, height: 120, strokeColor: "#1971c2", backgroundColor: "#a5d8ff", opacity: 80, seed: 987654321 }),
        makeElement("diamond", { x: 430, y: 45, width: 140, height: 100, strokeColor: "#2f9e44", backgroundColor: "transparent" }),
        makeElement("arrow", { x: 200, y: 130, points: [[0, 0], [55, 30]], startArrowhead: null, endArrowhead: "triangle", strokeColor: "#f08c00", strokeWidth: 3 }),
        makeElement("line", { x: 60, y: 220, points: [[0, 0], [180, 0], [180, 60]] }),
        makeElement("draw", { x: 300, y: 230, points: [[0, 0], [3.5, 8], [9, 15.5], [16, 21], [26, 24.5], [40, 25], [52, 22]], strokeColor: "#6741d9" }),
        makeElement("text", { x: 480, y: 240, text: "Design review\naction items:\n- ship it", strokeColor: "#1e1e1e", fontSize: 28 }),
        makeElement("text", { x: 40, y: 320, text: "single line note" }),
        makeElement("rectangle", { x: 520, y: 320, width: 70, height: 70, groupIds: ["grp1"], angle: Math.PI / 6 }),
        makeElement("arrow", { x: 10, y: 400, points: [[0, 0], [-20, 45], [-5, 90]], endArrowhead: "dot", opacity: 60, version: 7 }),
    ];
    const sceneMeta = { title: "Sample Board", viewBackgroundColor: "#ffffff", createdISO: "2026-08-25T00:00:00.000Z", modifiedISO: "2026-08-25T01:00:00.000Z" };
    const mdScene = serialize(scene, sceneMeta);
    const back = parse(mdScene);
    check("e: scene parses back", back !== null && back.elements.length === 10, back ? String(back.elements.length) : "null");
    const origJson = JSON.stringify(scene);
    const backJson = back ? JSON.stringify(back.elements) : "";
    check("e: elements byte-identical at JSON level after normalization", origJson === backJson,
        origJson.length + " vs " + backJson.length);
    if (origJson !== backJson && back) {
        for (let i = 0; i < scene.length; i++) {
            if (JSON.stringify(scene[i]) !== JSON.stringify(back.elements[i])) {
                console.log("   first diff at element " + i + " (" + scene[i].type + ")");
                break;
            }
        }
    }
    check("e: re-serialize stable", serialize(back.elements, sceneMeta) === mdScene);

    // ---------- f. backtick-laden text round-trips ----------
    function fenceLengthOf(md) {
        const m = md.match(/^(`{3,})json/m);
        return m ? m[1].length : -1;
    }
    check("d/e sanity: plain boards keep a 3-backtick fence", fenceLengthOf(mdScene) === 3);

    const btText = "code fence:\n```json\n{\"a\":1}\n```\nplus ```` run and ` singles";
    const btMeta = { title: "Backticks", createdISO: "2026-01-01T00:00:00.000Z", modifiedISO: "2026-01-02T00:00:00.000Z" };
    const bt = makeElement("text", { x: 0, y: 0, text: btText });
    const mdBt = serialize([bt], btMeta);
    const pBt = parse(mdBt);
    check("f: text containing ```json fence parses back", pBt !== null, "null");
    check("f: backtick text byte-identical",
        pBt !== null && pBt.elements.length === 1 && pBt.elements[0].text === btText,
        pBt ? JSON.stringify(pBt.elements.map((e) => e.text)) : "");
    check("f: fence sized past longest content run", (() => {
        const m = mdBt.match(/(`{3,})json[ \t]*\r?\n([\s\S]*?)\r?\n\1(?!`)/);
        if (!m) return false;
        let longest = 0, run = 0;
        for (const ch of m[2]) {
            run = ch === "`" ? run + 1 : 0;
            if (run > longest) longest = run;
        }
        return m[1].length > longest && m[1].length >= 4;
    })());

    const fenceSoup = makeElement("text", { x: 0, y: 0, text: "```\n````\n```json\nx\n```\n````" });
    const pSoup = parse(serialize([fenceSoup], {}));
    check("f: multiple full fences round-trip",
        pSoup !== null && pSoup.elements[0].text === fenceSoup.text,
        pSoup ? JSON.stringify(pSoup.elements[0].text) : "");

    check("f: re-serialize stable with backticks", serialize(pBt.elements, btMeta) === mdBt);

    // ---------- g. created frontmatter ----------
    const mdCreated = serialize([], {
        title: "Created", createdISO: "2025-12-31T10:00:00.000Z", modifiedISO: "2026-01-01T00:00:00.000Z",
    });
    const pCreated = parse(mdCreated);
    check("g: created parsed", pCreated !== null && pCreated.createdISO === "2025-12-31T10:00:00.000Z",
        pCreated ? String(pCreated.createdISO) : "null");
    const noCreated = mdCreated.replace(/^created: .*$/m, "").replace(/\n\n---/, "\n---");
    const pNoCreated = parse(noCreated);
    check("g: missing created tolerated", pNoCreated !== null && pNoCreated.createdISO === "",
        pNoCreated ? JSON.stringify(pNoCreated.createdISO) : "null");

    console.log("\n" + (count - failures) + "/" + count + " assertions passed.");
    process.exit(failures > 0 ? 1 : 0);
})().catch((err) => {
    console.error("FAIL: test harness crashed ->", err);
    process.exit(1);
});
