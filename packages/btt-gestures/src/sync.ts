import { buildTrigger, MANAGED_TAG } from "./codegen.ts";
import { BttClient } from "./rest-client.ts";
import { TriggerClass } from "./triggers.ts";
import { gestureUuid } from "./gesture-uuid.ts";
import type { Config } from "./schema.ts";

export interface SyncPlan {
  upsert: { uuid: string; id: string; trigger: string }[];
  delete: { uuid: string; description: string }[];
}

function isManaged(description: string | undefined): boolean {
  return Boolean(description?.includes(MANAGED_TAG));
}

export async function planSync(config: Config, sharedSecret: string | undefined): Promise<SyncPlan> {
  const client = new BttClient({ url: config.webserver.url, sharedSecret });
  const remote = await client.getTriggers(TriggerClass.trackpad);

  const desiredUuids = new Set(config.gestures.map((g) => gestureUuid(g.id)));

  const toDelete = remote
    .filter((t) => isManaged(t.BTTTriggerTypeDescription))
    .filter((t) => t.BTTUUID && !desiredUuids.has(t.BTTUUID))
    .map((t) => ({
      uuid: t.BTTUUID as string,
      description: t.BTTTriggerTypeDescription,
    }));

  const toUpsert = config.gestures.map((g) => ({
    uuid: gestureUuid(g.id),
    id: g.id,
    trigger: g.trigger,
  }));

  return { upsert: toUpsert, delete: toDelete };
}

export async function applySync(config: Config, sharedSecret: string | undefined): Promise<void> {
  const client = new BttClient({ url: config.webserver.url, sharedSecret });

  for (const gesture of config.gestures) {
    const uuid = gestureUuid(gesture.id);
    const payload = buildTrigger(gesture, { preset: config.preset });
    payload.BTTUUID = uuid;
    await client.deleteTrigger(uuid);
    await client.addTrigger(payload);
    console.log(`  ✓ ${gesture.id} (${gesture.trigger})`);
  }

  const plan = await planSync(config, sharedSecret);
  for (const stale of plan.delete) {
    await client.deleteTrigger(stale.uuid);
    console.log(`  ✗ stale ${stale.description}`);
  }

  console.log(`\n${config.gestures.length} synced, ${plan.delete.length} stale removed.`);
}
