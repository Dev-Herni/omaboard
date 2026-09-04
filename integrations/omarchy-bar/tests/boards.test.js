"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "..", "Boards.js"), "utf8");
const sandbox = {};
vm.createContext(sandbox);
vm.runInContext(src, sandbox);

let failed = 0;
function check(name, cond, detail) {
  if (cond) {
    console.log("PASS:", name);
  } else {
    failed++;
    console.log("FAIL:", name, detail || "");
  }
}

const dirs = sandbox.parseConfig("", "/home/oxhenri");
check("default vault", dirs.vaultDir === "/home/oxhenri/OxHenri Vault/Whiteboards");
check("default local", dirs.localDir === "/home/oxhenri/Documents/Whiteboards");

const cfg = sandbox.parseConfig(JSON.stringify({
  vaultDir: "~/Notes/Boards",
  localDir: "/tmp/boards"
}), "/home/oxhenri");
check("expand vault", cfg.vaultDir === "/home/oxhenri/Notes/Boards");
check("abs local", cfg.localDir === "/tmp/boards");

check("pretty timestamp", sandbox.prettyLabel("ideas-20260825-141000.md") === "ideas");
check("pretty plain", sandbox.prettyLabel("roadmap.md") === "roadmap");

const parsed = sandbox.parseFindLines(
  "1710\t/home/oxhenri/OxHenri Vault/Whiteboards/a.md\0" +
  "1700\t/home/oxhenri/Documents/Whiteboards/b.md\0" +
  "skip me\0",
  "/home/oxhenri/OxHenri Vault/Whiteboards"
);
check("parsed count", parsed.length === 2);
check("vault section", parsed[0].section === "vault" && parsed[0].label === "a");
check("local section", parsed[1].section === "local" && parsed[1].label === "b");

const weird = sandbox.parseFindLines(
  "1800\t/home/oxhenri/Documents/Whiteboards/two\nlines.md\0",
  "/home/oxhenri/OxHenri Vault/Whiteboards"
);
check("newline in filename survives", weird.length === 1 && weird[0].name === "two\nlines.md"
  && weird[0].section === "local");

const filtered = sandbox.filterBoards(parsed, "A");
check("filter case", filtered.length === 1 && filtered[0].label === "a");

const rows = sandbox.rowsFor(parsed);
check("rows are boards", rows.length === 2 && rows[0].kind === "board" && rows[1].kind === "board");

const duped = sandbox.parseFindLines(
  "2000\t/home/oxhenri/OxHenri Vault/Whiteboards/untitled-board-20260825-163215.md\0" +
  "1990\t/home/oxhenri/Documents/Whiteboards/untitled-board-20260825-163229.md\0",
  "/home/oxhenri/OxHenri Vault/Whiteboards"
);
const unique = sandbox.dedupeBoards(duped);
check("dedupe same title", unique.length === 1 && unique[0].section === "vault");
check("dedupe keeps newest", unique[0].path.indexOf("163215") >= 0);

if (failed) {
  console.log("FAILED", failed);
  process.exit(1);
}
console.log("ok");
