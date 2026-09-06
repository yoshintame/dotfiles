import { afterEach, describe, expect, test } from "bun:test";
import { chmod, lstat, mkdtemp, mkdir, readFile, readlink, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const roots: string[] = [];
const runner = join(import.meta.dir, "run.ts");

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { force: true, recursive: true })));
});

async function fixture(mode: "success" | "failure" | "interrupt") {
  const root = await mkdtemp(join(tmpdir(), "apm-global-"));
  roots.push(root);
  const home = join(root, "home");
  const dotfiles = join(root, "dotfiles");
  const live = join(home, ".apm");
  const canonical = join(dotfiles, "modules/home/apm/config");
  const bin = join(root, "bin");
  await Promise.all([mkdir(live, { recursive: true }), mkdir(canonical, { recursive: true }), mkdir(bin)]);
  await writeFile(join(canonical, "apm.yml"), "name: prod\n");
  await writeFile(join(canonical, "apm.lock.yaml"), "version: prod\n");
  await symlink(join(canonical, "apm.yml"), join(live, "apm.yml"));
  await symlink(join(canonical, "apm.lock.yaml"), join(live, "apm.lock.yaml"));
  await writeFile(
    join(bin, "apm"),
    [
      "#!/bin/sh",
      'rm "$HOME/.apm/apm.lock.yaml"',
      'printf "version: next\\n" > "$HOME/.apm/apm.lock.yaml"',
      'rm "$HOME/.apm/apm.yml"',
      'printf "name: next\\n" > "$HOME/.apm/apm.yml"',
      mode === "interrupt" ? `touch "${join(root, "ready")}"` : "",
      mode === "interrupt" ? "trap 'exit 143' TERM" : "",
      mode === "interrupt" ? "while :; do sleep 1; done" : "",
      mode === "failure" ? "exit 17" : "exit 0",
    ].join("\n"),
  );
  await writeFile(
    join(bin, "mise"),
    [
      "#!/bin/sh",
      `ln -s "${join(canonical, "apm.yml")}" "${join(live, "apm.yml")}"`,
      `ln -s "${join(canonical, "apm.lock.yaml")}" "${join(live, "apm.lock.yaml")}"`,
    ].join("\n"),
  );
  await Promise.all([chmod(join(bin, "apm"), 0o755), chmod(join(bin, "mise"), 0o755)]);
  return { bin, canonical, home, live, root };
}

async function runFixture(mode: "success" | "failure") {
  const paths = await fixture(mode);
  const process = Bun.spawn(["bun", runner, "install", "-g"], {
    cwd: paths.root,
    env: { ...Bun.env, DOTFILES: paths.canonical.split("/modules/home/apm/config")[0], HOME: paths.home, PATH: `${paths.bin}:${Bun.env.PATH}` },
    stderr: "pipe",
    stdout: "pipe",
  });
  return { paths, process, stderr: await new Response(process.stderr).text(), stdout: await new Response(process.stdout).text() };
}

async function expectRepaired(paths: Awaited<ReturnType<typeof fixture>>) {
  expect(await readFile(join(paths.canonical, "apm.yml"), "utf8")).toBe("name: next\n");
  expect(await readFile(join(paths.canonical, "apm.lock.yaml"), "utf8")).toBe("version: next\n");
  expect((await lstat(join(paths.live, "apm.yml"))).isSymbolicLink()).toBeTrue();
  expect((await lstat(join(paths.live, "apm.lock.yaml"))).isSymbolicLink()).toBeTrue();
  expect(await readlink(join(paths.live, "apm.yml"))).toBe(join(paths.canonical, "apm.yml"));
  expect(await readlink(join(paths.live, "apm.lock.yaml"))).toBe(join(paths.canonical, "apm.lock.yaml"));
}

describe("global APM wrapper", () => {
  test("persists replaced files and restores both canonical links", async () => {
    const { paths, process, stderr } = await runFixture("success");
    expect(stderr).toBe("");
    expect(await process.exited).toBe(0);
    await expectRepaired(paths);
  });

  test("repairs links while preserving the APM failure status", async () => {
    const { paths, process, stderr } = await runFixture("failure");
    expect(stderr).toBe("");
    expect(await process.exited).toBe(17);
    await expectRepaired(paths);
  });

  test("repairs links after interruption", async () => {
    const paths = await fixture("interrupt");
    const process = Bun.spawn(["bun", runner, "install", "-g"], {
      cwd: paths.root,
      env: { ...Bun.env, DOTFILES: paths.canonical.split("/modules/home/apm/config")[0], HOME: paths.home, PATH: `${paths.bin}:${Bun.env.PATH}` },
      stderr: "pipe",
      stdout: "pipe",
    });
    await Bun.file(join(paths.root, "ready")).exists().then(async (ready) => {
      while (!ready) {
        await Bun.sleep(10);
        ready = await Bun.file(join(paths.root, "ready")).exists();
      }
    });
    process.kill("SIGTERM");
    expect(await process.exited).toBe(143);
    await expectRepaired(paths);
  });
});
