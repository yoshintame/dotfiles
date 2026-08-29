import type { BttTrigger } from "./codegen.ts";

export interface BttClientOptions {
  url: string;
  sharedSecret?: string;
}

export class BttClient {
  public constructor(private readonly opts: BttClientOptions) {}

  private buildUrl(path: string, params: Record<string, string>): string {
    const base = new URL(path, this.opts.url);
    const parts: string[] = [];
    if (this.opts.sharedSecret) parts.push(`shared_secret=${encodeURIComponent(this.opts.sharedSecret)}`);
    for (const [key, value] of Object.entries(params)) parts.push(`${key}=${encodeURIComponent(value)}`);
    return parts.length > 0 ? `${base.toString()}?${parts.join("&")}` : base.toString();
  }

  public async getTriggers(triggerType: string): Promise<BttTrigger[]> {
    const url = this.buildUrl("/get_triggers/", { trigger_type: triggerType });
    const res = await fetch(url);
    if (!res.ok) throw new Error(`get_triggers failed: ${res.status} ${await res.text()}`);
    const text = await res.text();
    if (!text.trim()) return [];
    return JSON.parse(text) as BttTrigger[];
  }

  public async addTrigger(payload: BttTrigger): Promise<void> {
    const url = this.buildUrl("/add_new_trigger/", { json: JSON.stringify(payload) });
    const res = await fetch(url);
    if (!res.ok) throw new Error(`add_new_trigger failed: ${res.status} ${await res.text()}`);
  }

  public async updateTrigger(uuid: string, payload: BttTrigger): Promise<void> {
    const url = this.buildUrl("/update_trigger/", { uuid, json: JSON.stringify(payload) });
    const res = await fetch(url);
    if (!res.ok) throw new Error(`update_trigger ${uuid} failed: ${res.status} ${await res.text()}`);
  }

  public async deleteTrigger(uuid: string): Promise<void> {
    const url = this.buildUrl("/delete_trigger/", { uuid });
    const res = await fetch(url);
    if (!res.ok && res.status !== 404) {
      throw new Error(`delete_trigger ${uuid} failed: ${res.status} ${await res.text()}`);
    }
  }
}
