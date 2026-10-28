# A font family set in the dashboard

## What it is and how to trigger it

A Pro app's developer chooses the font family the board is set in, in the dashboard, beside the
tint. It reaches the app with the config the SDK already reads. No app update, and nothing in the
host app's code: the dashboard owns both the tint and the font, and the SDK no longer takes an
appearance from the host app.

One enum and one field:

- `FontFamily` is one of the four system font families, one value per SwiftUI `Font.Design`:
  `FONT_FAMILY_DEFAULT`, `FONT_FAMILY_ROUNDED`, `FONT_FAMILY_SERIF`, `FONT_FAMILY_MONOSPACED`.
  `FONT_FAMILY_UNSPECIFIED` means nothing was chosen.
- `AppConfig.font_family` (field 14) carries the choice, beside `tint` (field 13).

**No new plan surface.** A font family is part of `PLAN_SURFACE_APPEARANCE`, which Pro already
includes, the same as the tint.

## Expectations

| When it works | What the reader gets |
|---|---|
| A Pro app whose developer chose Rounded | `font_family` is `FONT_FAMILY_ROUNDED` |
| A Pro app whose developer chose nothing | `font_family` is `FONT_FAMILY_UNSPECIFIED`; the SDK draws the system's default family |
| A Free app | `font_family` is `FONT_FAMILY_UNSPECIFIED`, whatever was saved while it was on Pro |

| When it fails | What happens |
|---|---|
| A server on an older contract | Field 14 is never sent, so it reads as `FONT_FAMILY_UNSPECIFIED` |
| An SDK on an older contract | It skips field 14 |
| A value this build does not know | Read as `UNRECOGNIZED`; the SDK draws the system's default family |

## Flow chart

```
proto/differentrequests_domain.proto     enum FontFamily { UNSPECIFIED = 0; DEFAULT = 1; ROUNDED = 2; SERIF = 3; MONOSPACED = 4; }
proto/differentrequests_sdk.proto        message AppConfig { … Tint tint = 13; FontFamily font_family = 14; }
        │
Scripts/generate.sh ─► Sources/DifferentRequestsProtos/differentrequests_domain.pb.swift   DRFontFamily
                       Sources/DifferentRequestsProtos/differentrequests_sdk.pb.swift      DRAppConfig.fontFamily
                       Sources/DifferentRequestsProtos/Fields.differentrequests_sdk.generated.swift   "font_family"
        │
the server's GetConfig fills it from what the dashboard saved; the SDK sets the board's font design from it
```

## What was walked

- The contract regenerates and builds with the enum and the field.
- Not walked yet: the dashboard, the server and the SDK reading it. Each lands in its own repository.
