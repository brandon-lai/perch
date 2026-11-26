# Acceptance and evidence

> **Red panda pivot.** At the owner's direction the Mac app is now red panda
> only. It has a draggable tree instead of the rug, bed and bowl, and the
> photo-to-own-pet goal below is retired for the app. The photo and recognition
> criteria record the original PRD and the v0.1.0 evidence. The red panda's own
> checks are listed under **Native execution and release evidence**.

The source is `Desktop Pet PRD.pdf`, November 24, 2026. These are the PRD's
actual criteria, not substitutes for them. A deterministic rig preview is
not evidence of owner recognition; automated tests are not two weeks of use.

## Goals

> Someone recognizes their own pet on screen within 10 minutes of uploading photos.

**Not yet validated.** The native local template and browser trait editor
are the baseline. Exact likeness needs real photos and owner evaluation.

> The pet treats windows, the Dock and the menu bar as physical surfaces it can walk on, sit on and fall off.

Native geometry/physics verification is recorded below after the app check.
The browser playground is not evidence of macOS window interaction.

> The pet stays charming for weeks without becoming annoying: low CPU, never blocks clicks, easy to tuck away.

Sampled alpha routing and bed controls are verified in owned fixtures. This
is not a per-pixel OS input region; “never blocks clicks” and zero routing
latency are not established. Weeks of charm and battery cost require
longitudinal testing.

## Phase gates, verbatim

| Phase | “Done when” | Evidence / boundary |
| --- | --- | --- |
| 0. Spikes | “Placeholder pet rides a dragged window smoothly; one approach picked” | Approach A selected as the consistency baseline. A/B/C comparison on ten real pets is not available. |
| 1. Personal MVP | “You keep it running for 2 weeks and still like it” | Not completed by an implementation session. |
| 2. Self-serve beta | “20 outside testers make a pet with no help” | Not completed. No testers or success rates invented. |
| 3. Launch | “Public launch” | Source and an experimental release are not a notarized public launch. |

## Success metrics, verbatim

| Metric | Target | Status |
| --- | --- | --- |
| Photo upload to pet on desktop | Under 10 minutes | Local trait-to-pack flow is testable; owner-recognition target unvalidated. |
| Users who say “that's my pet” at the preview (one-tap survey) | 70% or more | No participants; no reported rate. |
| Pet still running 7 days after install | 50% or more | Not measured. |
| Pet still running 30 days after install | 30% or more | Not measured. |
| Pets sent to bed or muted per day, per user | Trending down over the first week | No telemetry collected. |
| Idle CPU on an M-series Mac | Under 2% | No target-hardware long-running benchmark claimed. |
| Generation cost per pet | Below the price charged for one pet | No paid generation or charged price in the experiment. |

The PRD additionally budgets **under 150 MB memory**, a **30 fps moving cap**,
and **near 0 fps sleeping**. Implementation caps do not alone prove CPU/RSS.

## Automated web evidence

- All nineteen actions appear in a versioned, native-compatible rig manifest.
- Name/color/enum validation and 3–10 photo, format and size boundaries.
- Real browser file decode, trait confirmation, and downloaded-pack inspection.
- Real pointer slow ride / fast tumble / click, keyboard movement and Escape.
- Click-only movement menu, independent pet pickup, and stationary floor
  landing in both full and compact previews.
- Field errors exposed through accessible descriptions; stable live regions.
- Pause/nap/wake and modal Escape/focus restoration.
- Real viewport widths 1440, 1024, 768, 390 and 320 without page overflow.
- All first fifteen Tab stops have names and visible focus.
- Body, muted and primary contrast measured in the rendered browser.
- No remote photo upload, fake generation, account, checkout, or admin route.

## Scope boundaries

No chat, reminders, email/calendar, Windows/Linux, multiple pets or
multiplayer. These are v1 non-goals. Moving other applications' windows was
also a non-goal; at the owner's request 0.2.0 adds it as an opt-in,
Accessibility-gated push (see `native/README.md`), still never resizing and
never modifying window contents.

Unimplemented launch features are explicit: hosted gift links, queued cloud
generation, provider-backed likeness, a one-tap recognition survey, payment,
optional AX observers, and typing-triggered nudges. A gift pack file and local
photo processing are useful baselines, not claims that those features exist.
From 0.2.0 the pet chases a physical ball and chews window edges (overlay
marks only). A red panda option climbs window faces and sides, holds on through
brisk drags, catches windows as it falls, and plays with the pointer: it stalks
the bamboo on the pointer (drawn beside it in 0.2.0; from 0.3.0 the arrow
itself), grabs it and eats it while riding along
until shaken off. While it hangs, clicks pass through. It uses
only the pointer's current position, and the pointer is never moved. New-window
sniffing and audio are not implemented.

## Native execution and release evidence

Executed on macOS 26.3, with actual owned AppKit windows and the real overlay,
not another user's desktop:

- Nineteen passing Swift tests cover pack validation, physics, occlusion,
  display geometry, quiet hours and behavior.
- Six slow owned-window moves applied six overlay ride frames, traversed
  84 points and measured zero paw error. Fast, minimized and vanished support
  caused a fall; floor landing passed.
- Three alpha checks passed; owned-overlay accepting/passing pixels, bed
  hiding/pausing and global bed shortcut registration were exercised.
- Ten additional pointer-routing/lifecycle fixture checks passed. Mouse-move
  callbacks update sleeping routing without engine/timer ticks and clean up
  on sleep/termination. They do not inspect or persist event payloads, keys,
  clicks or coordinate history. These are synthetic callback checks, **not**
  measured global OS event delivery latency.
- The tree passed nine owned-overlay checks (`--verify-tree`):
  - painted pixels take clicks and clicks beside it pass through;
  - dragging moves it;
  - the panda crawls up the trunk and naps draped over the branch;
  - it comes down head first;
  - **Go to its tree** sends it back up;
  - tucking it away hides the tree.
- Red panda cursor play passed 13 owned-window checks with a synthetic pointer
  (`--verify-cursor`). It stalks, swipes and grabs the bamboo on the pointer. The
  real bamboo view sits on the tip and takes no clicks. Its teeth land on the
  stalk's end within 1.5 pt, and it eats the stalk from the bottom up. The overlay stays click-through while it hangs over the
  pointer. It swings while riding and drops on a shake. It catches a window
  face mid-fall and drapes over the edge to sleep. Hanging from the **real**
  pointer was not exercised by automation.
- Red panda climbing passed ten owned-window checks (`--verify-climb`). On the
  face its pose follows its heading, upright and drawn about its torso, and the
  stride frame on screen is the engine's, picked from how far it has climbed.
  On a side it is upright and side on, facing the window, with its paws on the
  edge and its body outside it, checked through the rendered alpha. It rides
  its window when the window moves. From 0.3.0 the climbing poses are 48 × 48
  articulated frames drawn after the owner's photos of red pandas on trunks and
  branches.
- The bamboo pointer passed ten checks against WindowServer's **real** arrow
  (`--verify-pointer`), changing it for a few seconds and capturing nothing on
  screen:
  - the arrow becomes the stalk, tip as the hotspot, at four scales;
  - the pointer on screen is the stalk, then the arrow again;
  - an eaten stalk is shorter;
  - putting it away restores the arrow exactly;
  - a crashed Perch's stalk is recovered at launch;
  - the guard restores the arrow after a `SIGKILL`.

  The registry is private and unsupported: a future macOS may block it, in
  which case Perch draws the stalk beside the arrow. Every app's arrow being
  replaced was not exercised by automation.
- Red panda own-view contact sheets (two color sets) show twelve poses, with nineteen
  declared actions; v0.1.0 showed dog and cat sheets. From 0.2.0 these are 32 × 32 pixel sprites; v0.1.0 used
  173 pregenerated flat textures. Real SpriteKit and settings
  captures were inspected. No source photos or existing windows were captured.
- The browser-compatible fixture imported and round-tripped.
- The universal release contains arm64 and x86_64, has an ad-hoc signature,
  and includes a SHA-256 file. It is not Developer-ID signed or notarized.

Evidence is generated by the commands in `native/README.md` into the ignored
`native/dist/` directory, including `fixture-evidence.json`,
`pointer-routing-evidence.json`, `render-evidence.json` and `pack-evidence.json`.

**Not verified:** VoiceOver walks; real lock/unlock, Spaces/full-screen and
physical hotplug across host applications; real global hotkey delivery;
Intel/macOS 14 launch; pointer-event OS delivery latency; long-running CPU,
RSS and battery targets; real-pet recognition and every longitudinal/tester
gate above. Sleeping timer fallback is 250 ms if mouse monitoring is not
delivered. Bed is the reliable way to remove the overlay.

## Production evidence

Source is public at [brandon-lai/perch](https://github.com/brandon-lai/perch).
Vercel's `perchpet` project is connected to GitHub `main`, with `site` as its
root directory. Production is built from pushes, never a CLI working tree.

The final design review found the product deliberate, with the direction and
window-sill signature honored. Its verdict was **FIX** for compounded pet/perch
movement clipping on narrow screens. That finding was corrected after the
review: drag/menu movement share rendered-space constraints, resize recenters
the sample, and compact layouts accommodate the large cat rig. Thirteen real
browser workflows pass, including the exact repeated combined-movement
reproduction at 390 and 320 pixels, large-cat vertical extrema and resize.
No third review or independent post-fix **SHIP** verdict is claimed.

The [experimental v0.1.0 release](https://github.com/brandon-lai/perch/releases/tag/v0.1.0)
is public, including the universal ZIP, portable checksum, owned native captures
and fixture JSON. Its ZIP downloads anonymously with HTTP 200; downloaded
bytes passed SHA-256 and archive CRC checks.

[Production](https://perchpet.vercel.app) was exercised at app-code revision
`773882c131cf1b85b3746b126aa8ae73f015aa85`. Vercel reported `READY`,
`target: production`, `gitSource.type: github` and that exact source SHA,
with `perchpet.vercel.app` assigned. Evidence-only documentation revisions
redeploy the same application code; deployment SHA is rechecked against HEAD.

All thirteen browser workflows also passed against production. Sixteen live
captures were inspected, including repeated combined moves, the largest cat,
menus, errors, confirmation, sleep, and the social card, with no page errors.
Home, make, download, help, privacy and all three icon/social endpoints return
200. The unknown page and nonexistent generation, checkout and admin POST
endpoints return 404, never pretend success.

These results establish the delivered experimental baseline, not the
unvalidated PRD launch gates above.
