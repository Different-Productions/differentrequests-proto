# differentrequests-proto

The DifferentRequests contract, and the only place it lives.

`proto/*.proto` is the source of truth. `Sources/DifferentRequestsProtos` is generated
from it and hand-edited never.

## Three rules

Everything below follows from these, and every one of them was broken by the design
this replaced.

### No JSON

Protobuf binary is the only encoding on the wire. Every rpc is:

```
POST /differentrequests.v1.RequestsService/<Method>
Content-Type: application/proto
```

The request message is the body. The response message is the body. Errors are an
`ApiError` message in the body, encoded identically. The HTTP status is transport and
is not part of the contract.

There are no path parameters and no query strings — not as a style preference, but
because `GET /requests?sort=top&cursor=…` encodes `ListRequestsRequest` a second time,
in a second syntax, hand-parsed on arrival. One encoding means one definition of what
a request is.

The accepted cost: the API cannot be explored with curl, and no caller can be written
without the generated types. The audience is developers dropping in the SPM package,
for whom the SDK is the only intended client. `protoc --decode` reads a captured body.

### No shadow objects

The generated types **are** the types. A consumer does not wrap them, mirror them, or
map them onto a parallel set of its own.

Concretely, none of these may exist: an `openapi.yaml` describing the same shapes, a
hand-written `FeatureRequest` struct in the SDK that a generated one is copied into,
a separate entity layer in the server that the messages are mapped through, or a
`RequestStatus` written anywhere but `differentrequests_domain.proto`.

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
| `DifferentRequests-Server` | `DifferentRequestsProtos`, exact tag | serves `RequestsService`; renders the console from the same messages |
| `DifferentRequestsSDK` | `DifferentRequestsProtos`, exact tag | speaks `RequestsService`; exposes these types as its API |

The live TypeScript stack is deliberately **not** a consumer. It serves the previous
contract on `*.different.productions` for Backlog's shipped build, and it is switched
off rather than migrated. Generating this contract into it would produce a second
implementation of the thing replacing it.

## Adding to a consumer

```swift
.package(url: "https://github.com/Different-Productions/differentrequests-proto.git", exact: "0.1.0"),
```

Pin `exact:`. A range lets `swift package update` move the contract out from under a
consumer that was verified against a specific one.

The package identity is `differentrequests-proto`, so the product reference is
`.product(name: "DifferentRequestsProtos", package: "differentrequests-proto")`.

## Regenerating

```sh
./Scripts/generate.sh        # rewrites Sources/DifferentRequestsProtos/
```

Two generators run. `protoc-gen-swift` emits the message types. `endpoint-gen`
(`Tools/protoc-plugin`) emits `ServiceEndpoints.generated.swift` — one case per rpc,
carrying the path it is called at and the audience it declared — so that neither the
client nor the server ever hand-writes a path string. A path typed into a client is a
copy of the service definition that nothing checks; an rpc that forgets its audience is
a build failure rather than an open route.

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
