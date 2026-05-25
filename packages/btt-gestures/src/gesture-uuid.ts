import { v5 as uuidV5 } from "uuid";

const NAMESPACE = "5b8e8a44-9c0f-4f1e-b6a1-bb8b8e8e8e8e";

export function gestureUuid(id: string): string {
  return uuidV5(`btt-gestures:${id}`, NAMESPACE).toUpperCase();
}
