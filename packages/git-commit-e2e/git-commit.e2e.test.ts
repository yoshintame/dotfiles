import { afterEach, describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const packageDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(packageDir, "../..");
const commitContext = join(repoRoot, "modules/git/bin/git-commit-context");
const commitEdit = join(repoRoot, "modules/git/bin/git-commit-edit");
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
