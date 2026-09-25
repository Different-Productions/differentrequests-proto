# What a call is called

## What it is

Every rpc declares, as `(route_label)`, what one call to it does in words a person reads:
"Loaded the board", "Voted", "Signed a person in". A list of calls is drawn in two consoles — a
developer's Calls page and the platform console's Recent calls — and a list of rpc names
(`ListRequests`, `GetUnreadCount`) is a list only the people who wrote the contract can read.

`protoc-gen-drendpoints` emits it as `DRRequestsServiceRPC.label`, beside `audience` and
`allowance`. It is prose rather than an identifier: emitted as a string, never read back into a
case.

| Rpc | Label |
|---|---|
| GetConfig | Read its settings |
| CreateSession | Signed a person in |
| ListRequests | Loaded the board |
| CreateRequest | Asked for something |
| GetRequest | Opened a request |
| Vote | Voted |
| ClearVote | Took a vote back |
| Follow | Followed a request |
| Unfollow | Stopped following a request |
| ListComments | Loaded comments |
| CreateComment | Commented |
| ListNotifications | Loaded notifications |
| GetUnreadCount | Checked for new notifications |
| MarkAllNotificationsRead | Marked every notification read |
| MarkNotificationRead | Marked a notification read |
| RegisterDevice | Turned on notifications for a phone |
| UnregisterDevice | Turned off notifications for a phone |
| GetRoadmap | Loaded the roadmap |
| ListChangelog | Loaded what's new |

Past tense, because every place that draws one lists a call that already happened.

## Surfaces

| Surface | Ships this? |
|---|---|
| The contract (`differentrequests_options.proto`, `differentrequests_sdk.proto`) | **Yes** — the option, one declaration per rpc |
| The generator (`Tools/protoc-plugin`) | **Yes** — reads the option, refuses an rpc without one or with an empty one, emits `label` |
| The server | **Reads it** — the Calls page and the platform console's Recent calls draw it before the rpc name (DifferentRequests-Server#307) |
| The SDK | **none** — it pins the version; nothing in it reads `label` |

## How to find it, trigger it, and what happens

Declared on each rpc in `proto/differentrequests_sdk.proto`:

```proto
rpc ListRequests(ListRequestsRequest) returns (ListRequestsResponse) {
  option (route_method) = HTTP_METHOD_GET;
  option (route_path) = "/requests";
  option (route_audience) = AUDIENCE_APP_KEY;
  option (route_allowance) = ALLOWANCE_UNCOUNTED;
  option (route_label) = "Loaded the board";
}
```

`Scripts/generate.sh` regenerates `ServiceEndpoints.generated.swift`, and a page draws `rpc.label`.

## Expectations

### What works

| Given | When | Then |
|---|---|---|
| Every rpc declares a label | `Scripts/generate.sh` | `label` is emitted with one arm per rpc, each a string literal |
| A label holding `"` or `\` | generated | Escaped in the literal, so the generated file still compiles |

### What is refused

| Given | When | What the generator prints |
|---|---|---|
| An rpc with no `(route_label)`, or an empty one | `Scripts/generate.sh` | `RequestsService.GetConfig has no complete route — needs (route_method), (route_path), (route_audience), (route_allowance) and a non-empty (route_label). Fatal rather than defaulted: …` |

Walked 2026-09-25: GetConfig's label removed, `Scripts/generate.sh` printed exactly that and wrote
nothing; restored, the tree regenerated to the committed output.

## Flow chart of the real code path

```
proto/differentrequests_options.proto      extend MethodOptions { string route_label = 51252 }
proto/differentrequests_sdk.proto          option (route_label) = "…" on every rpc
        │
Scripts/generate.sh
        ├─ protoc-gen-swift → ContractGeneration/differentrequests_options.pb.swift (DRExtensions_route_label)
        └─ protoc-gen-drendpoints
             EndpointTablePlugin ── EmittedService ── EmittedMethod(method:…)
                                                        ├─ label missing or empty → EndpointTableError.incompleteRoute
                                                        └─ label → EmittedService: `public var label: String`
        │
Sources/DifferentRequestsProtos/ServiceEndpoints.generated.swift   DRRequestsServiceRPC.label
```
