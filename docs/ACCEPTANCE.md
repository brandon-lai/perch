# Acceptance and evidence

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

No chat, reminders, email/calendar, Windows/Linux, multiple pets, multiplayer,
or mutation of other applications' windows. These are v1 non-goals.

Unimplemented launch features are explicit: hosted gift links, queued cloud
generation, provider-backed likeness, a one-tap recognition survey, payment,
optional AX observers, and typing-triggered nudges. A gift pack file and local
photo processing are useful baselines, not claims that those features exist.
Toy actions are poses/animations, not autonomous ball chasing or new-window
sniffing. Audio is not implemented.

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
- Both dog and cat own-view contact sheets show twelve poses, with nineteen
  declared actions and 173 pregenerated textures. Real SpriteKit and settings
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

Release publication and live route verification are recorded below afterward.
