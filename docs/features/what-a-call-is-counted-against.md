# What a call is counted against

## What it is

Every rpc declares which allowance one call to it spends, as `(route_allowance)`:

| Value | Meaning | Rpcs |
|---|---|---|
| `ALLOWANCE_UNCOUNTED` | Counted against nothing | Every `GET`: GetConfig, ListRequests, GetRequest, ListComments, ListNotifications, GetUnreadCount, GetRoadmap, ListChangelog |
| `ALLOWANCE_WRITE` | Counted against the person and their app | CreateRequest, Vote, ClearVote, Follow, Unfollow, CreateComment, MarkAllNotificationsRead, MarkNotificationRead, RegisterDevice, UnregisterDevice |
| `ALLOWANCE_SIGN_IN` | Counted against the calling address and the app, and the app's new people | CreateSession |

`protoc-gen-drendpoints` emits it as `DRRequestsServiceRPC.allowance`, beside `audience` and `planGate`.
What each allowance's numbers are is the server's configuration, not the contract's.

## Surfaces

| Surface | Ships this? |
|---|---|
| The contract (`differentrequests_options.proto`, `differentrequests_sdk.proto`) | **Yes** — the `Allowance` enum, the option, one declaration per rpc |
| The generator (`Tools/protoc-plugin`) | **Yes** — reads the option, refuses an rpc without one, emits `allowance` |
| The server | **Reads it** — which allowance a call spends (DifferentRequests-Server#235) |
| The SDK | **none** — it pins the version; nothing in it reads `allowance` |

## How to find it, trigger it, and what happens

Declared on each rpc in `proto/differentrequests_sdk.proto`:

```proto
rpc CreateSession(CreateSessionRequest) returns (CreateSessionResponse) {
  option (route_method) = HTTP_METHOD_POST;
  option (route_path) = "/sessions";
  option (route_audience) = AUDIENCE_APP_KEY;
  option (route_allowance) = ALLOWANCE_SIGN_IN;
}
```

`Scripts/generate.sh` regenerates `ServiceEndpoints.generated.swift`, and a server switches on
`rpc.allowance`.

## Expectations

### What works

| Given | When | Then |
|---|---|---|
| Every rpc declares an allowance | `Scripts/generate.sh` | `allowance` is emitted with one arm per rpc |
| A new rpc declaring `ALLOWANCE_WRITE` | generated | Its arm returns `.write`, and a server's exhaustive switch over the allowance already handles it |

### What is refused

| Given | When | What the generator prints |
|---|---|---|
| An rpc with no `(route_allowance)` | `Scripts/generate.sh` | `RequestsService.GetConfig has no complete route — needs (route_method), (route_path), (route_audience) and (route_allowance). Fatal rather than defaulted: …` |
| A new value added to `Allowance` | a server built against it | Its exhaustive switch over `allowance` fails to compile until the value is handled |

## Flow chart of the real code path

```
proto/differentrequests_options.proto      enum Allowance · extend MethodOptions { route_allowance = 51251 }
proto/differentrequests_sdk.proto          option (route_allowance) = … on every rpc
        │
Scripts/generate.sh
        ├─ protoc-gen-swift → ContractGeneration/differentrequests_options.pb.swift  (DRExtensions_route_allowance)
        └─ protoc-gen-drendpoints
             EndpointTablePlugin.generate
               ├─ EnumCaseNames(typing: DRExtensions_route_allowance)     ← finds DRAllowance through the option
               └─ EmittedService → EmittedMethod(method:…, allowances:)
                    ├─ no route_allowance ──► EndpointTableError.incompleteRoute  ► protoc fails
                    └─ allowanceCaseName
             EmittedService.rpcEnumSource
               └─ public var allowance: DRAllowance { switch self { case .createSession: return .signIn … } }
        │
Sources/DifferentRequestsProtos/ServiceEndpoints.generated.swift
```

## UI map

No screen. The only thing a person sees is a server that refuses a sign-in flood without refusing the
people voting (DifferentRequests-Server#235).

```
generate.sh output
┌─────────────────────────────────────────────────────────────┐
│ Generated to …/Sources/DifferentRequestsProtos               │ ← every rpc declares one
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ --drendpoints_out: RequestsService.GetConfig has no complete │ ← one rpc forgot
│ route — needs … and (route_allowance). Fatal rather than …   │
└─────────────────────────────────────────────────────────────┘
```

## Platform differences

None. The generated table is the same Swift for the server (Linux, macOS) and the SDK (iOS, macOS).

## What walks the chart

| Walk | Result |
|---|---|
| `Scripts/generate.sh` with every rpc declaring one | `allowance` emitted: 8 `.uncounted`, 10 `.write`, 1 `.signIn`; `swift build` completes |
| The same with GetConfig's `route_allowance` removed | `RequestsService.GetConfig has no complete route — needs (route_method), (route_path), (route_audience) and (route_allowance).` |
| CI `Regenerate and diff` | The committed output matches a fresh run |
