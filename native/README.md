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

## Red panda (0.2.0)

Choose **Species → Red panda** in Settings. It starts in red panda colors, all
editable:

- **Coat** (warm orange) colors the body and head.
- **Ear color** (dark brown) dresses the legs, chest and inner ears.
- **Marking color** (cream) is the face mask and ear rims.

The pixel art follows the owner's reference sprites:

- a big round head with cream-rimmed ears;
- white brow dots, cheeks and muzzle, split by rust tear-lines;
- a long tail in alternating orange and rust rings;
- a warm plum outline.

On the floor it sleeps sprawled flat, legs stretched out and tail curled up.
A red panda saved in the first default colors (#C2532B coat) picks up the new
ones when Perch opens; edited colors are kept. Red pandas walk the top edges like
the others, but every few seconds they also grab a window: over the top edge
and down its face, or straight onto a window behind them from the floor. On the
face they crawl about seen from behind, limbs spread and ringed tail hanging.
On a side they turn a quarter, paws gripping the edge and body outside the
window, heading up or down. They climb back over the top where it's uncovered,
or let go and drop to whatever is below.

Holding on works like riding: a slowly moved window carries the panda along, a
flung or closed one makes it fall, and windows in front hide it. Picking it up
or sending it to bed makes it let go. Calm mode and Reduce Motion keep it on the
edges. Only position and size of windows are read; climbing never needs
Accessibility and never changes the window.

### Sticky paws and cursor play

Red pandas are sticky. They hold on to a window through a brisk drag (they only
let go above 1,300 points/second, double the dog and cat limit). When falling
past a window's face, they catch hold of it partway down more often than not,
then climb on from there.

**Play with the pointer** (Settings → Mischief, on by default, red pandas only):

- **Stalking:** when the pointer lingers within about 300 points, the panda
  looks at it, then stalks it. It runs along the edge it is on, climbs the
  window face behind it, scrambles up to a ledge under the pointer, or hops
  down toward it.
- **Swiping and grabbing:** in reach, it rears up on its hind legs with
  forepaws high and swipes. A pointer high enough to dangle from gets grabbed
  with a little leap, and a low one just gets batted.
- **Riding:** once it grabs on, it hangs by its teeth from the pointer's tip,
  forepaws hugging it, legs kicking. It rides along wherever the pointer goes,
  swinging out behind it like a pendulum.
- **Shaking it off:** ordinary moves keep it on. A quick back-and-forth shake
  (three reversals in under a second) or a hard fling drops it. Otherwise it
  lets go on its own after 6 to 16 seconds.
- **Startle:** a pointer whizzing right past makes it rear up with arms high,
  the red panda's defensive stance.

**Bamboo on the pointer** (Settings → Mischief → **Carry bamboo on the
pointer**, on by default, needs pointer play):

- A pixel bamboo stalk, with node bands and a leafy sprig, hangs from the
  pointer's tip.
- The panda chases the stalk's bottom end. Once it grabs on, it holds the
  stalk upright in front of its face, forepaws on either side, and eats it
  from the bottom up, climbing the stalk as it goes.
- A whole stalk takes about ten seconds. Then it hops down happy, and the
  bamboo grows back over about 40 seconds. It ignores a stalk shorter than
  about 60%.
- macOS doesn't let an app replace the pointer in other apps, so Perch draws
  the bamboo in its own overlay beside the system arrow. The bamboo never
  takes clicks.

While it hangs, clicks pass straight through to whatever is underneath. Cursor
play only uses where the pointer is right now and a smoothed speed. Nothing is
stored, clicks and keys are never watched, and the real pointer is never
moved. Calm mode, Reduce Motion, quiet hours, bedtime and a hungry pet all end
the game.

### Moving like a red panda

The behaviors draw on zoo and field sources:

- Smithsonian's National Zoo, San Diego Zoo Wildlife Alliance, Animal
  Diversity Web and the Red Panda Network for anatomy and behavior.
- Plocek & Dunham (2023) for the lateral-sequence gait.
- Bugler et al. (2023) for captive activity budgets.

What the pet does with them:

- **Amble:** a low, deliberate walk at 0.85× the dog's pace, slower still
  (0.7×) along narrow window edges. It is still on the move most of the time.
- **Climbing:** face toward you, chunky dark limbs splayed, one arm reaching as
  the opposite leg pushes. The ringed tail swings for balance. It comes down
  **head first**, as real red pandas do.
- **Pauses:** sniffing, **washing its face** (licks a forepaw, then wipes),
  **nibbling an apple** held in both forepaws (a zoo favourite), and sudden
  short **bounds**.
- **Sleep:** high up it **drapes over a window edge**, legs and tail hanging,
  as red pandas stretch out on branches in warm weather. On the floor it curls
  up.
- **Toy:** its ball is an apple, and its treat is the bamboo on your pointer.

The cursor game itself is a playful interpretation of red panda object play,
not observed behavior.

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
- **Pushes a window in its way** (opt-in). In **Settings → Mischief**, click
  **Set up window pushing…**: it turns the option on, asks macOS for
  Accessibility, opens System Settings at Privacy & Security → Accessibility,
  and updates by itself once you switch Perch on. **Test it** then slides a
  small Perch-owned window to prove the permission works. If Perch shows as
  switched on but still lacks access (macOS remembered an older build),
  **Reset and ask again** clears only Perch's record and asks again. Once allowed, bumping into
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
- Slow moves ride; moves over 650 points/second detach (1,300 for red pandas). Gravity snaps to the
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
  With a red panda and **Play with the pointer** on, each tick also hands the
  engine the pointer's current position. The engine keeps only that position and
  a smoothed speed until the next tick. While it hangs from the pointer the
  overlay stays click-through.
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
signs it and produces the files below. By default the signature is ad-hoc, and
macOS forgets Perch's Accessibility permission whenever it is rebuilt. Set
`PERCH_SIGN_IDENTITY` to a local signing identity, such as one listed by
`security find-identity -v -p codesigning`, to keep the permission across rebuilds:

```sh
PERCH_SIGN_IDENTITY="Apple Development: YOUR NAME (ID)" bash scripts/build-app.sh
```

Either way the build is not Developer ID signed or notarized.

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
dist/Perch.app/Contents/MacOS/Perch --verify-climb
dist/Perch.app/Contents/MacOS/Perch --verify-cursor
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
  special poses, for five dog/cat, ear and marking combinations and a red panda:
  - dine, chew, push and pounce;
  - crawl, side climb and head-first descent;
  - arms-up grab, hanging from the pointer, draped sleep, grooming and apple
    nibbling.
- `dist/native-climb-face.png`, `dist/native-climb-side.png`,
  `dist/climb-evidence.json`: a red panda on an owned window, captured from the
  real SpriteKit overlay. It crawls the face upright (head first when heading down), then grips a side turned a
  quarter with its paws on the edge (within 1 pt) and its body outside, and
  rides the window when it moves.
- `dist/native-cursor-hang.png`, `dist/native-cursor-ride.png`,
  `dist/native-drape.png`, `dist/cursor-evidence.json`: a red panda and a
  **synthetic** pointer above an owned window, from the real overlay. A stand-in
  arrow and the real bamboo view's image are drawn into the image, and the real
  pointer is never moved. It covers thirteen checks:
  - it stalks the pointer's bamboo, rears up and grabs it;
  - the bamboo view sits on the pointer tip and never takes clicks;
  - its teeth sit on the stalk's bottom end (within 1.5 pt), and it eats the
    stalk from the bottom up;
  - the overlay stays click-through with the pointer over the pet;
  - it rides a brisk move swinging out behind;
  - a shake drops it;
  - it catches the window face while falling;
  - it sleeps draped over the edge, with its belly on the edge.
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
front, side, from-behind and curled views, with dog, cat and red panda heads,
floppy/pointed ears and tails composed per pack. Each pixel names a palette slot (coat light/base/shade,
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

The 0.2.0 build passed **43 XCTest cases** (including red panda climbing of
faces and sides with a return over the top, riding and falling off a moved
window, dogs and cats never leaving the edges, walking share, hop-downs,
wall stops, push requests only when allowed, one bite per chew, a ball chase
that follows the ball down to the floor, fast balls staying out of the Dock
strip, no flicker on ledges narrower than the pet, and calm pets staying out of
mischief) and the full `scripts/verify.sh` run: owned-window rides with zero
paw error, falls, alpha routing on 32 px sprites, ten pointer checks, bowl
routing, meal and nap, nine mischief checks, and pack round trip.

Cursor play, sticky paws, the bamboo and the red panda poses added **13 more
XCTest cases** (56 in all), plus the owned-window `--verify-cursor` run above:

- eating a whole bamboo stalk from the bottom up, hopping off happy, ignoring a
  stub, and the stalk growing back;
- bamboo geometry (top on the tip, end under it) and every stalk length
  fitting its outline;
- moving only untouched first-default red panda colors to the new ones;

- stalk, swipe, grab, ride and a shake that drops it;
- letting go down by the Dock lands it on the floor instead of leaving it
  stuck below;
- letting go on its own, and on pickup or bedtime;
- a low pointer gets batted, never ridden below the floor;
- no cursor play for dogs and cats, with the setting off, in calm mode or under
  Reduce Motion;
- the arms-up startle;
- a panda gripping through a drag that throws a dog off;
- mid-fall window catches;
- head-first descent, grooming, apple and drape poses, and still walking most
  of the time;
- the hang and drape anchor rows.

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
