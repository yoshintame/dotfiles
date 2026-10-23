import { basename, join } from "node:path";
import { $ } from "bun";

export interface DumpOptions {
  outDir: string;
  brewfile: string;
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
  receiptIds: Set<string>;
}

function asStrings(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (Array.isArray(value))
    return value.filter((v): v is string => typeof v === "string");
  return [];
}

async function getBrewManagedApps(): Promise<BrewManaged> {
  const names = new Set<string>();
  const receiptIds = new Set<string>();
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
            for (const id of [...asStrings(quit), ...asStrings(pkgutil)]) {
              receiptIds.add(id);
            }
          }
        }

        const json = JSON.stringify(artifact);
        for (const match of json.matchAll(/\/Applications\/([^/"]+)\.app/g)) {
          names.add(match[1]);
        }
      }
    }
  } catch {}
  return { names, receiptIds };
}

async function appIds(appPath: string): Promise<string[]> {
  const ids: string[] = [];
  const bundleId = (
    await $`/usr/bin/defaults read ${join(appPath, "Contents/Info")} CFBundleIdentifier`
      .quiet()
      .nothrow()
      .text()
  ).trim();
  if (bundleId) ids.push(bundleId);
  const fileInfo = await $`/usr/sbin/pkgutil --file-info ${appPath}`
    .quiet()
    .nothrow()
    .text();
  for (const match of fileInfo.matchAll(/^pkgid: (.+)$/gm)) ids.push(match[1]);
  return ids;
}

async function isBrewOrMasManaged(
  appPath: string,
  receiptIds: Set<string>,
): Promise<boolean> {
  if (await Bun.file(join(appPath, "Contents/_MASReceipt/receipt")).exists())
    return true;
  return (await appIds(appPath)).some((id) => receiptIds.has(id));
}

async function getMasApps(brewfilePath: string): Promise<Set<string>> {
  const names = new Set<string>();
  const brewfile = Bun.file(brewfilePath);
  if (!(await brewfile.exists())) return names;
  const content = await brewfile.text();
  for (const line of content.split("\n")) {
    if (!line.startsWith("mas ")) continue;
    const match = line.match(/^mas "([^"]+)"/);
    if (match) names.add(match[1]);
  }
  return names;
}

export async function dump(opts: DumpOptions) {
  const { outDir, brewfile, appsDir, setappDir, ignore } = opts;

  await $`mkdir -p ${outDir}`.quiet();

  const setappApps = await readdirApps(setappDir).catch(() => [] as string[]);
  if (setappApps.length) {
    await Bun.write(
      join(outDir, "Appsfile.setapp"),
      `${setappApps.join("\n")}\n`,
    );
    console.log(`setapp: ${setappApps.length} apps`);
  }

  const { names: managed, receiptIds } = await getBrewManagedApps();
  for (const name of await getMasApps(brewfile)) managed.add(name);
  for (const name of ignore) managed.add(name);

  const managedLower = new Set([...managed].map((n) => n.toLowerCase()));

  const all = await readdirApps(appsDir);
  const unmanaged: string[] = [];
  for (const name of all) {
    if (managed.has(name) || managedLower.has(name.toLowerCase())) continue;
    if (await isBrewOrMasManaged(join(appsDir, `${name}.app`), receiptIds))
      continue;
    unmanaged.push(name);
  }

  await Bun.write(
    join(outDir, "Appsfile.unmanaged"),
    unmanaged.length ? `${unmanaged.join("\n")}\n` : "",
  );
  console.log(`unmanaged: ${unmanaged.length} apps`);
}
