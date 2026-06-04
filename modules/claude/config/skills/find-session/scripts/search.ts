#!/usr/bin/env bun
import { fileURLToPath } from "node:url";

const ASSET = fileURLToPath(new URL("../assets/cc.sql", import.meta.url));

const RU_STOP = new Set("для и во в на с со по к ко у о об что как это не но а же ли от до из за при я мне меня мной ты".split(" "));
const EN_STOP = new Set("the for a an to of in on and or with is are my me i it this that".split(" "));

type Args = {
  synonyms: string[];
  kind?: string;
  tool?: string;
  limit: number;
  sessions: boolean;
  resume: boolean;
  noStem: boolean;
  showSql: boolean;
  distinct: boolean;
};

function parseArgs(argv: string[]): Args {
  const a: Args = { synonyms: [], limit: 40, sessions: false, resume: false, noStem: false, showSql: false, distinct: false };
  for (const t of argv) {
    if (t === "--sessions") a.sessions = true;
    else if (t === "--resume") { a.sessions = true; a.resume = true; }
    else if (t === "--no-stem") a.noStem = true;
    else if (t === "--distinct") a.distinct = true;
    else if (t === "--sql") a.showSql = true;
    else if (t.startsWith("--kind=")) a.kind = t.slice(7);
    else if (t.startsWith("--tool=")) { a.tool = t.slice(7); a.kind ??= "tool_use"; }
    else if (t.startsWith("--limit=")) a.limit = Math.max(1, parseInt(t.slice(8), 10) || 40);
    else if (t.startsWith("--")) { console.error(`unknown flag: ${t}`); process.exit(2); }
    else a.synonyms.push(t);
  }
  if (a.synonyms.length === 0) {
    console.error('usage: search.ts "<synonym phrase>" ["<synonym>" ...] [--kind=K] [--tool=NAME] [--sessions] [--resume] [--distinct] [--limit=N] [--no-stem] [--sql]');
    process.exit(2);
  }
  return a;
}

const tokenize = (phrase: string): string[] =>
  phrase.toLowerCase().split(/[^\p{L}\p{N}]+/u)
    .filter((w) => w.length >= 2 && !RU_STOP.has(w) && !EN_STOP.has(w));

const lang = (w: string): "russian" | "english" => (/[а-яё]/i.test(w) ? "russian" : "english");

// one synonym -> ordered loose-phrase ILIKE over its stemmed tokens: %a%b%
function clause(phrase: string, stem: boolean): string | null {
  const toks = tokenize(phrase);
  if (toks.length === 0) return null;
  const parts = toks.map((w) => (stem ? `stem('${w}','${lang(w)}')` : `'${w}'`));
  return `m.text ILIKE '%' || ${parts.join(" || '%' || ")} || '%'`;
}

function duck(sql: string, init = false): { ok: boolean; out: string; err: string } {
  const cmd = init ? ["duckdb", "-init", ASSET, "-c", sql] : ["duckdb", "-c", sql];
  const r = Bun.spawnSync(cmd, { stdout: "pipe", stderr: "pipe" });
  return { ok: r.exitCode === 0, out: r.stdout.toString(), err: r.stderr.toString() };
}

const args = parseArgs(Bun.argv.slice(2));
const stem = !args.noStem && duck("LOAD fts; SELECT 1;").ok;

const clauses = args.synonyms.map((s) => clause(s, stem)).filter((c): c is string => c !== null);
if (clauses.length === 0) { console.error("all synonyms reduced to stopwords"); process.exit(2); }

const view = args.kind && args.kind !== "user" ? "msg" : "me";
const where = [`(${clauses.join(") OR (")})`];
if (args.kind && view === "msg") where.push(`m.kind = '${args.kind}'`);
if (args.tool) where.push(`m.tool = '${args.tool}'`);

// dedup key: strip <ide_selection> block (dotall) + collapse whitespace
const NORM = "regexp_replace(regexp_replace(m.text, '<ide_selection>.*?</ide_selection>', '', 'gs'), '\\s+', ' ', 'g')";

const select = args.sessions
  ? `SELECT m.project, m.session_id, ${args.distinct ? `count(DISTINCT ${NORM})` : "count(*)"} AS hits,
       min(m.ts)::date AS first_seen, max(m.ts)::date AS last_seen${args.resume ? `,
       'claude --resume ' || m.session_id AS resume` : ""}
   FROM ${view} m WHERE ${where.join(" AND ")}
   GROUP BY m.project, m.session_id ORDER BY last_seen DESC LIMIT ${args.limit}`
  : `SELECT m.ts::date AS dt, m.project,
       left(regexp_replace(m.text, '\\s+', ' ', 'g'), 160) AS snippet
   FROM ${view} m WHERE ${where.join(" AND ")}
   ${args.distinct ? `QUALIFY row_number() OVER (PARTITION BY ${NORM} ORDER BY m.ts) = 1` : ""}
   ORDER BY m.ts DESC LIMIT ${args.limit}`;

const sql = `${stem ? "LOAD fts;\n" : ""}${select};`;

if (args.showSql) { console.log(sql); process.exit(0); }

const stems = stem
  ? args.synonyms.map((s) => `${s} → %${tokenize(s).map((w) => `${w}:${lang(w)[0]}`).join("%")}%`)
  : args.synonyms;
console.error(`view=${view} stem=${stem} distinct=${args.distinct} limit=${args.limit}\nterms: ${stems.join("  |  ")}`);

const r = duck(select.replace(/^/, stem ? "LOAD fts;\n" : ""), true);
process.stdout.write(r.out);
const realErr = r.err.split("\n").filter((l) => l.trim() && !l.includes("Loading resources")).join("\n");
if (realErr) { process.stderr.write(realErr + "\n"); if (!r.ok) process.exit(1); }
