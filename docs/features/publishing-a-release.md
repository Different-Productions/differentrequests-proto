# Publishing a release

## What it is

This repository, `differentrequests-proto-private`, is private. The package the server and the SDK
resolve is its **public copy**, `Different-Productions/differentrequests-proto`, and that copy only
ever receives releases.

Pushing a release tag here — `0.32.0` — publishes **one commit** to the public copy: the tag's files,
without `.github`, on top of the previous public release, tagged `0.32.0`. Work in progress, pull
requests and commit history stay private.

**A published tag never moves.** SwiftPM records the commit behind every tag it resolves and refuses a
tag that later points somewhere else, so the publisher refuses a version the public copy already has,
and the public copy's rulesets refuse tag updates and deletions from anyone.

The publisher is one action shared with the SDK:
`Different-Productions/DifferentRequestsSDK-private/.github/actions/publish-release-copy@master`. Its
full description lives beside it, in the SDK's `docs/features/publishing-a-release.md`.

## Surfaces

| Surface | Ships this? |
|---|---|
| This private repository | **Yes** — `.github/workflows/publish-release-copy.yml`; `.github/workflows/regenerate-and-diff.yml` moves to the organization's Mac |
| The public copy `differentrequests-proto` | **Yes** — receives release commits and tags; issues, wiki and projects are off; rulesets let only the release key create or change branches and tags |
| `DifferentRequestsSDK-private` | **Yes** — owns the shared action; its Actions access is set to the organization |
| `DifferentRequestsSDK` and `DifferentRequests-Server` | **None** — both keep `https://github.com/Different-Productions/differentrequests-proto.git`, `exact:`; every tag published before 2026-09-11 points at the same commit it always did |
| The generated Swift (`DifferentRequestsProtos`) | **None** |
| The console, the example app | **None** |

## How to find it, trigger it, and what happens

**Release.** Tag the commit and push the tag to this repository:

```sh
git tag -a 0.32.0 -m 0.32.0
git push origin 0.32.0
```

The tag push starts **Publish release copy** on the organization's Mac. It clones the public copy,
refuses if `0.32.0` is already there, replaces the tree with `git archive 0.32.0` minus `.github`,
commits `Release 0.32.0` as `github-actions[bot]`, tags it, and pushes the branch and the tag
atomically with the write key in `RELEASE_COPY_DEPLOY_KEY`. It then reads the tag back from the
public copy and fails unless it points at the commit it made.

The SDK's and the server's contract pin checks read tags from the **public copy**, so a new version
exists for them only once this run has finished.

**Rehearse.** Actions → Publish release copy → Run workflow, with a version and **publish**
unchecked. It builds the same commit and prints it; nothing is pushed.

## Expectations

**Positive**

| Given | When | Then |
|---|---|---|
| A new version tag `X.Y.Z` pushed here | the workflow runs | One commit `Release X.Y.Z` on the public copy's `master`, parented on the previous release, and tag `X.Y.Z` on it |
| The published tag | a consumer resolves `exact: "X.Y.Z"` | It resolves over HTTPS with no credentials |
| The published tag | the SDK's pin check runs | `X.Y.Z` is the latest published version it compares against |
| A rehearsal (`publish` unchecked) | the workflow runs | `Release X.Y.Z of differentrequests-proto: <commit> on top of <previous> (master)` and `Rehearsal: nothing was pushed.` |
| Any tag published before 2026-09-11 | resolved again | The same commit as before the repositories moved; no fingerprint error |
| The public copy after a release | its tree is read | Exactly the tag's tracked files minus `.github` |
| The first release after the move | published | It also deletes `.github/workflows/regenerate-and-diff.yml`, the last workflow file on the public copy |
| A pull request or push to `master` here | Regenerate and diff runs | It runs on `[self-hosted, macOS, ARM64]`, one run at a time, and passes when the committed Swift matches a fresh `Scripts/generate.sh` |

**Negative**

| Given | When | Then | What is shown |
|---|---|---|---|
| A version already on the public copy | publish or rehearse | Refused, nothing pushed | `X.Y.Z is already published on differentrequests-proto. A published tag never moves; release a new version instead.` |
| A version that is not three numbers | dispatch | Refused | `v1 is not a release version. Release tags are three numbers, like 0.9.0.` |
| A version with no tag here | dispatch | Refused | `There is no tag X.Y.Z in this repository.` |
| Publishing without the key | publish | Refused before anything is cloned | `Publishing needs the write key for the public copy in DEPLOY_KEY.` |
| The SDK repository's Actions access set back to none | the workflow runs | The run fails to download the action | GitHub's action download error; not walked |
| Anyone, an organization admin included, creating a branch on the public copy | `git push` | Refused by the ruleset **Only the release publisher writes branches**; nothing is created | `GH013: Repository rule violations found for refs/heads/<branch>.` then `Cannot create ref due to creations being restricted.` |
| Anyone, an organization admin included, creating a tag on the public copy | `git push` | Refused by the ruleset **Release tags are made once and never move**; nothing is created | `GH013: Repository rule violations found for refs/tags/<tag>.` then `Cannot create ref due to creations being restricted.` |
| Anyone updating `master`, or moving or deleting a public tag | `git push`, `git push --force`, `git push --delete` | Refused by the update, non-fast-forward and deletion rules of the same rulesets | Not walked: a rule that failed would move or delete a real release |
| Committed Swift behind `proto/` | Regenerate and diff runs | The check fails | `Sources/DifferentRequestsProtos is stale. Run ./Scripts/generate.sh and commit the result.` |

## The path

```
git push origin X.Y.Z                          (this private repository)
        │
        ▼
.github/workflows/publish-release-copy.yml      on: push tags [0-9]+.[0-9]+.[0-9]+
        │  runs-on [self-hosted, macOS, ARM64], concurrency contract-release-copy
        │  checkout, fetch-depth 0
        ▼
DifferentRequestsSDK-private/.github/actions/publish-release-copy/action.yml   @master
        │  public-copy differentrequests-proto
        ▼
publish-release-copy.sh
        │
        ├── VERSION, PUBLIC_COPY or PUBLISH empty ► error, exit 1
        ├── VERSION not N.N.N ───────────────► error, exit 1
        ├── no refs/tags/VERSION here ────────► error, exit 1
        ├── PUBLISH true, no DEPLOY_KEY ──────► error, exit 1
        │
        ▼
git clone https://github.com/Different-Productions/differentrequests-proto.git
        │
        ├── tag VERSION already there ────────► error, exit 1   (tags never move)
        │
        ▼
git rm -r .  →  git archive VERSION | tar -x  →  rm -rf .github  →  git add --all --force
        │
        ▼
commit "Release VERSION" (github-actions[bot])  →  tag -a VERSION
        │
        ├── PUBLISH != true ──────────────────► print, exit 0   (rehearsal)
        │
        ▼
ssh key from RELEASE_COPY_DEPLOY_KEY  →  git push --atomic master refs/tags/VERSION
        │                                        │
        │                              public copy rulesets:
        │                              branches and tags writable only by the deploy key
        ▼
git ls-remote refs/tags/VERSION^{}  ── not the new commit ──► error, exit 1
        │
        ▼
"Published VERSION to differentrequests-proto at <commit>."
        │
        ▼
DifferentRequestsSDK / DifferentRequests-Server Package.swift  exact: "VERSION"   (a later pin bump)
```

## The screen

There is no app screen. What a person sees is the Actions run and the public copy.

```
 Actions ▸ Publish release copy ▸ Run workflow            (manual rehearsal)
 ┌──────────────────────────────────────────────────────────┐
 │ Use workflow from   [ master ▾ ]                          │
 │ A release tag that exists in this repository.             │
 │ [ 0.32.0                                  ]  ← required   │
 │ [ ] Push to the public copy. Unchecked prints what…       │  ← unchecked = rehearsal
 │                                   ( Run workflow )        │
 └──────────────────────────────────────────────────────────┘

 Run log, rehearsal                  (real output; tag 9.9.9 existed only in a local rehearsal)
   Release 9.9.9 of differentrequests-proto: e6a17e67015c… on top of c7e3af0720ea… (master)
    1 file changed, 85 deletions(-)          ← the old .github/workflows/regenerate-and-diff.yml going away
   Rehearsal: nothing was pushed.

 Run log, refused                    (real output, read from GitHub)
   ::error::0.31.0 is already published on differentrequests-proto. A published tag never moves;
   release a new version instead.                                        ← run fails, red X

 github.com/Different-Productions/differentrequests-proto      (public copy)
 ┌──────────────────────────────────────────────────────────┐
 │ master · Release 0.32.0 · github-actions[bot]             │
 │ Tags: 0.32.0  0.31.0  …                                   │
 │ Issues: off   Wiki: off   Projects: off                   │
 └──────────────────────────────────────────────────────────┘
 In flight: the run is queued behind any other run in contract-release-copy (queue: max); a
 second tag waits rather than racing the first.
```

## Platform differences

**None.** Releases are source; SwiftPM resolves the same tag on every platform the package supports.

The one split is **where it runs**: this repository's workflows run on the organization's Mac, and the
public copy runs nothing — its tree carries no `.github` after the first release, and the
organization's runner group refuses public repositories. Regenerate and diff needs Apple Silicon
because the pinned `protoc` is the `osx-aarch_64` build.

## What walks this chart

There is no test target for the publisher.

Walked on 2026-09-11 when the repositories moved (Different-Productions/DifferentRequests-Server#190):

1. Before the move: `master` and all 31 tags recorded from the public repository.
2. After the move: the public copy read anonymously over HTTPS — `master` and all 31 tags at the same
   commits.
3. A new package on a machine with an empty home directory and no Git credentials resolved
   `DifferentRequestsSDK` `exact: "0.8.0"` → `differentrequests-proto` 0.23.0 from the public copy.
4. The server's own `swift package resolve`, with this Mac's existing SwiftPM fingerprints, succeeded
   and left `Package.resolved` unchanged.
5. `publish-release-copy.sh` run against a bare clone of the public copy and a clone of this
   repository carrying a local tag `9.9.9`, through `PUBLIC_REMOTE_OVERRIDE`:
   - rehearsal printed the release and pushed nothing;
   - publish pushed one commit on top of the public `master`, and `9.9.9` read back at that commit;
   - publishing `9.9.9` again, rehearsing `0.31.0` against GitHub, and publishing with no
     `DEPLOY_KEY` each exited 1 with the text in the table above;
   - the published tree matched `9.9.9` file for file, minus `.github`;
   - GitHub never received `9.9.9`.
6. Regenerate and diff ran on the organization's Mac for this pull request and passed in 1m19s.
7. **Run workflow** on `master` with `0.31.0` and *publish* unchecked ran on the organization's Mac.
   It downloaded the action from `DifferentRequestsSDK-private@master` and refused:
   `0.31.0 is already published on differentrequests-proto. A published tag never moves; release a new version instead.`
8. The owner's own credentials, as an organization admin, pushed the already-public `master` commit
   to a new branch and to a new tag on the public copy. GitHub refused both with the text in the
   table above, and neither ref existed afterwards.
9. Not walked yet: the first real release through the workflow with the deploy key. Updating `master`
   and moving or deleting a tag were not tried: a rule that failed would damage a real release.
