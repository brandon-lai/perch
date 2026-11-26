# Perch

A Mac app that turns photos of your real pet into a small animated version of it
that lives on your desktop, walks along the Dock, sits on top of your windows,
and reacts when you move them.

**This delivery is an experimental, native-first template-rig MVP, not a
validated self-serve AI service or a notarized public launch.** The shared rig
is the consistency baseline (approach A). [Design direction](DESIGN.md).

[Companion site](https://perchpet.vercel.app) |
[Experimental Mac release](https://github.com/brandon-lai/perch/releases/tag/v0.1.0)

## Structure

- `native/`: Swift, AppKit, SwiftUI and SpriteKit desktop companion.
- `site/`: Next.js companion site and browser-local pet-pack builder.
- `docs/`: acceptance evidence and pack contract.

## Decisions

| PRD open question | Shipped decision and reason |
| --- | --- |
| Art style | Soft flat 2D. One shared rig preserves coat and markings across poses; no claim of exact AI likeness. |
| Pricing | Free experimental build. Eventual one-time custom-pet pricing, not a subscription, should follow measured costs and recognition tests. No made-up price or payment collection. |
| Distribution | Direct GitHub release first. App Store is deferred until sandbox/window-reading behavior is proven. |
| Acting on windows | Strictly read-only. The pet never moves or resizes another app's window. |
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
keyboard-content monitoring and optional Accessibility observers are not
implemented. Window titles and screen contents are never inspected or saved.
Toy actions are animations; autonomous ball chasing, new-window sniffing and
audio are not implemented.

Mouse-move coordinates update sampled alpha hit-routing, with a timer
fallback. No keys, clicks or input history are monitored. This is not a macOS
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
