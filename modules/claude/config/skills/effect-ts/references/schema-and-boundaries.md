# Schema, branded types, parsing boundaries

## Parse unknown data at the boundary, not later

Any data crossing into your program (HTTP body, LSP response, file contents, env, MCP tool result, queue message) is `unknown`. Parse it once, then downstream code is typed.

```ts
// DO
import { Schema } from 'effect'

const User = Schema.Struct({
  id: Schema.UUID,
  email: Schema.String,
  createdAt: Schema.DateFromString,
})
type User = Schema.Schema.Type<typeof User>

const handleRequest = Effect.gen(function* () {
  const body = yield* httpClient.get('/user')           // unknown
  const user = yield* Schema.decodeUnknown(User)(body)  // User, typed
  return yield* process(user)
})
```

```ts
// DON'T
const body = yield* httpClient.get('/user')
const user = body as User                  // lie
const user2 = body as unknown as User       // longer lie
return yield* process(user)                 // crashes at runtime field access
```

## Brand entity IDs

A bare `string` for `userId` will silently accept `orderId`. Brands enforce nominal typing.

```ts
// DO
export const UserId = Schema.UUID.pipe(Schema.brand('@app/UserId'))
export type UserId = Schema.Schema.Type<typeof UserId>

export const OrderId = Schema.UUID.pipe(Schema.brand('@app/OrderId'))
export type OrderId = Schema.Schema.Type<typeof OrderId>

declare function findOrder(id: OrderId): Effect.Effect<Order, OrderNotFound>
findOrder(someUserId)  // ❌ TS error
```

```ts
// DON'T
export type UserId = string
export type OrderId = string
findOrder(someUserId)  // ✅ compiles, ❌ wrong
```

Namespace the brand (`@app/UserId`, `@yoshintame/extractor-runtime/SourceTxId`) so brands from different packages don't collide.

## `Schema.optional` / `optionalWith` / Option fields

| Want | Use |
|---|---|
| Field may be absent on input, decode as `T \| undefined` | `Schema.optional(T)` |
| Field may be `null` or absent | `Schema.optionalWith(T, { nullable: true })` |
| Field may be absent, decode as `Option<T>` | `Schema.optionalWith(T, { as: 'Option' })` |
| Field may be absent, decode with default | `Schema.optionalWith(T, { default: () => fallback })` |

```ts
// DO
const User = Schema.Struct({
  id: UserId,
  email: Schema.String,
  bio: Schema.optionalWith(Schema.String, { as: 'Option' }),  // Option<string>
  name: Schema.String.pipe(
    Schema.optionalWith({ nullable: true }),
    Schema.withDecodingDefault(() => '<unnamed>'),
  ),
})
```

```ts
// DON'T
const User = Schema.Struct({
  id: UserId,
  email: Schema.String,
  bio: Schema.Union(Schema.String, Schema.Null, Schema.Undefined),
  // No standard semantics, downstream consumers each handle null/undefined differently
})
```

## `Option<T>` in domain types, not `T | null`

```ts
// DO
type User = {
  readonly id: UserId
  readonly email: string
  readonly bio: Option.Option<string>
  readonly avatar: Option.Option<URL>
}

const greeting = (u: User) =>
  Option.match(u.bio, {
    onNone: () => `Hi, ${u.email}`,
    onSome: (bio) => `Hi, ${u.email} — ${bio}`,
  })
```

```ts
// DON'T
type User = {
  readonly id: UserId
  readonly email: string
  readonly bio: string | null
  readonly avatar: URL | undefined
}
// Now every consumer writes its own null check; one will be forgotten.
```

## Wrap nullable boundary values once with `Option.fromNullable`

```ts
// DO — at the API boundary, convert null/undefined to Option
const editor = Option.fromNullable(vscode.window.activeTextEditor)
return Option.match(editor, {
  onNone: () => Effect.fail(new NoEditorOpenError()),
  onSome: (ed) => useEditor(ed),
})
```

```ts
// DON'T — null check leaks into business logic
const editor = vscode.window.activeTextEditor
if (editor === null || editor === undefined) {
  return yield* new NoEditorOpenError()
}
return yield* useEditor(editor)
```

## `Schema.Class` for entities with computed properties

```ts
// DO — methods + computed properties live with the schema
class User extends Schema.Class<User>('User')({
  id: UserId,
  email: Schema.String,
  roles: Schema.Array(Schema.String),
}) {
  get isAdmin() {
    return this.roles.includes('admin')
  }

  hasPermission(p: Permission) {
    return checkPermission(this.roles, p)
  }
}

const user: User = yield* Schema.decodeUnknown(User)(raw)
user.isAdmin       // ✅
user.hasPermission('write:user')  // ✅
```

```ts
// DON'T — schema and methods drift apart
const UserSchema = Schema.Struct({ id: UserId, email: Schema.String, roles: Schema.Array(Schema.String) })
type User = Schema.Schema.Type<typeof UserSchema>
function isAdmin(u: User) { return u.roles.includes('admin') }
```

## Recursive schemas: declare interface, suspend the recursion

```ts
// DO
interface Tree {
  readonly name: string
  readonly children: ReadonlyArray<Tree>
}

const Tree: Schema.Schema<Tree> = Schema.Struct({
  name: Schema.String,
  children: Schema.Array(Schema.suspend(() => Tree)),
})
```

```ts
// DON'T — direct self-reference, TS inference fails
const Tree = Schema.Struct({
  name: Schema.String,
  children: Schema.Array(Tree),  // ❌ used before declared
})
```

## `Schema.Struct` vs `Schema.Class` quick rule

| Use | When |
|---|---|
| `Schema.Struct({...})` | Plain data, no behavior, just shape |
| `Schema.Class('Name')({...})` | Entity with methods, computed props, or `_tag` discrimination |
| `Schema.TaggedError('Tag')<...>` | Serializable error (RPC/HTTP boundary) |
| `Data.TaggedError('Tag')<...>` | Internal domain error (no serialization) |

## Encoding/decoding direction

- `Schema.decodeUnknown(S)(input)` — `unknown → A`, parsing data INTO your domain
- `Schema.encode(S)(value)` — `A → I`, serializing your domain OUT
- `Schema.decode(S)(input)` — typed input variant (when you already know `I`)

Use `decodeUnknown` at every untrusted boundary; `encode` when serializing back out (HTTP response, queue payload, file write).
