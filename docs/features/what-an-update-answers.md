# What an update answers

## What it is and how to trigger it

Each published What's New entry names the requests it answers, so the SDK lists them under the
update and a person taps through to the one they asked for (DifferentRequestsSDK-private#73).
Mockup agreed 2026-09-25: https://claude.ai/artifact/1SHTWeLUD5ApsBM388aZ1L (top row).

`ChangelogEntry.answers`, a list of `ChangelogAnswer { request_id, title, vote_count }`, beside the
`request_ids` the entry already carried. The server fills it on `ListChangelog`; the SDK draws it.

It names only what a reader of the app can see: a request kept private, or taken down since, is left
out of `answers` and stays in `request_ids`, which is what telling the people who asked reads.

## Expectations

| When it works | What the reader gets |
|---|---|
| An update answering two public requests | `answers` holds both, each with its title and its votes now |
| An update answering a request kept private | That request is absent from `answers`, present in `request_ids` |
| An update answering nothing | `answers` is empty |

| When it fails | What happens |
|---|---|
| A server on an older contract | `answers` is empty; the SDK draws the update with no list, as before |

## Flow chart

```
proto/differentrequests_domain.proto     message ChangelogEntry { … repeated ChangelogAnswer answers = 9; }
                                         message ChangelogAnswer { request_id, title, vote_count }
        │
Scripts/generate.sh ─► Sources/DifferentRequestsProtos/differentrequests_domain.pb.swift
        │
the server's ListChangelog fills it; the SDK's ChangelogView draws it
```

## What was walked

- The contract regenerates and builds with the new field. Walked end to end on development once the
  server fills it and the SDK draws it; recorded in the SDK's feature doc.
