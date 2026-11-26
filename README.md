# Perch

A Mac app that turns photos of your real pet into a small animated version of it
that lives on your desktop, walks along the Dock, sits on top of your windows,
and reacts when you move them.

**This delivery is an experimental, native-first template-rig MVP, not a
validated self-serve AI service or a notarized public launch.** The shared rig
is the consistency baseline (approach A). [Design direction](DESIGN.md).

[Companion site](https://perchpet.vercel.app) |
[Experimental Mac release](https://github.com/brandon-lai/perch/releases/tag/v0.1.0)

The newer **local native build (0.2.0)** draws the pet as 32 × 32 pixel art,
adds a desktop rug, bed and clickable food bowl, and adds a **red panda** that
climbs anywhere on a window: across its face, up and down its sides, and over
the top. It sticks to windows and to your pointer, which it stalks, grabs and
rides along on until you shake it off. Its moves (an amble, head-first
descent, face-washing, apple snacks, sleeping draped over an edge) follow red
panda research. Your pet returns home for a meal and a nap, and can pull itself
up onto a window without moving it. See
[Desktop home](native/README.md#desktop-home-local-020-build) and
[Sticky paws and cursor play](native/README.md#sticky-paws-and-cursor-play).

## Structure

- `native/`: Swift, AppKit, SwiftUI and SpriteKit desktop companion.
- `site/`: Next.js companion site and browser-local pet-pack builder.
- `docs/`: acceptance evidence and pack contract.

## Decisions

| PRD open question | Shipped decision and reason |
| --- | --- |
| Art style | 32 × 32 pixel art in the Mac app (from 0.2.0). Hand-placed sprites recolored from the pet's traits keep its coat, ears and markings identical in every pose, need no image generation, and stay crisp at whole-pixel sizes. No claim of exact AI likeness. The website builder still previews the earlier flat drawing. |
| Pricing | Free experimental build. Eventual one-time custom-pet pricing, not a subscription, should follow measured costs and recognition tests. No made-up price or payment collection. |
| Distribution | Direct GitHub release first. App Store is deferred until sandbox/window-reading behavior is proven. |
| Acting on windows | Read-only by default. From 0.2.0 an opt-in **Push windows** setting (requires macOS Accessibility) lets the pet shove a window that blocks its path about 40 points, only while you're idle and not pointing at it, never off screen and never resizing. This reverses the PRD's v1 non-goal at the owner's request. Bite marks are drawn in Perch's own overlay; the bitten window is never changed. |
| Pets that have passed away | Optional remembrance wording, with no death-related assumptions or notifications. Quiet company, not a separate monetized mode. |
| Name | Perch: the pet's place on the edge of a window is the defining mechanism. |

## Privacy and deliberate scope

Photos stay on the device. There is no account, upload server, database,
analytics, chat, email/calendar access, payment, or cloud generation in this
MVP. Color/trait confirmation creates a versioned procedural rig pack. This
privacy-first baseline replaces the PRD's queued backend until there is a
real reason and validated asset-generation provider to operate one.

No raw source photos are included in exported packs. Gift sharing is an
exported pack file, not a hosted gift link. Multiple pets, Windows/Linux,
keyboard-content monitoring and Accessibility observers are not
implemented; Accessibility is used only for the opt-in window push. Window titles and screen contents are never inspected or saved.
From 0.2.0 the pet mostly walks, hops down from windows, chases a ball that
rolls and falls between windows, and chews window edges. New-window sniffing
and audio are not implemented.

Mouse-move coordinates update sampled alpha hit-routing, with a timer
fallback. A red panda with **Play with the pointer** on also uses the pointer's
current position to chase it. Nothing is stored, and clicks pass through while
it hangs on. No keys, clicks or input history are monitored. This is not a macOS
per-pixel input region, and zero-delay click-through is not guaranteed.

## Run

```sh
cd native
swift test
swift run Perch
```

```sh
cd site
npm ci
npm run dev
```

Native packaging, release signing, and verification evidence are documented
in `native/README.md` and `docs/ACCEPTANCE.md`.

Notarization requires a **Developer ID Application** identity and an existing
notarytool keychain profile; an Apple Development identity is not sufficient:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: YOUR NAME (TEAMID)" \
NOTARY_PROFILE="perch-notary" bash native/scripts/notarize.sh
```

The script produces a separate notarized ZIP only after Apple's submission,
stapling and Gatekeeper checks succeed. The published v0.1.0 is ad-hoc signed.

## Release gates that cannot be manufactured

- Ten real pets for the A/B/C asset comparison and owner recognition survey.
- Two weeks of personal use and twenty unassisted outside beta testers.
- Seven-/thirty-day retention and target-hardware battery/CPU measurements.
- A suitable Apple Developer ID Application identity and notarization profile.
- An image-to-model/frame provider, budget, terms and credentials if B or C is
  pursued. No third-party terms are accepted on the owner's behalf.

Furever Dock's current site was read for context. Its downloadable app was not
installed or run on this shared machine; window-interaction parity is unverified.
