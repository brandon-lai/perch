# Perch

A little pixel **red panda** that lives on your Mac desktop:

- **Explores:** it crawls up window faces and sides, walks their top edges,
  gallops along the Dock and leaps between windows.
- **Chases:** it goes after the bamboo stalk on your pointer, rides the pointer
  and eats the bamboo.
- **Rests:** it naps draped over the branch of its own little tree, which you
  can put anywhere along the bottom of a display.

**This is an experimental native alpha, not a notarized public launch.** The
original PRD was a pet made from photos of your own dog or cat. At the owner's
direction Perch now goes all in on one fully realized animal: the red panda.
[Design direction](DESIGN.md).

[Companion site](https://perchpet.vercel.app) |
[Experimental Mac release](https://github.com/brandon-lai/perch/releases/tag/v0.1.0)
(the published v0.1.0 release is the earlier dog/cat build). See
[the native README](native/README.md) for the red panda, its tree and pointer
chasing.

## Structure

- `native/`: Swift, AppKit, SwiftUI and SpriteKit desktop companion.
- `site/`: Next.js companion site and browser-local pack maker.
- `docs/`: acceptance evidence and pack contract.

## Decisions

| PRD open question | Shipped decision and reason |
| --- | --- |
| Which animal | One red panda instead of photo-based dogs and cats. It can climb anywhere, which makes the desktop its playground. Its pixel art follows the owner's reference sprites and its moves follow red panda research. Older dog and cat packs open as a red panda. |
| Art style | 32 × 32 hand-placed pixel art, recolored from three editable colors (coat, legs and ears, face mask), drawn small (1–2 points per art pixel) and crisp. No image generation. |
| Pricing | Free experimental build. No made-up price or payment collection. |
| Distribution | Direct GitHub release first. App Store is deferred until sandbox/window-reading behavior is proven. |
| Acting on windows | Read-only by default. An opt-in **Push windows** setting (requires macOS Accessibility) lets the panda shove a window that blocks its path about 40 points, only while you're idle and not pointing at it, never off screen and never resizing. This reverses the PRD's v1 non-goal at the owner's request. Bite marks are drawn in Perch's own overlay; the bitten window is never changed. |
| Home | A draggable pixel tree replaces the rug, bed and food bowl. There is no hunger; the bamboo on your pointer is its treat. |
| Name | Perch: the red panda's place on the edge of a window, or a branch. |

## Privacy and deliberate scope

There is no account, upload server, database, analytics, chat, email/calendar
access, payment, or cloud generation. Packs are small JSON files of colors and
traits. Gift sharing is an exported pack file, not a hosted gift link.

These are not implemented: multiple pets, Windows/Linux, keyboard-content
monitoring, Accessibility observers and audio. Accessibility is used only for
the opt-in window push. Window titles and screen contents are never inspected
or saved.

Mouse-move coordinates update sampled alpha hit-routing, with a timer fallback.
With **Chase the pointer** on, the panda also uses the pointer's current
position to chase it. The bamboo is drawn by Perch beside the system arrow, not
as a replacement pointer. Nothing is stored, and clicks pass through while it
hangs on. No keys, clicks or input history are monitored. This is not a macOS
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
