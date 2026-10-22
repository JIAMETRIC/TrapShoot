// Golden fixture generator.
// Extracts the pure functions of the 7.0.7 web app (Tools/golden/reference/index-7.0.7.html) and runs them on fixed inputs.
// The Swift port in Packages/TrapCore must produce the same answers (see TrapCoreTests).
// Usage: node Tools/golden/generate.js Tools/golden/reference/index-7.0.7.html Packages/TrapCore/Tests/TrapCoreTests/Fixtures
"use strict";
const fs = require("fs"), path = require("path");
const [,, htmlPath, outDir] = process.argv;
if (!htmlPath || !outDir) { console.error("usage: generate.js <index.html> <outDir>"); process.exit(2); }
const lines = fs.readFileSync(htmlPath, "utf8").split("\n");
const lineOf = (re, from = 0) => { for (let i = from; i < lines.length; i++) if (re.test(lines[i])) return i; throw new Error("not found: " + re); };
const range = (a, b) => lines.slice(a, b).join("\n");
// a function body by brace counting (the app's functions keep braces out of strings)
function grab(name) {
  const s = lineOf(new RegExp("^\\s*function " + name + "\\("));
  let depth = 0, started = false;
  for (let i = s; i < lines.length; i++) {
    for (const ch of lines[i]) { if (ch === "{") { depth++; started = true; } else if (ch === "}") depth--; }
    if (started && depth === 0) return range(s, i + 1);
  }
  throw new Error("unbalanced: " + name);
}
const grabVar = (name) => lines[lineOf(new RegExp("^\\s*var " + name + "\\b"))];

let code = "";
code += range(lineOf(/^\s*var SCHEME_SRC = \{/), lineOf(/app info and logo/)) + "\n";   // schemes, constants, rules, prediction
code += grabVar("APP") + "\n" + grabVar("K") + "\n";
code += ["lget", "lset", "loadPrefs", "newRound", "norm", "toDoc"].map(grab).join("\n") + "\n";
code += range(lineOf(/^\s*var BRK_K\b/), lineOf(/^\s*function brkTxt\b/)) + "\n";         // break distance
code += ["ntCount", "csvCell", "shooterById", "csvFor"].map(grab).join("\n") + "\n";
code += range(lineOf(/^\s*var ANG\b/), lineOf(/^\s*var DIMS = \[/)) + "\n";   // analysis constants
code += ["trapAt"].map(grab).join("\n") + "\n" + range(lineOf(/^\s*var DIMS = \[/), lineOf(/^\s*function statsOf\b/)) + "\n";
code += ["statsOf", "analyse", "pct", "schemeCounts", "dominantScheme", "solve3", "fitGeometry", "aLabel", "hLabel", "trapStats", "trapFindings", "esc", "fmtDate"].map(grab).join("\n") + "\n";
code += "\nreturn { N, QUOTA, PRED_FROM, pct, schemeCounts, dominantScheme, fitGeometry, trapStats, trapFindings, SCHEMES, DIROFF, trapFor, blank, score, counts, recorded, stnOf, stationCounts, stationOver, isFull, dirOdds, grade, initials, genSid, dirsRecorded, predict, newRound, norm, toDoc, BRK, shotTime, breakDist, brkShot, brkFor, csvFor, ntCount, DIMS, statsOf, analyse, setRounds: function (x) { rounds = x; }, setBrk: function (b) { BRK = Object.assign({}, BRK, b); shotKey = ''; } };";
const localStorage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
const app = new Function("localStorage", "document", "var rounds = [], shooters = [], me = null, cur = null;\n" + code)(localStorage, {});

// ---- deterministic data ----
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function mkRound(seed, o) {
  const rnd = mulberry32(seed), N = app.N;
  const r = Object.assign({
    id: "r" + seed.toString(36) + "abc", uid: "u-" + seed, createdAt: "2026-10-20T07:" + String(10 + seed % 40).padStart(2, "0") + ":00.000Z", date: "2026-10-20", startTime: "09:30",
    startStn: 1, session: 1, sessionId: "20261020-0930-MT", type: "Training", scheme: 2, field: 3, sky: "sun", wind: "light", temp: 24, hum: 55,
    shooter: "Mohammad Tajudeen", place: "Capri Range", notes: "", weapon: "Beretta DT11", ammo: "RC4 24g", choke1: "3/4", choke2: "Full", ver: "7.0.7",
    dirs: app.blank("-"), res: app.blank("-"), t1: new Array(N).fill(null), t2: new Array(N).fill(null), call: new Array(N).fill(null), tmic: new Array(N).fill(""), nt: new Array(N).fill(0)
  }, o.base || {});
  const n = o.targets == null ? N : o.targets;
  // directions: each station gets R,R,S,L,L in a shuffled order unless o.violate
  const perStation = [];
  for (let s = 0; s < 5; s++) { const a = ["R", "R", "S", "L", "L"]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } perStation.push(a); }
  const used = [0, 0, 0, 0, 0];
  let dirs = "", res = "";
  for (let i = 0; i < N; i++) {
    const s = app.stnOf(r, i);
    if (i < n) {
      let d = perStation[s][used[s]++];
      if (o.violate && i < 5) d = "R";
      dirs += d;
      const x = rnd(); const st = x < 0.6 ? "G" : x < 0.85 ? "Y" : "R"; res += st;
      if (o.timed !== false && rnd() < 0.9) {
        r.t1[i] = Math.round((0.55 + rnd() * 0.35) * 1000) / 1000;
        if (st === "Y" || (st === "R" && rnd() < 0.5)) r.t2[i] = Math.round((r.t1[i] + 0.25 + rnd() * 0.4) * 1000) / 1000;
        r.call[i] = Math.round((88 + rnd() * 10) * 10) / 10; r.tmic[i] = rnd() < 0.5 ? "DJI Mic Mini 2" : "iPhone Microphone";
      }
      if (rnd() < 0.08) r.nt[i] = 1 + Math.floor(rnd() * 2);
    } else { dirs += "-"; res += "-"; }
  }
  r.dirs = dirs; r.res = res;
  return r;
}
const rounds = [
  mkRound(1, {}),
  mkRound(2, { targets: 12 }),
  mkRound(3, { timed: false, base: { scheme: 5, startStn: 4, sky: "overcast", wind: "calm", temp: null, hum: null, notes: 'Windy, "gusty" afternoon' } }),
  mkRound(4, { targets: 0 }),
  mkRound(5, { base: { scheme: 7, startStn: 3, field: null, type: "Competition", place: "Al Ain, Range 2", notes: "line1\nline2" } }),
  mkRound(6, { targets: 17, violate: true, base: { scheme: 10, startStn: 2 } }),
  mkRound(7, { targets: 20, base: { scheme: 1, startStn: 5 } })
];
const N = app.N, D = ["R", "S", "L"];
const w = (n, o) => fs.writeFileSync(path.join(outDir, n), JSON.stringify(o, null, 1));
const roundFx = rounds.map(r => ({
  round: r,
  doc: (() => { const d = app.toDoc(r); delete d.updatedAt; return d; })(),
  score: app.score(r), counts: app.counts(r), recorded: app.recorded(r), dirsRecorded: app.dirsRecorded(r),
  stations: Array.from({ length: N }, (_, i) => app.stnOf(r, i)),
  stationCounts: [0, 1, 2, 3, 4].map(s => app.stationCounts(r, s, -1)),
  stationOver: [0, 1, 2, 3, 4].map(s => app.stationOver(r, s)),
  isFull: Array.from({ length: N }, (_, i) => D.map(d => app.isFull(r, i, d))),
  odds: Array.from({ length: N }, (_, i) => app.dirOdds(r, i)),
  predict: app.predict(r),
  brkShot: Array.from({ length: N }, (_, i) => app.brkShot(r, i)),
  brk: Array.from({ length: N }, (_, i) => app.brkFor(r, i)),
  csv: app.csvFor([r], false),
  stats: app.statsOf([r]),
  analyse: app.analyse([r])
}));
const schemes = {};
for (let k = 1; k <= 10; k++) { schemes[k] = []; for (let s = 1; s <= 5; s++) for (const d of D) schemes[k].push({ stn: s, d, ...app.trapFor(k, s, d) }); }
const grades = [-1, 0, 0.1, 0.29, 0.3, 0.49, 0.5, 0.74, 0.75, 1].map(p => ({ p, g: app.grade(p) }));
// break distance under several settings
const brk = { defaults: Object.assign({}, app.BRK), shotTime: {}, distance: [] };
const settingsList = [{}, { vs: 380, size: "7" }, { vs: 415, size: "8" }, { vs: 400, size: "9", v: 30, delay: 170 }];
settingsList.forEach((st, si) => {
  app.setBrk(Object.assign({}, brk.defaults, st));
  brk.shotTime[si] = { settings: Object.assign({}, brk.defaults, st), at: [0, 0.5, 1, 1.5, 2, 5, 10, 17.3, 30, 45, 60, 79, 100].map(x => ({ x, t: app.shotTime(x) })) };
  for (const scheme of [1, 2, 5, 7, 10]) for (let stn = 1; stn <= 5; stn++) for (const d of D) for (const t of [0.3, 0.55, 0.704, 0.9, 1.25, 2.4, null])
    brk.distance.push({ si, scheme, stn, d, t, m: app.breakDist(scheme, stn, d, t) });
});
app.setBrk(brk.defaults);
// session ids and initials
app.setRounds([{ id: "x1", sessionId: "20261022-0930-MT" }, { id: "x2", sessionId: "20261022-0930-MT-2" }]);
const sessions = {
  initials: ["", "   ", "Mohammad", "Mohammad Tajudeen", "a b c d", "  yugan   k  ", "ab"].map(n => ({ name: n, out: app.initials(n) })),
  genSid: [
    { r: { id: "n1", date: "2026-10-22", startTime: "09:30", shooter: "Mohammad Tajudeen" } },
    { r: { id: "x1", date: "2026-10-22", startTime: "09:30", shooter: "Mohammad Tajudeen" } },
    { r: { id: "n2", date: "2026-01-05", startTime: "", shooter: "" } },
    { r: { id: "n3", date: "2026-10-22", startTime: "14:05", shooter: "Khalid" } }
  ].map(c => ({ ...c, out: app.genSid(c.r) }))
};
app.setRounds([]);
// norm (document import) on messy inputs
const normCases = [
  { id: "d0", doc: { date: "2026-10-01", createdAt: "2026-10-01T05:00:00.000Z" } },
  { id: "d1", doc: { date: "2026-10-01", createdAt: "2026-10-01T05:00:00.000Z", startStn: 9, scheme: 99, session: "2", field: null, temp: 31.5, hum: null, dirs: "RSL", res: "GGG", t1: [0.7, "x", null, 0.81], t2: "no", call: [90, null], tmic: ["DJI", 5], nt: [2, -1, 1.6, 0] } },
  { id: "d2", doc: { date: "2026-10-01", createdAt: "2026-10-01T05:00:00.000Z", startStn: 5, scheme: 10, session: 3, field: 1, dirs: "RRSLLRRSLLRRSLLRRSLLRRSLL", res: "GYRGYRGYRGYRGYRGYRGYRGYRG", t1: new Array(30).fill(0.6), t2: [], type: "Competition", sky: "rain", wind: "strong", shooter: "A B", place: "P", notes: "n", weapon: "w", ammo: "a", choke1: "c1", choke2: "c2", ver: "6.9", uid: "ignored", startTime: "07:15", sessionId: "S-1" } },
  { id: "d3", doc: { date: "2026-10-01", createdAt: "2026-10-01T05:00:00.000Z", startStn: 0, scheme: 3.5, dirs: "RRSLLRRSLLRRSLLRRSLLRRSL", nt: [1, 1, 1] } }
];
const norm = normCases.map(c => ({ ...c, out: app.norm(c.id, c.doc) }));


// ---- multi-round analysis sets (trap analysis needs >= 30 timed first shots for the geometry fit) ----
const extra = [11, 12, 13, 14, 15, 16].map(seed => mkRound(seed, { base: { scheme: 2, startStn: 1 + (seed % 5), date: "2026-10-" + String(seed).padStart(2, "0"), createdAt: "2026-10-" + String(seed).padStart(2, "0") + "T06:00:00.000Z" } }));
const partial = mkRound(21, { targets: 9, base: { scheme: 2, date: "2026-10-21", createdAt: "2026-10-21T06:00:00.000Z" } });
const otherScheme = mkRound(22, { base: { scheme: 7, date: "2026-10-22", createdAt: "2026-10-22T06:00:00.000Z" } });
const untimed = mkRound(23, { timed: false, base: { scheme: 2, date: "2026-10-23", createdAt: "2026-10-23T06:00:00.000Z" } });
function strip(h) { return h.replace(/<\/?b>/g, ""); }
function overview(list) {
  const full = list.filter(r => app.recorded(r) === N), all = app.statsOf(list);
  let best = 0, sum = 0, g = 0, y = 0;
  full.forEach(r => { const sc = app.score(r); sum += sc; if (sc > best) best = sc; });
  list.forEach(r => { const c = app.counts(r); g += c.G; y += c.Y; });
  return { rounds: list.length, fullRounds: full.length, avgScore: full.length ? (sum / full.length).toFixed(1) : null, best: full.length ? best : null,
           hitRate: app.pct(all.hit, all.n), firstBarrel: app.pct(g, all.n), secondBarrel: app.pct(y, all.n) };
}
function trend(list) {
  return list.filter(r => app.recorded(r) === N).sort((a, b) => a.createdAt < b.createdAt ? -1 : 1).slice(-14).map(r => ({ id: r.id, date: r.date, score: app.score(r) }));
}
const sets = [
  { name: "six full scheme 2 + partial + other scheme + untimed", list: [...extra, partial, otherScheme, untimed] },
  { name: "two rounds, no fit", list: [rounds[0], rounds[1]] },
  { name: "empty", list: [rounds[3]] },
  { name: "other scheme only", list: [otherScheme, rounds[4]] }
].map(st => {
  const dom = app.dominantScheme(st.list);
  const ts = dom == null ? null : app.trapStats(st.list, dom);
  return { name: st.name, rounds: st.list, schemeCounts: app.schemeCounts(st.list), dominant: dom, overview: overview(st.list), trend: trend(st.list),
           trapStats: ts, findings: ts ? app.trapFindings(ts).map(strip) : [] };
});
fs.mkdirSync(outDir, { recursive: true });
w("analysis.json", sets);
w("schemes.json", { schemes, quota: app.QUOTA, predFrom: app.PRED_FROM, grades });
w("rounds.json", roundFx);
w("break.json", brk);
w("sessions.json", sessions);
w("norm.json", norm);
console.log("wrote fixtures:", fs.readdirSync(outDir).join(", "));
console.log("sample: round1 score", roundFx[0].score, "recorded", roundFx[0].recorded, "brk[0]", roundFx[0].brk[0], "shotTime(30)", brk.shotTime[0].at.find(a => a.x === 30).t);
