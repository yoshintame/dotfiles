import { afterEach, describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import {
  chmodSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(packageDir, "../..");
const commitContext = join(
  repoRoot,
  "modules/home/agents-shared/config/skills/git-commit/scripts/gather-context.v5.sh",
);
const commitEdit = join(repoRoot, "modules/home/git/bin/git-commit-edit");
const commitAtomic = join(repoRoot, "modules/home/git/bin/git-commit-atomic");
const tmpRoots: string[] = [];

function run(
  command: string,
  args: string[],
  options: {
    cwd?: string;
    env?: Record<string, string>;
  } = {},
) {
  return execFileSync(command, args, {
    cwd: options.cwd,
    env: {
      ...process.env,
      LANG: "C",
      LC_ALL: "C",
      ...options.env,
    },
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trimEnd();
}

function runGit(repo: string, args: string[], env?: Record<string, string>) {
  return run("git", ["-C", repo, ...args], { env });
}

function makeRepo(prefix: string) {
  const repo = mkdtempSync(join(tmpdir(), `${prefix}-`));
  tmpRoots.push(repo);
  runGit(repo, ["init"]);
  runGit(repo, ["config", "user.name", "test"]);
  runGit(repo, ["config", "user.email", "test@example.com"]);
  runGit(repo, ["config", "commit.gpgsign", "false"]);
  runGit(repo, ["config", "core.editor", "true"]);
  writeFileSync(join(repo, "tracked.txt"), "base\n");
  runGit(repo, ["add", "--", "tracked.txt"]);
  runGit(repo, ["commit", "-m", "chore: init"]);
  return repo;
}

function writeRepoFile(repo: string, relativePath: string, content: string) {
  writeFileSync(join(repo, relativePath), content);
}

function createPrivateIndex(repo: string, name: string) {
  const indexPath = join(repo, ".git", name);
  runGit(repo, ["read-tree", "HEAD"], { GIT_INDEX_FILE: indexPath });
  writeFileSync(join(repo, ".git", `${name}.base`), `${runGit(repo, ["rev-parse", "HEAD"])}\n`);
  return indexPath;
}

function privateDiff(repo: string, indexPath: string, treeish?: string) {
  const args = ["diff", "--cached", "--name-status"];
  if (treeish) {
    args.push(treeish);
  }
  return runGit(repo, args, { GIT_INDEX_FILE: indexPath });
}

function statusShort(repo: string) {
  return runGit(repo, ["status", "--short"]);
}

function statusEntries(repo: string) {
  return statusShort(repo)
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.length > 0 && !line.startsWith("## "));
}

function runCommitContext(repo: string, indexPath?: string) {
  const args = indexPath ? ["--index", indexPath, repo] : [repo];
  return run(commitContext, args);
}

function runCommitEdit(repo: string, indexPath: string, message: string) {
  return run(commitEdit, [message], {
    env: {
      GIT_DIR: join(repo, ".git"),
      GIT_WORK_TREE: repo,
      GIT_INDEX_FILE: indexPath,
    },
  });
}

afterEach(() => {
  while (tmpRoots.length > 0) {
    const repo = tmpRoots.pop();
    if (repo) {
      rmSync(repo, { recursive: true, force: true });
    }
  }
});

describe("git-commit skill e2e", () => {
  test("git commit-context resets shared index to HEAD", () => {
    const repo = makeRepo("git-commit-context-reset");
    writeRepoFile(repo, "shared.txt", "shared staged in shared index\n");
    runGit(repo, ["add", "--", "shared.txt"]);

    expect(statusEntries(repo)).toEqual(["A  shared.txt"]);

    const output = runCommitContext(repo);

    expect(output).toContain("=== SHARED INDEX ===");
    expect(statusEntries(repo)).toEqual(["?? shared.txt"]);
  });

  test("git commit-edit clears shared index and updates private base", () => {
    const repo = makeRepo("git-commit-private-clears-shared");
    writeRepoFile(repo, "shared.txt", "shared staged in shared index\n");
    runGit(repo, ["add", "--", "shared.txt"]);
    const privateIndex = createPrivateIndex(repo, "private-index");
    writeRepoFile(repo, "private.txt", "private staged in private index\n");
    runGit(repo, ["add", "--", "private.txt"], { GIT_INDEX_FILE: privateIndex });

    runCommitEdit(repo, privateIndex, "feat: add private file");

    const head = runGit(repo, ["rev-parse", "HEAD"]);
    const base = readFileSync(`${privateIndex}.base`, "utf8");

    expect(statusEntries(repo)).toEqual(["?? shared.txt"]);
    expect(runGit(repo, ["diff", "--cached", "--name-status"])).toBe("");
    expect(base.trim()).toBe(head);
  });

  test("private commit does not leave inverted shared-index state", () => {
    const repo = makeRepo("git-commit-no-inverted-index");
    const privateIndex = createPrivateIndex(repo, "private-index");
    writeRepoFile(repo, "new.txt", "private staged in private index\n");
    runGit(repo, ["add", "--", "new.txt"], { GIT_INDEX_FILE: privateIndex });

    runCommitEdit(repo, privateIndex, "feat: add new file");

    expect(statusEntries(repo)).toEqual([]);
    expect(runGit(repo, ["diff", "--cached", "--name-status"])).toBe("");
  });

  test("stale private index rebases onto moved HEAD and keeps staged add", () => {
    const repo = makeRepo("git-commit-rebase-add");
    const privateA = createPrivateIndex(repo, "private-a");
    const privateB = createPrivateIndex(repo, "private-b");

    writeRepoFile(repo, "tracked.txt", "parallel head move\n");
    runGit(repo, ["add", "--", "tracked.txt"], { GIT_INDEX_FILE: privateA });
    runGit(repo, ["commit", "-m", "feat: parallel head move"], { GIT_INDEX_FILE: privateA });
    writeFileSync(`${privateA}.base`, `${runGit(repo, ["rev-parse", "HEAD"])}\n`);
    runGit(repo, ["read-tree", "HEAD"]);

    writeRepoFile(repo, "feature.txt", "feature staged in stale private index\n");
    runGit(repo, ["add", "--", "feature.txt"], { GIT_INDEX_FILE: privateB });

    const oldBase = readFileSync(`${privateB}.base`, "utf8").trim();
    const output = runCommitContext(repo, privateB);
    const head = runGit(repo, ["rev-parse", "HEAD"]);

    expect(output).toContain(`rebased: ${oldBase} -> ${head}`);
    expect(privateDiff(repo, privateB)).toBe("A\tfeature.txt");
    expect(runGit(repo, ["show", "HEAD:tracked.txt"])).toBe("parallel head move");
  });

  test("stale private index rebases and keeps staged delete", () => {
    const repo = makeRepo("git-commit-rebase-delete");
    writeRepoFile(repo, "obsolete.txt", "obsolete\n");
    runGit(repo, ["add", "--", "obsolete.txt"]);
    runGit(repo, ["commit", "-m", "chore: add obsolete file"]);

    const privateA = createPrivateIndex(repo, "private-a");
    const privateB = createPrivateIndex(repo, "private-b");

    renameSync(join(repo, "obsolete.txt"), join(repo, "obsolete.txt.deleted"));
    runGit(repo, ["add", "-u", "--", "obsolete.txt"], { GIT_INDEX_FILE: privateB });

    writeRepoFile(repo, "tracked.txt", "parallel head move\n");
    runGit(repo, ["add", "--", "tracked.txt"], { GIT_INDEX_FILE: privateA });
    runGit(repo, ["commit", "-m", "feat: parallel head move"], { GIT_INDEX_FILE: privateA });
    writeFileSync(`${privateA}.base`, `${runGit(repo, ["rev-parse", "HEAD"])}\n`);
    runGit(repo, ["read-tree", "HEAD"]);

    const output = runCommitContext(repo, privateB);

    expect(output).toContain("rebased:");
    expect(privateDiff(repo, privateB)).toBe("D\tobsolete.txt");
  });

  test("same private index supports sequential commits", () => {
    const repo = makeRepo("git-commit-sequential");
    const privateIndex = createPrivateIndex(repo, "private-index");

    writeRepoFile(repo, "first.txt", "first commit\n");
    runGit(repo, ["add", "--", "first.txt"], { GIT_INDEX_FILE: privateIndex });
    runCommitEdit(repo, privateIndex, "feat: first private commit");

    writeRepoFile(repo, "second.txt", "second commit\n");
    runGit(repo, ["add", "--", "second.txt"], { GIT_INDEX_FILE: privateIndex });

    const output = runCommitContext(repo, privateIndex);

    expect(output).not.toContain("rebased:");
    expect(privateDiff(repo, privateIndex)).toBe("A\tsecond.txt");

    runCommitEdit(repo, privateIndex, "feat: second private commit");

    const head = runGit(repo, ["rev-parse", "HEAD"]);
    const base = readFileSync(`${privateIndex}.base`, "utf8");

    expect(base.trim()).toBe(head);
  });
});

type AtomicOptions = {
  auto?: boolean;
  env?: Record<string, string>;
  extraArgs?: string[];
};

function runAtomic(
  repo: string,
  message: string,
  files: string[] = [],
  patches: string[] = [],
  options: AtomicOptions = {},
) {
  const args: string[] = [];
  if (options.auto) args.push("--auto");
  if (options.extraArgs) args.push(...options.extraArgs);
  args.push(message, ...files);
  if (patches.length > 0) args.push("--", ...patches);
  return run(commitAtomic, args, {
    env: {
      GIT_DIR: join(repo, ".git"),
      GIT_WORK_TREE: repo,
      ...(options.env ?? {}),
    },
    cwd: repo,
  });
}

function writeFakeEditor(repo: string, body: string): string {
  const path = join(repo, "fake-editor.sh");
  writeFileSync(path, `#!/usr/bin/env bash\n${body}\n`);
  chmodSync(path, 0o755);
  return path;
}

describe("git-commit-atomic e2e", () => {
  test("commits new files", () => {
    const repo = makeRepo("atomic-new-files");
    writeRepoFile(repo, "added.txt", "fresh content\n");

    runAtomic(repo, "feat: add fresh file", ["added.txt"], [], { auto: true });

    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("feat: add fresh file");
    expect(runGit(repo, ["show", "HEAD:added.txt"])).toBe("fresh content");
    expect(statusEntries(repo)).toEqual([]);
  });

  test("commits modifications", () => {
    const repo = makeRepo("atomic-modifications");
    writeRepoFile(repo, "tracked.txt", "updated\n");

    runAtomic(repo, "fix: update tracked", ["tracked.txt"], [], { auto: true });

    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("fix: update tracked");
    expect(runGit(repo, ["show", "HEAD:tracked.txt"])).toBe("updated");
    expect(statusEntries(repo)).toEqual([]);
  });

  test("ignores unrelated staged entries in shared index", () => {
    const repo = makeRepo("atomic-isolation");
    writeRepoFile(repo, "noise.txt", "noise pre-staged in shared index\n");
    runGit(repo, ["add", "--", "noise.txt"]);

    writeRepoFile(repo, "feature.txt", "feature payload\n");
    runAtomic(repo, "feat: feature only", ["feature.txt"], [], { auto: true });

    expect(runGit(repo, ["log", "-1", "--name-only", "--pretty="]).trim()).toBe("feature.txt");
    expect(runGit(repo, ["ls-tree", "-r", "HEAD", "--name-only"]).split("\n").sort()).toEqual([
      "feature.txt",
      "tracked.txt",
    ]);
    expect(statusEntries(repo).sort()).toEqual(["?? noise.txt"]);
  });

  test("does not block when shared .git/index.lock is held by another process", () => {
    const repo = makeRepo("atomic-shared-lock-isolation");
    writeRepoFile(repo, "isolated.txt", "no contention\n");
    const lockPath = join(repo, ".git", "index.lock");
    writeFileSync(lockPath, "");
    try {
      runAtomic(repo, "chore: bypass shared lock", ["isolated.txt"], [], { auto: true });
    } finally {
      rmSync(lockPath, { force: true });
    }
    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("chore: bypass shared lock");
    expect(runGit(repo, ["show", "HEAD:isolated.txt"])).toBe("no contention");
  });

  test("applies single patch", () => {
    const repo = makeRepo("atomic-patch-single");
    writeRepoFile(repo, "tracked.txt", "base\nadded line\n");
    const patch = join(repo, "p.patch");
    writeFileSync(patch, `${runGit(repo, ["diff", "tracked.txt"])}\n`);
    writeRepoFile(repo, "tracked.txt", "base\nadded line\nstray edit\n");

    runAtomic(repo, "feat: apply patch", [], [patch], { auto: true });

    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("feat: apply patch");
    expect(runGit(repo, ["show", "HEAD:tracked.txt"])).toBe("base\nadded line");
  });

  test("mixes whole-file edits with patches in one commit", () => {
    const repo = makeRepo("atomic-mixed");
    writeRepoFile(repo, "second.txt", "second base\n");
    runGit(repo, ["add", "--", "second.txt"]);
    runGit(repo, ["commit", "-m", "chore: add second"]);

    writeRepoFile(repo, "tracked.txt", "fully replaced\n");
    writeRepoFile(repo, "second.txt", "second base\nappended\n");
    const patch = join(repo, "second.patch");
    writeFileSync(patch, `${runGit(repo, ["diff", "second.txt"])}\n`);
    runGit(repo, ["checkout", "--", "second.txt"]);

    runAtomic(repo, "feat: mix whole and patch", ["tracked.txt"], [patch], { auto: true });

    expect(runGit(repo, ["show", "HEAD:tracked.txt"])).toBe("fully replaced");
    expect(runGit(repo, ["show", "HEAD:second.txt"])).toBe("second base\nappended");
    const files = runGit(repo, ["show", "--name-only", "--pretty=", "HEAD"])
      .split("\n")
      .filter(Boolean)
      .sort();
    expect(files).toEqual(["second.txt", "tracked.txt"]);
  });

  test("retries via CAS when HEAD moves between snapshot and update-ref", () => {
    const repo = makeRepo("atomic-cas-retry");
    writeRepoFile(repo, "tracked.txt", "base\npatched\n");
    const patch = join(repo, "p.patch");
    writeFileSync(patch, `${runGit(repo, ["diff", "tracked.txt"])}\n`);
    runGit(repo, ["checkout", "--", "tracked.txt"]);

    writeRepoFile(repo, "competitor.txt", "outside change\n");
    runGit(repo, ["add", "--", "competitor.txt"]);
    runGit(repo, ["commit", "-m", "chore: head bump from peer"]);

    runAtomic(repo, "feat: under HEAD move", [], [patch], { auto: true });

    expect(runGit(repo, ["log", "-2", "--pretty=%s"]).split("\n")).toEqual([
      "feat: under HEAD move",
      "chore: head bump from peer",
    ]);
    expect(runGit(repo, ["show", "HEAD:tracked.txt"])).toBe("base\npatched");
    expect(runGit(repo, ["show", "HEAD:competitor.txt"])).toBe("outside change");
  });

  test("rejects malformed patch with clear error", () => {
    const repo = makeRepo("atomic-bad-patch");
    const patch = join(repo, "bad.patch");
    writeFileSync(patch, "not a real diff\n");

    let threw = false;
    try {
      runAtomic(repo, "feat: nope", [], [patch], { auto: true });
    } catch (err) {
      threw = true;
      const stderr = (err as { stderr?: Buffer | string }).stderr?.toString() ?? "";
      expect(stderr.length).toBeGreaterThan(0);
    }
    expect(threw).toBe(true);
    expect(runGit(repo, ["log", "--oneline"]).split("\n")).toHaveLength(1);
  });

  test("opens editor on commit message and uses edited result by default", () => {
    const repo = makeRepo("atomic-editor-preview");
    const editor = writeFakeEditor(repo, 'printf "\\nedited-by-fake-editor\\n" >> "$1"');
    runGit(repo, ["config", "core.editor", editor]);

    writeRepoFile(repo, "x.txt", "x\n");
    runAtomic(repo, "feat: original", ["x.txt"]);

    const msg = runGit(repo, ["log", "-1", "--pretty=%B"]);
    expect(msg).toContain("feat: original");
    expect(msg).toContain("edited-by-fake-editor");
  });

  test("--auto skips editor invocation entirely", () => {
    const repo = makeRepo("atomic-auto");
    const sentinel = join(repo, "editor-was-called");
    const editor = writeFakeEditor(
      repo,
      `touch "${sentinel}"\nprintf "\\nshould-not-appear\\n" >> "$1"`,
    );
    runGit(repo, ["config", "core.editor", editor]);

    writeRepoFile(repo, "y.txt", "y\n");
    runAtomic(repo, "feat: clean", ["y.txt"], [], { auto: true });

    const msg = runGit(repo, ["log", "-1", "--pretty=%B"]).trim();
    expect(msg).toBe("feat: clean");
    expect(existsSync(sentinel)).toBe(false);
  });

  test("--signoff appends Signed-off-by trailer", () => {
    const repo = makeRepo("atomic-signoff");
    runGit(repo, ["config", "user.name", "Test User"]);
    runGit(repo, ["config", "user.email", "test@example.com"]);

    writeRepoFile(repo, "x.txt", "x\n");
    runAtomic(repo, "feat: signed", ["x.txt"], [], { auto: true, extraArgs: ["-s"] });

    const msg = runGit(repo, ["log", "-1", "--pretty=%B"]);
    expect(msg).toContain("feat: signed");
    expect(msg).toContain("Signed-off-by: Test User <test@example.com>");
  });

  test("--no-verify accepted as no-op (plumbing flow never invokes hooks)", () => {
    const repo = makeRepo("atomic-no-verify");
    const hook = join(repo, ".git", "hooks", "pre-commit");
    writeFileSync(hook, "#!/bin/sh\necho 'hook should never fire' >&2\nexit 1\n");
    chmodSync(hook, 0o755);

    writeRepoFile(repo, "x.txt", "x\n");
    runAtomic(repo, "chore: hook bypass", ["x.txt"], [], {
      auto: true,
      extraArgs: ["--no-verify"],
    });

    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("chore: hook bypass");
  });

  test("--no-edit runs pre-commit hooks and commits without opening an editor", () => {
    const repo = makeRepo("atomic-no-edit-hooks");
    const hookRan = join(repo, "hook-ran");
    const hook = join(repo, ".git", "hooks", "pre-commit");
    writeFileSync(hook, `#!/bin/sh\ntouch "${hookRan}"\nexit 0\n`);
    chmodSync(hook, 0o755);
    const editorCalled = join(repo, "editor-was-called");
    const editor = writeFakeEditor(repo, `touch "${editorCalled}"`);
    runGit(repo, ["config", "core.editor", editor]);

    writeRepoFile(repo, "x.txt", "x\n");
    runAtomic(repo, "feat: no-edit", ["x.txt"], [], { extraArgs: ["--no-edit"] });

    expect(runGit(repo, ["log", "-1", "--pretty=%s"])).toBe("feat: no-edit");
    expect(runGit(repo, ["show", "HEAD:x.txt"])).toBe("x");
    expect(existsSync(hookRan)).toBe(true);
    expect(existsSync(editorCalled)).toBe(false);
  });

  test("--no-edit aborts the commit when a pre-commit hook fails", () => {
    const repo = makeRepo("atomic-no-edit-hook-fail");
    const hook = join(repo, ".git", "hooks", "pre-commit");
    writeFileSync(hook, "#!/bin/sh\nexit 1\n");
    chmodSync(hook, 0o755);

    writeRepoFile(repo, "x.txt", "x\n");
    let threw = false;
    try {
      runAtomic(repo, "feat: should be blocked", ["x.txt"], [], {
        extraArgs: ["--no-edit"],
      });
    } catch {
      threw = true;
    }
    expect(threw).toBe(true);
    expect(runGit(repo, ["log", "--oneline"]).split("\n")).toHaveLength(1);
  });

  test("--auto and --no-edit are mutually exclusive", () => {
    const repo = makeRepo("atomic-mutually-exclusive");
    writeRepoFile(repo, "x.txt", "x\n");

    let threw = false;
    try {
      runAtomic(repo, "feat: nope", ["x.txt"], [], {
        auto: true,
        extraArgs: ["--no-edit"],
      });
    } catch (err) {
      threw = true;
      const stderr = (err as { stderr?: Buffer | string }).stderr?.toString() ?? "";
      expect(stderr).toContain("mutually exclusive");
    }
    expect(threw).toBe(true);
    expect(runGit(repo, ["log", "--oneline"]).split("\n")).toHaveLength(1);
  });

  test("--author overrides commit author", () => {
    const repo = makeRepo("atomic-author");
    writeRepoFile(repo, "x.txt", "x\n");

    runAtomic(repo, "feat: with author", ["x.txt"], [], {
      auto: true,
      extraArgs: ["--author", "Alice <alice@example.org>"],
    });

    expect(runGit(repo, ["log", "-1", "--pretty=%an <%ae>"])).toBe("Alice <alice@example.org>");
  });

  test("--allow-empty-message lets the editor return an empty string", () => {
    const repo = makeRepo("atomic-allow-empty");
    const editor = writeFakeEditor(repo, ': > "$1"');
    runGit(repo, ["config", "core.editor", editor]);

    writeRepoFile(repo, "x.txt", "x\n");
    runAtomic(repo, "feat: this gets erased", ["x.txt"], [], {
      extraArgs: ["--allow-empty-message"],
    });

    const msg = runGit(repo, ["log", "-1", "--pretty=%B"]).replace(/\s/g, "");
    expect(msg).toBe("");
  });

  test("rejects unsupported flags rather than silently passing them through", () => {
    const repo = makeRepo("atomic-bad-flag");
    writeRepoFile(repo, "x.txt", "x\n");

    let threw = false;
    try {
      runAtomic(repo, "feat: nope", ["x.txt"], [], {
        auto: true,
        extraArgs: ["--this-flag-does-not-exist"],
      });
    } catch (err) {
      threw = true;
      const stderr = (err as { stderr?: Buffer | string }).stderr?.toString() ?? "";
      expect(stderr).toContain("unsupported flag");
      expect(stderr).toContain("--this-flag-does-not-exist");
    }
    expect(threw).toBe(true);
    expect(runGit(repo, ["log", "--oneline"]).split("\n")).toHaveLength(1);
  });

  test("parallel kitten/passport scenario lands both commits with correct attribution", async () => {
    for (let iter = 0; iter < 10; iter++) {
      const repo = makeRepo(`atomic-parallel-${iter}`);
      writeRepoFile(repo, "kitten.txt", "kitten payload\n");
      writeRepoFile(repo, "passport.txt", "passport payload\n");

      const kittenP = new Promise<void>((resolveK, rejectK) => {
        setTimeout(() => {
          try {
            runAtomic(repo, "docs(kitten): add kitten payload", ["kitten.txt"], [], {
              auto: true,
            });
            resolveK();
          } catch (e) {
            rejectK(e);
          }
        }, 0);
      });
      const passportP = new Promise<void>((resolveP, rejectP) => {
        setTimeout(() => {
          try {
            runAtomic(repo, "docs(passport): add passport payload", ["passport.txt"], [], {
              auto: true,
            });
            resolveP();
          } catch (e) {
            rejectP(e);
          }
        }, 0);
      });
      await Promise.all([kittenP, passportP]);

      const log = runGit(repo, ["log", "--pretty=%s"]).split("\n").sort();
      expect(log).toEqual([
        "chore: init",
        "docs(kitten): add kitten payload",
        "docs(passport): add passport payload",
      ]);
      expect(runGit(repo, ["show", "HEAD:kitten.txt"])).toBe("kitten payload");
      expect(runGit(repo, ["show", "HEAD:passport.txt"])).toBe("passport payload");

      for (const sha of runGit(repo, ["log", "--pretty=%H", "-2"]).split("\n")) {
        const subj = runGit(repo, ["log", "-1", "--pretty=%s", sha]);
        const files = runGit(repo, ["show", "--name-only", "--pretty=", sha])
          .split("\n")
          .filter(Boolean);
        if (subj.includes("kitten")) {
          expect(files).toEqual(["kitten.txt"]);
        } else if (subj.includes("passport")) {
          expect(files).toEqual(["passport.txt"]);
        }
      }
    }
  });
});
