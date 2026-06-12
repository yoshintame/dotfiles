import { describe, expect, test } from "bun:test";

import { normalizeCwd, projectDir, projectHash, sessionJsonlPath } from "./project-hash.ts";

describe("projectHash", () => {
  test("maps every separator and dot to a dash", () => {
    expect(projectHash("/Users/yoshintame/Development")).toBe("-Users-yoshintame-Development");
  });

  test("leading slash becomes a leading dash", () => {
    expect(projectHash("/a")).toBe("-a");
  });

  test("a dot-directory yields a double dash (no dash collapsing)", () => {
    expect(projectHash("/Users/yoshintame/.dotfiles")).toBe("-Users-yoshintame--dotfiles");
  });

  test("underscores and dots are replaced individually", () => {
    expect(projectHash("/a/b.c_d")).toBe("-a-b-c-d");
  });

  test("at-sign (worktree names like senate@crm-frontend) is replaced", () => {
    expect(projectHash("/Users/yoshintame/.local/share/worktrees/senate@crm-frontend/persist-rework")).toBe(
      "-Users-yoshintame--local-share-worktrees-senate-crm-frontend-persist-rework",
    );
  });

  test("existing hyphens and alphanumerics are preserved", () => {
    expect(projectHash("/Users/x/my-repo-2")).toBe("-Users-x-my-repo-2");
  });

  test("trailing slashes are normalized away before hashing", () => {
    expect(projectHash("/a/b/")).toBe("-a-b");
    expect(projectHash("/a/b///")).toBe("-a-b");
  });

  test("a long path still maps char-for-char (>200 chars, no native truncation replicated)", () => {
    const deep = "/Users/yoshintame/" + Array.from({ length: 40 }, (_, i) => `segment-number-${i}`).join("/");
    expect(deep.length).toBeGreaterThan(200);
    expect(projectHash(deep)).toBe(deep.replace(/[^a-zA-Z0-9]/g, "-"));
  });

  describe("golden cases observed in ~/.claude/projects", () => {
    const cases: Array<[string, string]> = [
      ["/Users/yoshintame/.dotfiles", "-Users-yoshintame--dotfiles"],
      ["/Users/yoshintame/Development/work/senate/senate@docs", "-Users-yoshintame-Development-work-senate-senate-docs"],
      ["/Users/yoshintame/Development/work/senate/senate@e2e", "-Users-yoshintame-Development-work-senate-senate-e2e"],
      ["/Users/yoshintame/Documents/obsidian/yoshintame", "-Users-yoshintame-Documents-obsidian-yoshintame"],
      ["/private/tmp", "-private-tmp"],
    ];
    for (const [input, expected] of cases) {
      test(input, () => {
        expect(projectHash(input)).toBe(expected);
      });
    }
  });
});

describe("normalizeCwd", () => {
  test("keeps the root path intact", () => {
    expect(normalizeCwd("/")).toBe("/");
  });

  test("strips a trailing slash from a normal path", () => {
    expect(normalizeCwd("/a/b/")).toBe("/a/b");
  });
});

describe("path builders honour an explicit home", () => {
  test("projectDir composes root + hash", () => {
    expect(projectDir("/a/b", "/home/u")).toBe("/home/u/.claude/projects/-a-b");
  });

  test("sessionJsonlPath appends <id>.jsonl", () => {
    expect(sessionJsonlPath("/a/b", "sid-123", "/home/u")).toBe("/home/u/.claude/projects/-a-b/sid-123.jsonl");
  });
});
