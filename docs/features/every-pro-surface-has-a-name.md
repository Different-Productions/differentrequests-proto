# Every Pro surface has a name

## What it is

`PlanSurface` is the list of what a plan decides, and so the list of what Pro is. `AppConfig`
carries one flag per surface, each declaring `(gates)`, and the generated
`DRAppConfig.includes(_:)` answers for every one of them.

| Surface | Flag | What it is |
|---|---|---|
| `PLAN_SURFACE_ROADMAP` | `roadmap_enabled` | What is planned and being built |
| `PLAN_SURFACE_CHANGELOG` | `changelog_enabled` | Published release notes |
| `PLAN_SURFACE_COMMENTS` | `comments_enabled` | Comments between people — every plan, off only by the tenant's choice |
| `PLAN_SURFACE_PUSH` | `push_enabled` | The server sending push notifications |
| `PLAN_SURFACE_DEVELOPER_REPLIES` | `developer_replies_enabled` | The developer answering in a request's thread |
| `PLAN_SURFACE_FOLDING` | `folding_enabled` | Several requests folded into one |
| `PLAN_SURFACE_APPEARANCE` | `appearance_enabled` | The board in the host app's accent color and font |
| `PLAN_SURFACE_PLANNING` | `planning_enabled` | The developer filing a request of their own |
| `PLAN_SURFACE_TRAIT_RANKING` | `trait_ranking_enabled` | Ranking by a trait the people asking carry |
| `PLAN_SURFACE_BADGE_REMOVAL` | `badge_removed` | The board without "Powered by Different Requests" |

`show_badge` (field 5) is gone and reserved. A Free app's `badge_removed` is false, so the badge is
drawn; `show_badge` said the same thing the other way round, and was the one flag no surface named.

Which plan includes which surface is the server's entitlement, not the contract's.

## Surfaces

| Surface | Ships this? |
|---|---|
| The contract (`differentrequests_options.proto`, `differentrequests_sdk.proto`) | **Yes** — seven `PlanSurface` values, seven flags, field 5 reserved |
| The generator (`Tools/protoc-plugin`) | **none** — `protoc-gen-drfields` already emits `includes(_:)` from every field declaring `(gates)` |
| The server | **Reads it** — sets every flag from the plan, and asks `includes(_:)` before serving a surface (DifferentRequests-Server#251) |
| The SDK | **Reads it** — `badge_removed` for the badge, `appearance_enabled` for the host app's look (DifferentRequests-Server#251) |

## How to find it, trigger it, and what happens

Declared in `proto/differentrequests_options.proto` (`enum PlanSurface`) and
`proto/differentrequests_sdk.proto` (`message AppConfig`). `Scripts/generate.sh` regenerates
`Fields.differentrequests_sdk.generated.swift`, where `includes(_:)` gains one arm per flag.

A caller asks the one question for every surface:

```swift
DRAppConfig(entitling: app).includes(.folding)
```

## Expectations

### What works

| Given | When | Then |
|---|---|---|
| Every `PlanSurface` value has a flag declaring it | `Scripts/generate.sh` | `includes(_:)` has one arm per value and `swift build` completes |
| A config whose `folding_enabled` is true | `includes(.folding)` | `true` |
| A config for a Free app | `includes(.badgeRemoval)` | `false`, so the SDK draws the badge |
| `.unspecified` or an unrecognized value | `includes(_:)` | `false` — the reading an unknown plan gets |

### What is refused

| Given | When | What happens |
|---|---|---|
| A `PlanSurface` value no flag declares | `swift build` | `Fields.differentrequests_sdk.generated.swift:88:5: error: switch must be exhaustive` |
| A consumer still reading `showBadge` | it builds against this version | `value of type 'DRAppConfig' has no member 'showBadge'` |
| A new field named `show_badge` | `Scripts/generate.sh` | `Field name "show_badge" is reserved.` |
| A new field numbered 5 | `Scripts/generate.sh` | `Field "shown" uses reserved number 5.` |

## Flow chart of the real code path

```
proto/differentrequests_options.proto   enum PlanSurface { ROADMAP … BADGE_REMOVAL = 10 }
proto/differentrequests_sdk.proto       message AppConfig { bool folding_enabled = 8 [(gates) = PLAN_SURFACE_FOLDING] … }
        │
Scripts/generate.sh
        ├─ protoc-gen-swift   → differentrequests_options.pb.swift  (DRPlanSurface, allCases)
        │                     → differentrequests_sdk.pb.swift      (DRAppConfig.foldingEnabled …)
        └─ protoc-gen-drfields
             FieldTablePlugin → EmittedFieldTable(message: AppConfig)
               └─ EmittedGates(message:namer:)
                    for each field with (gates) → EmittedGate(surfaceCaseName, propertyName)
                    swiftSource → public func includes(_ surface: DRPlanSurface) -> Bool
        │
Sources/DifferentRequestsProtos/Fields.differentrequests_sdk.generated.swift
        │
        ├─ server: DRAppConfig(entitling:) sets every flag · includes(_:) before each surface
        └─ SDK:    BadgeState(response:) · the appearance the board is drawn in
```

## UI map

No screen of its own. What a person sees is each surface there or not there, drawn by the server and
the SDK (DifferentRequests-Server#251).

```
generate.sh
┌──────────────────────────────────────────────────────────────┐
│ Generated to …/Sources/DifferentRequestsProtos                │ ← every surface has a flag
└──────────────────────────────────────────────────────────────┘
swift build, a surface with no flag
┌──────────────────────────────────────────────────────────────┐
│ error: switch must be exhaustive                              │ ← the list and the flags
│   add missing case: '.folding'                                │   disagree
└──────────────────────────────────────────────────────────────┘
```

## Platform differences

None. The generated Swift is the same for the server (Linux, macOS) and the SDK (iOS, macOS).

## What walks the chart

| Walk | Result |
|---|---|
| `Scripts/generate.sh` | `includes(_:)` emitted with ten arms plus `.unspecified, .UNRECOGNIZED`; `swift build` completes |
| `(gates)` taken off `folding_enabled`, regenerated | `swift build`: `error: switch must be exhaustive` |
| `bool show_badge = 13;` added, regenerated | `Field name "show_badge" is reserved.` |
| `bool shown = 5;` added, regenerated | `Field "shown" uses reserved number 5.` |
| CI `Regenerate and diff` | The committed output matches a fresh run |
| The server and the SDK built against this version | Walked on development under DifferentRequests-Server#251 |
