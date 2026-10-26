# A tint set in the dashboard

## What it is and how to trigger it

A Pro app's developer chooses the SDK's tint color in the dashboard, one color for light mode and
one for dark mode, and it reaches the app with the config the SDK already reads
(DifferentRequests-Server#454). No app update.

Two messages and one field:

- `Color { red, green, blue }` is one color in sRGB, each component a whole number from 0 to 255.
- `Tint { light, dark }` is the pair: the color drawn in light mode and the color drawn in dark mode.
- `AppConfig.tint` (field 13) carries the pair. It is absent when the developer chose nothing, and
  absent on an app whose plan leaves `PLAN_SURFACE_APPEARANCE` out.

**A color is never text.** A hex code is how a person types a color into the dashboard. It is read
once there, and from then on the color is these three numbers: in the table, on the wire and in the
SDK.

**No new plan surface.** A tint is part of `PLAN_SURFACE_APPEARANCE`, which Pro already includes.
`appearance_enabled` is still the flag; `tint` is what the developer chose on top of it.

## Expectations

| When it works | What the reader gets |
|---|---|
| A Pro app whose developer saved a light and a dark color | `tint` is present, and `light` and `dark` are both present |
| A Pro app whose developer chose the app's own color | `tint` is absent; the SDK draws the color passed in code, or the system tint |
| A Free app | `tint` is absent, whatever was saved while it was on Pro |

| When it fails | What happens |
|---|---|
| A server on an older contract | `tint` is absent; the SDK draws the color passed in code |
| An SDK on an older contract | It skips field 13 and draws the color passed in code |
| A component over 255, or a `tint` holding one color of the two | Not a color the dashboard can write. The SDK reads it as no tint |

## Flow chart

```
proto/differentrequests_domain.proto     message Color { uint32 red = 1; uint32 green = 2; uint32 blue = 3; }
                                         message Tint  { Color light = 1; Color dark = 2; }
proto/differentrequests_sdk.proto        message AppConfig { … Tint tint = 13; }
        │
Scripts/generate.sh ─► Sources/DifferentRequestsProtos/differentrequests_domain.pb.swift   DRColor, DRTint
                       Sources/DifferentRequestsProtos/differentrequests_sdk.pb.swift      DRAppConfig.tint, hasTint
        │
the server's GetConfig fills it from what the dashboard saved; the SDK tints with it
```

## What was walked

- The contract regenerates and builds with the two messages and the field.
- Walked end to end on a local server and the SDK's example app, both built against this branch
  before it was tagged; recorded in the server's and the SDK's feature docs.
