// Board listing helpers for the OmaBoard bar panel.

function expandHome(p, home) {
  if (typeof p !== "string" || p.length === 0)
    return p
  if (p === "~")
    return home
  if (p.indexOf("~/") === 0)
    return home + p.substring(1)
  return p
}

function parseConfig(text, home) {
  var vault = home + "/OxHenri Vault/Whiteboards"
  var local = home + "/Documents/Whiteboards"
  try {
    var cfg = JSON.parse(text)
    if (cfg && typeof cfg === "object" && !Array.isArray(cfg)) {
      if (typeof cfg.vaultDir === "string" && cfg.vaultDir.length > 0)
        vault = expandHome(cfg.vaultDir, home)
      if (typeof cfg.localDir === "string" && cfg.localDir.length > 0)
        local = expandHome(cfg.localDir, home)
    }
  } catch (e) {
    // malformed config -> keep defaults
  }
  return { vaultDir: vault, localDir: local }
}

function prettyLabel(name) {
  var label = String(name || "")
  if (label.length > 3 && label.substring(label.length - 3) === ".md")
    label = label.substring(0, label.length - 3)
  return label.replace(/-\d{8}-\d{6}$/, "")
}

function parseFindLines(text, vaultDir) {
  var out = []
  var recs = String(text === undefined || text === null ? "" : text).split("\0")
  var prefix = vaultDir && vaultDir.length > 0 ? vaultDir + "/" : ""
  for (var i = 0; i < recs.length; i++) {
    var rec = recs[i]
    if (rec.length === 0)
      continue
    var tab = rec.indexOf("\t")
    var path = tab >= 0 ? rec.substring(tab + 1) : rec
    if (path.length < 4 || path.substring(path.length - 3) !== ".md")
      continue
    var slash = path.lastIndexOf("/")
    var name = slash >= 0 ? path.substring(slash + 1) : path
    if (name.length === 0 || name.indexOf("/") >= 0)
      continue
    var inVault = prefix.length > 0 && path.indexOf(prefix) === 0
    out.push({
      path: path,
      name: name,
      label: prettyLabel(name),
      section: inVault ? "vault" : "local"
    })
  }
  return out
}

function filterBoards(boards, query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q)
    return boards
  var out = []
  for (var i = 0; i < boards.length; i++) {
    var b = boards[i]
    var hay = (b.label + " " + b.name).toLowerCase()
    if (hay.indexOf(q) >= 0)
      out.push(b)
  }
  return out
}

function colorRgba(c, a) {
  if (!c)
    return "rgba(0,0,0," + a + ")"
  return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255)
       + "," + Math.round(c.b * 255) + "," + a + ")"
}

function paintIcon(ctx, width, height, color, accent, running) {
  var s = Math.max(1, Math.round(Math.min(width, height)))
  if (!ctx || s <= 0)
    return
  ctx.reset()
  ctx.clearRect(0, 0, width, height)
  if (ctx.imageSmoothingEnabled !== undefined)
    ctx.imageSmoothingEnabled = false

  // Snap 16-grid points onto device pixels so 1px strokes match the
  // NativeRendering glyphs in the rest of the bar.
  var u = s / 16
  function px(n) {
    return Math.round(n * u) + 0.5
  }

  ctx.globalAlpha = 1
  ctx.strokeStyle = colorRgba(color, 1)
  ctx.lineWidth = 1
  ctx.lineCap = "square"
  ctx.lineJoin = "miter"
  ctx.miterLimit = 2

  // Pad + two writing lines. A zigzag in a box reads as a ticker;
  // flat strokes of different length read as ink on a board.
  ctx.beginPath()
  ctx.moveTo(px(2), px(3))
  ctx.lineTo(px(2), px(13))
  ctx.lineTo(px(14), px(13))
  ctx.lineTo(px(14), px(3))
  ctx.stroke()

  ctx.beginPath()
  ctx.moveTo(px(5), px(6))
  ctx.lineTo(px(11), px(6))
  ctx.stroke()

  ctx.beginPath()
  ctx.moveTo(px(5), px(9))
  ctx.lineTo(px(9), px(9))
  ctx.stroke()
}

function dedupeBoards(boards) {
  // Newest-first list: keep the first row for each display name so a local
  // save plus a vault save of the same board does not show up twice.
  var seen = {}
  var out = []
  for (var i = 0; i < boards.length; i++) {
    var key = boards[i].label
    if (seen[key])
      continue
    seen[key] = true
    out.push(boards[i])
  }
  return out
}

function rowsFor(boards) {
  var rows = []
  for (var i = 0; i < boards.length; i++) {
    rows.push({
      kind: "board",
      label: boards[i].label,
      path: boards[i].path,
      section: boards[i].section
    })
  }
  return rows
}
