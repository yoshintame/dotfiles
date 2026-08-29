import { buildTrigger, MANAGED_TAG } from "./codegen.ts";
import { BttClient } from "./rest-client.ts";
import { TriggerClass } from "./triggers.ts";
import { gestureUuid } from "./gesture-uuid.ts";
import type { Config } from "./schema.ts";

const NUKE_RETRY_LIMIT = 3;

function isManaged(description: string | undefined): boolean {
  return Boolean(description?.includes(MANAGED_TAG));
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function nukeManaged(client: BttClient, desiredUuids: readonly string[]): Promise<number> {
  let total = 0;

  for (const uuid of desiredUuids) await client.deleteTrigger(uuid);
  total += desiredUuids.length;

  for (let pass = 0; pass < NUKE_RETRY_LIMIT; pass++) {
    await sleep(300);
    const remote = await client.getTriggers(TriggerClass.trackpad);
    const stale = remote.filter((t) => t.BTTUUID && isManaged(t.BTTTriggerTypeDescription));
    if (stale.length === 0) return total;
    for (const t of stale) await client.deleteTrigger(t.BTTUUID as string);
    total += stale.length;
  }
  return total;
}

async function nukeAllTrackpad(client: BttClient): Promise<number> {
  let total = 0;
  for (let pass = 0; pass < NUKE_RETRY_LIMIT; pass++) {
    const remote = await client.getTriggers(TriggerClass.trackpad);
    if (remote.length === 0) return total;
    for (const t of remote) if (t.BTTUUID) await client.deleteTrigger(t.BTTUUID);
    total += remote.length;
    await sleep(100);
  }
  return total;
}

export interface SyncOptions {
  nukeAll?: boolean;
}

export async function applySync(
  config: Config,
  sharedSecret: string | undefined,
  opts: SyncOptions = {},
): Promise<void> {
  const client = new BttClient({ url: config.webserver.url, sharedSecret });
  const desiredUuids = config.gestures.map((g) => gestureUuid(g.id));

  const removed = opts.nukeAll ? await nukeAllTrackpad(client) : await nukeManaged(client, desiredUuids);
  console.log(`  ⊘ removed ${removed} ${opts.nukeAll ? "trackpad" : "managed"} trigger(s)`);

  await sleep(300);

  for (const gesture of config.gestures) {
    const uuid = gestureUuid(gesture.id);
    const payload = buildTrigger(gesture, { preset: config.preset, sound: config.feedback?.sound });
    payload.BTTUUID = uuid;
    await client.updateTrigger(uuid, payload);
    console.log(`  ✓ ${gesture.id} (${gesture.trigger})`);
  }

  console.log(`\n${config.gestures.length} synced, ${removed} removed.`);
}

export interface CleanOptions {
  filter?: (description: string | undefined, uuid: string) => boolean;
}

export async function clean(config: Config, sharedSecret: string | undefined, opts: CleanOptions = {}): Promise<number> {
  const client = new BttClient({ url: config.webserver.url, sharedSecret });
  const remote = await client.getTriggers(TriggerClass.trackpad);
  const predicate = opts.filter ?? ((d) => isManaged(d));

  const toDelete = remote.filter((t) => t.BTTUUID && predicate(t.BTTTriggerTypeDescription, t.BTTUUID));
  for (const t of toDelete) {
    await client.deleteTrigger(t.BTTUUID as string);
    console.log(`  ✗ ${t.BTTUUID?.slice(0, 8)}  ${t.BTTTriggerTypeDescription ?? "(no description)"}`);
  }
  return toDelete.length;
}
