# differentrequests-proto

The DifferentRequests contract, and the only place it lives.

`proto/*.proto` is the source of truth. `Sources/DifferentRequestsProtos` is generated
from it and hand-edited never.

## Three rules

Everything below follows from these, and every one of them was broken by the design
this replaced.

### No JSON

Protobuf is the only payload encoding, in both directions, on every route. Ordinary HTTP
endpoints carry it:

```
GET  /requests?sort=top&cursor=…     Accept: application/x-protobuf
POST /requests                       Content-Type: application/x-protobuf
```

Every response body is a serialized message, a failure included — a failure is an
`DRApiError`, encoded exactly as a success would be. The HTTP status says only whether
the body is the answer or the error; *which* error is `DRApiError.code`, because a status
cannot distinguish "upgrade to Pro" from "not your request".

Proto is the payload, not the addressing. A path segment names a thing and a query
parameter scopes a read; both make a response cacheable and a request legible in a log.
`BacklogServer` and `backlog-admin-cms` speak exactly this, down to the content type.

What that leaves is the risk of a query key or an enum spelling being typed twice — once
in the client, once in the server. Neither is: `protoc-gen-drfields` emits each message's
field names and `protoc-gen-drtokens` emits each value's URL spelling, so both sides read
one declaration.

### No shadow objects

The generated types **are** the types. A consumer does not wrap them, mirror them, or
map them onto a parallel set of its own.

Concretely, none of these may exist: an `openapi.yaml` describing the same shapes, a
hand-written `DRFeatureRequest` struct in the SDK that a generated one is copied into,
a separate entity layer in the server that the messages are mapped through, a
`DRRequestStatus` written anywhere but `differentrequests_domain.proto`, or a path,
query key, or enum spelling typed into a consumer.

Storage is the one thing this package does not describe. Keys, indexes, and item
layout answer to access patterns, not to the wire, and the storage model is free to
look nothing like these messages — but it holds *these* messages, not restatements of
them.

### No copies

Consumers depend on this package by exact version tag. Nothing generated here is ever
committed into a consumer.

A vendored contract does not sometimes drift — it drifts silently. `backlog-admin-cms`
hand-copied `moderation.proto` from its server; the server's action enum gained a case,
the copy stopped at the previous one, hiding a comment became a one-way door, and
nothing failed loudly. That is the failure this package exists to prevent, and a copy
one directory over reintroduces it.

## Why this repository is public

The consumers are `DifferentRequests-Server` (private) and `DifferentRequestsSDK`
(public). A public Swift package cannot resolve a private dependency — an external
developer's `swift build` would fail on authentication — so under *no copies* the
contract has to be readable by anyone who can read the SDK.

That costs nothing. The contract describes messages a third-party app already sends
and receives; anyone holding the SDK has it. What stays private is
`DifferentRequests-Server`: the implementation, the storage model, the triage console,
and the platform-admin surface. None of it is here.

Console and platform-admin surfaces are server-rendered HTML and have no rpcs, which
is why `Audience` has no value for them. When something internal does need a wire
contract — a billing webhook, a worker — it gets its own private package rather than a
file in this one that a generator has to be trusted not to read.

## Consumers

| Consumer | Depends on | Uses |
| --- | --- | --- |
| `DifferentRequests-Server` | `DifferentRequestsProtos`, exact tag | serves `RequestsService`, routing from the generated table |
| `DifferentRequestsSDK` | `DifferentRequestsProtos`, exact tag | speaks `RequestsService`; exposes these types as its API |

The live TypeScript stack is deliberately **not** a consumer. It serves the previous
contract on `*.different.productions` for Backlog's shipped build, and it is switched
off rather than migrated. Generating this contract into it would produce a second
implementation of the thing replacing it.

## Adding to a consumer

```swift
.package(url: "https://github.com/Different-Productions/differentrequests-proto.git", exact: "0.8.0"),
```

Pin `exact:`. A range lets `swift package update` move the contract out from under a
consumer that was verified against a specific one.

The package identity is `differentrequests-proto`, so the product reference is
`.product(name: "DifferentRequestsProtos", package: "differentrequests-proto")`.

## Regenerating

```sh
./Scripts/generate.sh        # rewrites Sources/DifferentRequestsProtos/
```

Six generators run, all of them in `Tools/protoc-plugin`, and each emits something
`protoc-gen-swift` does not.

- `protoc-gen-swift` — the message types.
- `protoc-gen-drendpoints` — the endpoint table. One CaseIterable enum a server builds its
  router from, carrying each rpc's verb, path template, and audience; and one enum whose
  cases carry the path parameters, so a client cannot construct a call without the ids its
  path needs. An rpc declaring no audience is a build failure rather than an open route.
- `protoc-gen-drtokens` — how an enum value is spelled in a URL, and an initializer that
  reads one back. A value with no declared spelling cannot be sent.
- `protoc-gen-drfields` — each message's field names as the schema spells them, so a query
  key is referenced rather than typed.
- `protoc-gen-drvocab` — values whose contract *is* their spelling: an HTTP header, an
  authorization scheme, a media type. protoc emits Int-backed enums, so the string a value
  carries when it leaves Swift has nowhere else to live.
- `protoc-gen-drprices` — what each step of the price costs per month, in cents. Its own
  generator rather than a third property on tokens-gen, because what a value is *called* and
  what it *costs* change for different reasons: the server that charges, the console that
  quotes and the page that advertises are three copies of one number the moment it is typed
  anywhere but the schema, and the copy that drifts is found by a customer on their card.
  The total is not emitted — summing a taper is behaviour, and belongs to whoever owns the bill.

Every one of them is a protoc plugin, the shape `protoc-gen-swift` itself is: protoc parses
the schema once and hands each of them descriptors. None opens a `.proto` file. A generator
that read the text would be a second implementation of a grammar protoc already implements,
and wrong wherever the two disagree — a brace opened by a `oneof` closing a message, a `//`
inside a string literal starting a comment, a declaration split across lines never seen at
all.

That is also why the route metadata is three scalar options rather than one `Route` message.
A message-typed option can only be read by decoding it, and decoding needs the generated
Swift for the file that declares it — which would make the generator depend on its own
output. Scalars are read as the numbers they are, and their names resolved through the
descriptor.

Types carry a `DR` prefix. The domain's nouns are the most generic words available — App,
Comment, Plan — and `Notification` shadows Foundation's outright, so a consumer would
otherwise have to rename its own types to accommodate the contract. `igdb.proto` keeps its
package prefix for the same reason, arriving as `Proto_Game`.

Requires `protoc` (`brew install protobuf`). `protoc-gen-swift` is **not** taken from
`PATH` — it is built from the swift-protobuf version pinned in
`Tools/protoc-plugin/Package.swift`, so the committed output does not depend on what a
given machine happened to install. Pinned to the same version `backlog-proto` pins, so
both contract packages in this org emit identically formatted Swift.

CI regenerates and fails if the working tree moves. Both halves of the toolchain are
pinned for that reason: `protoc-gen-swift` by the tools manifest, `protoc` by
`.github/workflows/regenerate-and-diff.yml`.

The library's own swift-protobuf requirement is a range, because that is the *runtime* a
consumer links and consumers resolve their own. Reproducibility of the generated source
comes from pinning the generator, not the runtime.

## Compatibility

Field numbers are the contract under a binary encoding. A number is never reused and
never renumbered; a removed field becomes `reserved`. Adding a field is safe in both
directions — an older client ignores what it does not know, which is what makes a
pinned SDK survive a server that has moved on.
