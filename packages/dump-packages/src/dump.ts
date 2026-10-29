import { basename, join } from "node:path";
import { $ } from "bun";

export interface DumpOptions {
  outDir: string;
  appsDir: string;
  setappDir: string;
  ignore: Set<string>;
}

async function readdirApps(dir: string): Promise<string[]> {
  const glob = new Bun.Glob("*.app");
  const names: string[] = [];
  for await (const path of glob.scan({ cwd: dir, onlyFiles: false })) {
    if (!path.startsWith(".")) names.push(path.replace(".app", ""));
  }
  return names.sort();
}

interface BrewManaged {
  names: Set<string>;
  quitBundleIds: Set<string>;
  pkgIdPatterns: string[];
}

function asStrings(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (Array.isArray(value))
    return value.filter((v): v is string => typeof v === "string");
  return [];
}

async function getBrewManagedApps(): Promise<BrewManaged> {
  const names = new Set<string>();
  const quitBundleIds = new Set<string>();
  const pkgIdPatterns: string[] = [];
  try {
    const raw =
      await $`brew info --cask --json=v2 --installed 2>/dev/null`.text();
    const data = JSON.parse(raw);

    for (const cask of data.casks ?? []) {
      for (const artifact of cask.artifacts ?? []) {
        if (typeof artifact !== "object" || artifact === null) continue;

        for (const key of ["app", "suite"] as const) {
          for (const item of (artifact as Record<string, unknown[]>)[key] ??
            []) {
            const name =
              typeof item === "string"
                ? item
                : Array.isArray(item) && typeof item[0] === "string"
                  ? item[0]
                  : null;
            if (name?.includes(".app")) {
              names.add(basename(name).replace(".app", ""));
            }
          }
        }

        for (const key of ["uninstall", "zap"] as const) {
          for (const step of (artifact as Record<string, unknown[]>)[key] ??
            []) {
            if (typeof step !== "object" || step === null) continue;
            const { quit, pkgutil } = step as Record<string, unknown>;
            for (const id of asStrings(quit)) quitBundleIds.add(id);
            pkgIdPatterns.push(...asStrings(pkgutil));
          }
        }

        const json = JSON.stringify(artifact);
        for (const match of json.matchAll(/\/Applications\/([^/"]+)\.app/g)) {
          names.add(match[1]);
        }
      }
    }
  } catch {}
  return { names, quitBundleIds, pkgIdPatterns };
}

function matchesPattern(id: string, pattern: string): boolean {
  if (!pattern.includes("*")) return id === pattern;
  const regex = pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replaceAll("*", ".*");
  return new RegExp(`^${regex}$`).test(id);
}

async function appIds(
  appPath: string,
): Promise<{ bundleId: string; pkgIds: string[] }> {
  const bundleId = (
    await $`/usr/bin/defaults read ${join(appPath, "Contents/Info")} CFBundleIdentifier`
      .quiet()
      .nothrow()
      .text()
  ).trim();
  const fileInfo = await $`/usr/sbin/pkgutil --file-info ${appPath}`
    .quiet()
    .nothrow()
    .text();
  const pkgIds = [...fileInfo.matchAll(/^pkgid: (.+)$/gm)].map((m) => m[1]);
  return { bundleId, pkgIds };
}

async function isBrewOrMasManaged(
  appPath: string,
  brew: BrewManaged,
): Promise<boolean> {
  if (await Bun.file(join(appPath, "Contents/_MASReceipt/receipt")).exists())
    return true;
  const { bundleId, pkgIds } = await appIds(appPath);
  if (bundleId && brew.quitBundleIds.has(bundleId)) return true;
  return pkgIds.some((id) =>
    brew.pkgIdPatterns.some((pattern) => matchesPattern(id, pattern)),
  );
}

export async function dump(opts: DumpOptions) {
  const { outDir, appsDir, setappDir, ignore } = opts;

  await $`mkdir -p ${outDir}`.quiet();

  const setappApps = await readdirApps(setappDir).catch(() => [] as string[]);
  if (setappApps.length) {
    await Bun.write(
      join(outDir, "Appsfile.setapp"),
      `${setappApps.join("\n")}\n`,
    );
    console.log(`setapp: ${setappApps.length} apps`);
  }

  const brew = await getBrewManagedApps();
  const managed = new Set([...brew.names, ...ignore]);

  const managedLower = new Set([...managed].map((n) => n.toLowerCase()));

  const all = await readdirApps(appsDir);
  const unmanaged: string[] = [];
  for (const name of all) {
    if (managedLower.has(name.toLowerCase())) continue;
    if (await isBrewOrMasManaged(join(appsDir, `${name}.app`), brew))
      continue;
    unmanaged.push(name);
  }

  await Bun.write(
    join(outDir, "Appsfile.unmanaged"),
    unmanaged.length ? `${unmanaged.join("\n")}\n` : "",
  );
  console.log(`unmanaged: ${unmanaged.length} apps`);
}
