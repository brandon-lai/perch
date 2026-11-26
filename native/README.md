# Perch native alpha

Native Swift 6.2 package, macOS **14 or newer**. AppKit transparent overlays,
SpriteKit pixel-art pets and a SwiftUI trait/settings window; not a web
shell. No cloud, account, generation provider, uploads, audio, or telemetry.
The photo-assisted template does **not** promise an exact likeness.

## Run and verify

From `/Users/brandon/Documents/Dev/perch/native`:

```sh
swift test
swift run Perch
```

First launch offers stock Milo, editable traits and optional 3–10 local photos.
Vision suggests foreground coat/ear colors only; it does not infer species,
ears, body type or markings. Every trait can be corrected before **Save & wake**.
A failed mask/decode/model operation produces a visible error and leaves the
previous traits intact. Analysis holds photo data in memory, never writes the
originals and never includes them in a pack.

The menu-bar paw offers wake, bed, pet, fill food bowl, play ball, high five, hop to a
window, peek from the menu bar, move to the next display, settings and quit.
Click the opaque animal pixels to pet it; hover to look; drag to hold and release
to fall. Escape cancels a drag when the overlay has keyboard focus. Settings
and menu actions provide non-drag alternatives. **Control–Option–Command–B**
is registered as a Carbon hotkey, not a global keyboard event tap.

## Desktop home (local 0.2.0 build)

Look just above the Dock or bottom safe edge for the stitched rug, cushion and
blue bowl. Click the bowl or choose **Fill food bowl** from the paw menu.
Your pet comes home, eats and naps on the cushion before exploring again.
After 15 minutes of awake, active time it comes to wait by an empty bowl on its
own. There is no offline hunger, illness, countdown or notification.

In **Settings → Desktop home**, choose the display and bottom corner, then
**Save & wake**. An unplugged display falls back to the main display. Pets walk
to the edge to change displays on their way home; offset floors use an edge
transfer rather than animating through an invisible gap. The rug and cushion
do not accept clicks. Tucking the pet away also hides the home.

## Mischief (0.2.0)

The pet now walks most of the time, with short sniffs, sits and stretches in
between. It hops down from window edges, wanders across displays and,
unprompted every few minutes, does one of these:

- **Plays ball.** A ball rolls with friction, falls off edges, bounces off
  windows in front, and rides windows that move. The pet runs after it, jumps
  down (going around a window that's in the way), climbs up to it, and bats it
  three to five times. **Play ball** in the menu or Settings starts a game.
- **Chews a window edge.** It lies down on the window it's standing on and
  gnaws, leaving a nibble mark at that spot. Marks are Perch overlay drawings
  that follow their window, hide behind windows in front, never take clicks,
  and fade after 20 minutes (three per window, ten in all). **Chew window
  edges** in Settings is on by default; **Tidy up bite marks** clears them.
- **Pushes a window in its way** (opt-in). With **Push windows** on and Perch
  allowed in System Settings → Privacy & Security → Accessibility, bumping into
  a window in front asks to slide it about 40 points over 0.9 s. The app skips
  the push unless you've been idle 1.5 s and the pointer is outside that
  window, keeps it fully on screen and never touches Perch's own windows. The
  slide stops at once on any input, a held mouse button, the pointer entering
  the window, or the window being moved by anyone else, and every Accessibility
  call times out after 0.25 s so a hung app can't stall the pet. Without
  permission the pet just shoves in place.

Calm mode keeps the pet wandering, slower and with longer pauses, but with no
mischief, climbing or pushing; Reduce Motion keeps it still. The engine only emits requests
(`PetEvent.bite`, `.push`); the app decides whether to act on them.

Curious pets occasionally hook their front paws over a reachable window edge,
give two pulls and climb up. **Hop to a window** lets you try it on demand;
the window itself never moves. Calm mode suppresses autonomous climbing and
Reduce Motion skips the animated tug and home journey.

**Save & wake** explicitly persists the confirmed pack and settings:

```
~/Library/Application Support/Perch/pet.perchpack
~/Library/Application Support/Perch/preferences.json
~/Library/Application Support/Perch/care.json
```

Quiet hours, calm mode and remembrance are editable. The app naps after five
minutes of system inactivity; bedtime is hidden, while quiet/idle sleep remains
visible and pauses the SpriteKit scene. Reduced Motion freezes pose animation
and disables wandering. All interactions are silent. Delete saved pet removes
all three files and hides the animal; it does not erase the user's external exports.
Care stores only active-time appetite and whether the bowl is filled, never a
timestamp or activity history. It is saved at meals and on normal quit for a
saved pet and is not included in exported packs.

## Packs

Import/export uses the exact shared `../docs/PACK.md` JSON contract. Version,
rig, colors, finite anchors, timing, size, complete 19-action coverage and
duplicate/unknown actions are validated. The `.perchpack` is UTF-8 JSON, not a
ZIP or executable. Import stages traits for confirmation rather than saving
immediately. Double-clicking a pack opens the same review window in the app.
The registered `perch:` URL scheme does not download remote data.

`Tests/PerchCoreTests/Fixtures/browser.perchpack` reproduces the browser's
19-action manifest, including single-frame sleep. XCTest imports it, exports
it, checks exact top-level keys and round-trips it. Render verification exports
`dist/Milo.perchpack` and `dist/Juniper.perchpack` for browser verification.

## Window behavior

- One borderless transparent, shadowless overlay per display joins Spaces.
- Window metadata comes from `CGWindowListCopyWindowInfo`: bounds, numeric ID,
  layer, numeric PID and z-order. **No title/owner string is read or logged,
  and no screen-image API is used.** Accessibility is requested only when you
  turn on **Push windows**, and then only window position and size are read.
- Front windows subtract covered top-edge segments. If a foreground rectangle
  overlaps a supported pet, the whole animal is hidden conservatively; private
  content is never sampled. Walking stops with the nose at a window in front
  instead of vanishing behind it. Windows are never resized, and only moved by
  the opt-in push below.
- Safe visible-frame floors account for Dock/menu-bar space. Side Dock space is
  excluded. The menu-bar command uses a hanging/peeking pose.
- Slow moves ride; moves over 650 points/second detach. Gravity snaps to the
  highest crossed surface. Closed/minimized/occluded support falls. Display
  changes rebuild overlays; adjacent floors support cross-display walking.
- Polling is 10 Hz normally, 30 Hz while riding, 2 Hz while asleep. Motion is
  capped at 30 fps; sleep pauses rendering. Locked/inactive/sleeping sessions
  stop timers and hide windows. Full-screen-size front windows hide that display.
- Global and local **mouseMoved-only** monitors immediately sample
  `NSEvent.mouseLocation` and refresh alpha-based `ignoresMouseEvents` routing
  on the main thread. The global event payload is ignored; local events are
  returned unchanged. No key/button/scroll monitoring, event-content inspection,
  coordinate history, event persistence, camera or screen capture is added.
  Monitors are removed on session sleep/lock and termination, and restored on
  wake. A 33 ms moving / 250 ms sleeping timer remains a fallback for undelivered
  events or registration failure. Delivered movement no longer waits for that
  timer; this is not an OS-level per-pixel input region or an OS-latency guarantee.

## Build artifacts and owned-window captures

```sh
bash scripts/build-app.sh
bash scripts/verify.sh
```

`build-app.sh` builds **arm64 + x86_64**, copies an LSUIElement bundle,
ad-hoc signs it and produces:

```
dist/Perch.app
dist/Perch-0.2.0-universal.zip
dist/Perch-0.2.0-universal.zip.sha256
```

Individual graphical checks (run from `native/`, a logged-in GUI required):

```sh
dist/Perch.app/Contents/MacOS/Perch --capture-preview
dist/Perch.app/Contents/MacOS/Perch --capture-settings
dist/Perch.app/Contents/MacOS/Perch --verify-fixture
dist/Perch.app/Contents/MacOS/Perch --verify-home
dist/Perch.app/Contents/MacOS/Perch --verify-mischief
dist/Perch.app/Contents/MacOS/Perch --capture-sprites
dist/Perch.app/Contents/MacOS/Perch --verify-pack Tests/PerchCoreTests/Fixtures/browser.perchpack
```

Each command starts real NSApplication/NSWindow rendering and terminates itself.
`--output dist/alternate` optionally selects another directory inside native.
Preview/settings/fixture captures use `NSView.cacheDisplay` on **our own view**.
`native-spritekit.png` comes from `SKView.texture(from:)` on **our own scene**.
No desktop/window screenshot request is made and no other window content appears.
The fixture moves/minimizes/closes a window it owns, verifies actual CG bounds,
gravity and alpha routing, then writes sanitized counts. It neither logs other
window titles nor moves their windows or the shared cursor.

Evidence paths:

- `dist/native-preview.png`, `dist/native-cat-preview.png`: twelve actual poses
  each, from the same palette/marking rig used by the overlay.
- `dist/native-sprites.png`: all nineteen actions' distinct frames, plus the
  dine, chew, push and pounce poses, for five dog/cat, ear and marking combinations.
- `dist/native-mischief.png`, `dist/mischief-evidence.json`: two owned windows;
  the walk stops at the front window and requests a push, a chew leaves a nibble
  that follows its window, hides behind the front window and goes when its
  window closes, and the ball is drawn in the overlay. Records whether
  Accessibility was granted; it was not on the verification machine, so the
  actual window slide is **unverified**.
- `dist/native-settings.png`, `dist/native-settings-files.png`: native rendered
  traits and scrolled quiet-hours/remembrance/import/export/delete controls.
- `dist/native-fixture-ride.png`, `dist/native-fixture-fall.png`: owned-window
  checks; `dist/native-spritekit.png`: actual SpriteKit render.
- `dist/native-overlay-ride.png`: the actual SpriteKit overlay after six
  frame/bounds-driven rides, with only our fixture's outline/label added for
  alignment evidence. This is our scene texture, never a desktop screenshot.
- `dist/render-evidence.json`, `dist/fixture-evidence.json`: dimensions,
  sampled-color counts, actual ride/fall outcomes and privacy-safe diagnostics.
- `dist/pack-evidence.json`, `dist/imported-roundtrip.perchpack`: executable
  import/export verification of a browser-format fixture.
- `dist/native-home-meal.png`, `dist/native-home-nap.png`: owned artwork and
  rendered pet frames at the positions used by the desktop overlay.
- `dist/pointer-routing-evidence.json`: ten targeted awake/sleeping routing and
  lifecycle checks through the actual monitor callbacks with synthetic owned
  coordinates, including transparent sprite pixels, unchanged local events,
  paused sleep, no timer/engine/window-list tick, and cleanup. The fixture does
  not move the shared cursor or record private input.

## Pixel art

Pets are hand-placed **32 × 32** sprites in `Sources/PerchCore/Pixel*.swift`:
front, side, from-behind and curled views, with dog/cat heads and floppy/pointed
ears composed per pack. Each pixel names a palette slot (coat light/base/shade,
ear, marking, eye, collar…). `PixelPalette(pack:)` derives hue-shifted ramps
from the pack's three colors and maps markings: chest adds the blaze, bib and
tail tip; socks whitens the paws; tuxedo does both; the muzzle always uses the
marking color. A one-pixel outline in a dark tone of the coat is added around
the silhouette, softened where it only touches light markings.

Every action has up to four distinct frames spread over twelve playback slots
(walk cycle, tail wags, blinks, chewing, a three-step pull-up). Paws rest on
row 30; the climb's paws hook over row 13 so the engine's `hangDepth` keeps
them on the window edge. Small/medium/large draw each art pixel at 2/3/4
points with nearest-neighbor filtering, positions snap to device pixels, and the
desktop home uses the same grid. Hit testing reads the rendered sprite's alpha.

`--capture-sprites` writes `dist/native-sprites.png`: every action's frames for
five trait combinations, drawn offscreen without capturing any window.
`PixelSpriteTests` check that every pose leaves room for its outline, grounded
poses touch the paw row, markings recolor only their pixels, and the eating
nose reaches the bowl at every size.

All artifacts are ignored by `native/.gitignore`.

Verified on macOS 26.3 / Swift 6.2.4: **19 focused XCTest cases passed**,
both Mach-O architectures declare macOS 14.0, the ZIP checksum and archive
integrity passed, and the signature is ad-hoc with no Team ID. The owned fixture
rode six real bounds changes (84 points total) with zero paw-alignment error,
then verified fast/minimized/closed-target falls and floor landing. Eight native
PNG captures and JSON counters are persisted in `dist/`. See
`dist/verification.log` for the actual final run rather than inferred results.

The 0.2.0 build passed **37 XCTest cases** (including walking share, hop-downs,
wall stops, push requests only when allowed, one bite per chew, a ball chase
that follows the ball down to the floor, fast balls staying out of the Dock
strip, no flicker on ledges narrower than the pet, and calm pets staying out of
mischief) and the full `scripts/verify.sh` run: owned-window rides with zero
paw error, falls, alpha routing on 32 px sprites, ten pointer checks, bowl
routing, meal and nap, nine mischief checks, and pack round trip.

The pointer-routing refinement was separately verified with the same 19
XCTest cases and **10 new owned-fixture checks**, then rebuilt and rechecked
using the universal app executable. The current archive's checksum, ZIP
integrity and ad-hoc signature passed. Latest targeted logs:
`dist/pointer-verification.log` and `dist/pointer-release.log`.
The callback timing in `dist/pointer-routing-evidence.json` measures the
synchronous fixture callback only, not operating-system event-delivery latency.

## Release gates / intentionally incomplete PRD items

This is an **ad-hoc signed experimental alpha**, not a notarized public release.
The supplied `scripts/notarize.sh` requires an explicitly chosen
`DEVELOPER_ID_APPLICATION="Developer ID Application: …"` and a configured
`NOTARY_PROFILE`; it does not select an existing identity or accept terms.
It signs hardened runtime, submits, staples, validates and creates a separate
notarized ZIP. Developer ID/notarization remains a launch gate.

Not implemented: keyboard-speed monitoring/break nudges (deliberately excluded
for privacy), autonomous sniff/hop reactions specifically to newly opened
windows, free placement of food outside the bowl, a clickable ball,
audio purrs, AI/photo-to-3D/generated sprite pipelines,
gift hosting, Accessibility observers, multiple simultaneous pets.
The two-pull climb is an authored animation, not physics-based wall climbing.

Still **not verified**: real-user keyboard/VoiceOver walks, Escape focus in
every host-app configuration, actual locked/full-screen Spaces transitions,
physical multi-monitor hot-plug on hardware, notarized macOS 14 launch,
Intel hardware launch, Vision results on real pet photos, actual global-hotkey
delivery from every host app, battery impact and PRD CPU/memory targets. Geometry,
adjacent/negative displays and bed/lock hiding are automated; lock is simulated
in the fixture. Do not confuse that with real lock-screen testing.

No ten-real-pet comparison, owner recognition rate, two-week retention, twenty
outside testers, pricing validation or target-hardware performance claims are
made. Those require genuine usage and consenting pet owners.
