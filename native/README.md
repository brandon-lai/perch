# Perch native alpha

Native Swift 6.2 package, macOS **14 or newer**. AppKit transparent overlays,
SpriteKit pixel art and a SwiftUI settings window; not a web shell. No cloud,
account, generation provider, uploads, audio, or telemetry.

Perch is a little **red panda** that lives on your desktop: it explores your
windows, chases your pointer, and naps in its tree.

## Run and verify

From `/Users/brandon/Documents/Dev/perch/native`:

```sh
swift test
swift run Perch
```

First launch shows Maple, a red panda. In Settings you can rename it and edit its
three colors:

- **Coat** colors the body and head.
- **Legs and ears** colors the legs, chest and inner ears.
- **Face mask** colors the face mask and ear rims.

Every change waits for **Save & wake**.

The menu-bar paw offers these actions:

- wake, send to bed, and pet;
- go to its tree, play ball, and tidy up bite marks;
- high five, hop to a window, peek from the menu bar, and move to the next
  display;
- settings and quit.

How you interact with it:

- **Pet it:** click the panda's opaque pixels.
- **Look:** hover over it.
- **Pick it up:** drag to hold it, then release and it falls.
- **Cancel a drag:** press Escape when the overlay has keyboard focus.

Settings and the menu provide non-drag alternatives. **Control–Option–Command–B**
is registered as a Carbon hotkey, not a global keyboard event tap.

## Its tree

A little pixel tree stands at the bottom of the main display, on the same pixel
grid as the panda. It has a crown of leaves, a trunk and a branch.

- **Moving the tree:** drag it along the bottom of any display. Settings → Its
  tree offers the same without dragging: a **Display** picker and a
  **Position** slider. **Show its tree** turns it off.
- **Clicks:** only the tree's painted pixels take clicks; clicks anywhere else
  pass through.
- **Bedtime:** at quiet hours, or after five minutes of no input, the panda
  walks to the tree, crossing displays if needed. It crawls up the trunk,
  hugging it with its face toward you, and sleeps draped over the branch.
- **Waking:** when you're back, it stretches, walks to the trunk and backs down
  it, tail first.
- **Visits:** it also climbs up for short rests (washing, an apple, a doze),
  sometimes after eating a stalk of bamboo. **Go to its tree** in the menu or
  Settings sends it now.
- **Moving the tree with the panda on it:** the panda rides the branch.
- **Hiding:** tucking the panda away hides the tree too.

The tree replaces the earlier rug, cushion and food bowl; there is no hunger or
feeding.

## The red panda

The pixel art follows the owner's reference sprites:

- a big round head with cream-rimmed ears;
- white brow dots, cheeks and muzzle, split by rust tear-lines;
- dark brown legs with pale claws;
- a long ringed tail that sweeps up behind it as it walks;
- a warm plum outline.

It is small: 32 × 32 art at 1, 1.5 or 2 points per pixel for small, medium and
large. On Retina displays every art pixel stays square and crisp.

A red panda saved in the first default colors (#C2532B coat) picks up the new
ones when Perch opens; edited colors are kept. Packs made for the earlier dog
and cat pets open as a red panda in its own colors, keeping their name, size
and temperament.

### Always exploring

It is on the move nearly all the time, with only short pauses. It mostly runs
errands across its display: to a spot on a window's face, a window's top edge,
the far end of the floor, or its tree.

To get there it:

- walks and gallops along edges;
- climbs up the face of the window behind it;
- walks over to a window's side and climbs the edge, side on, to the top corner;
- leaps up to grab a window's bottom edge;
- backs down a tall window's side rather than jumping, and steps off onto the
  floor;
- pulls itself up over tops and backs down faces.

Climbing is drawn after photos of red pandas on trunks and branches:

- **Up a face or the trunk:** seen from behind, with a long body between short,
  chunky gripping legs and the ringed tail hanging for balance. Holding still,
  it looks back over its shoulder at you.
- **Down:** it is never upside down. It backs down tail first, head up and
  looking at you, with its paws stepping backwards.
- **Diagonally or straight across a face:** side on, body along its way like
  a red panda on a branch: up a diagonal, straight across, or gently downhill.
- **Legs on dark desktops:** the near legs catch the light along their top
  edge, so they don't vanish against a dark background.
- **A window's side:** side on, belly to the edge, claws hooked over it and its
  body outside the window. It usually keeps climbing up or down the edge.

The paws move in a diagonal sequence through four stride frames. The engine
picks the frame from how far the panda has climbed, so paws never slide, and
the body surges as each pair of paws pulls.

Holding on works like riding: a slowly moved window carries the panda along, a
flung or closed one makes it fall, and windows in front hide it.

Red pandas are sticky:

- They hold on through a brisk drag, letting go only above 1,300
  points/second.
- When falling past a window's face, they usually catch hold partway down.

Picking it up or sending it to bed makes it let go. Calm mode keeps it gentler,
and Reduce Motion keeps it still. Only window positions and sizes are read;
climbing never needs Accessibility and never changes the window.

### Chasing the pointer

With **Chase the pointer** on (Settings → Mischief, on by default), the pointer
is irresistible anywhere on the panda's display:

- **Noticing:** it looks round at the pointer, then goes after it, along edges,
  up window faces and across them, and off whichever edge faces the pointer.
- **Leaping:** a pointer above what it can reach standing gets a leap, and it
  snatches it in mid-air.
- **Grabbing:** in reach, it rears up on its hind legs and swipes, then grabs
  on. It holds a pointer high enough to dangle from and bats a low one.
- **Riding:** it hangs from the pointer, forepaws gripping and legs kicking,
  rides along wherever it goes and swings out behind it.
- **Shaking it off:** ordinary moves keep it on. A quick back-and-forth shake
  (three reversals in under a second) or a hard fling drops it.
- **Coming back:** after a shake it takes a few seconds' breather, then comes
  back for more. If a couple of chases can't reach the pointer, it explores for
  a while instead.
- **Startle:** a pointer whizzing right past makes it rear up with arms high,
  the red panda's defensive stance.

**Make the pointer bamboo** (on by default) turns the pointer into a pixel
bamboo stalk, tip first:

- The panda goes for the stalk's bottom end. Once it grabs on, it holds the
  stalk upright in front of its face and eats it from the bottom up.
- A whole stalk takes about ten seconds. Then it hops down happy, sometimes off
  to its tree. The bamboo grows back over about 40 seconds, and it ignores a
  stalk shorter than about 60%.
- Only the arrow changes. Text cursors, pointing hands and resize arrows stay
  as they are, and over a full-screen app the arrow is back to normal.
- macOS has no public way to change the pointer everywhere. Perch uses
  WindowServer's cursor registry, the private interface cursor customizers
  use, and registers the stalk under both standard arrow names.
- Your own arrow is saved first, in memory and in WindowServer under Perch's
  names. It comes back exactly when the game pauses, when Perch quits, sleeps,
  is tucked away or is sent `SIGTERM`, and at the next launch if Perch crashed.
  A tiny guard process (`Perch --pointer-guard <pid>`) waits for Perch to exit,
  however it exits, and restores the arrow too.
- If the registry is ever unavailable, Perch draws the stalk in its own overlay
  beside the system arrow instead.

While it hangs, clicks pass straight through to whatever is underneath, and the
bamboo never takes clicks. Chasing only uses where the pointer is right now and
a smoothed speed. Nothing is stored, clicks and keys are never watched, and the
real pointer is never moved. Calm mode, Reduce Motion, quiet hours, bedtime and
tree visits all pause the game.

### Moving like a red panda

The behaviors draw on zoo and field sources:

- Smithsonian's National Zoo, San Diego Zoo Wildlife Alliance, Animal
  Diversity Web and the Red Panda Network for anatomy and behavior.
- Plocek & Dunham (2023) for the lateral-sequence gait.
- Bugler et al. (2023) for captive activity budgets.

What the panda does with them:

- **Gait:** a low amble, slower along narrow edges, and a gallop (stretched
  out, then gathered) when chasing or bounding.
- **Climbing:** short, chunky dark limbs, one arm reaching as the opposite leg
  pushes. The ringed tail swings for balance. Real red pandas come down head
  first, but upside down looked odd on a desktop, so it backs down tail first.
- **Pauses:** sniffing, **washing its face** (licks a forepaw, then wipes),
  **nibbling an apple** held in both forepaws, and sudden short bounds.
- **Sleep:** up high it **drapes over a branch or window edge**, legs and tail
  hanging, as red pandas stretch out on branches in warm weather. On the floor
  it sleeps sprawled flat with its tail curled up.
- **Toys:** its ball is an apple, and its treat is the bamboo on your pointer.

The cursor game itself is a playful interpretation of red panda object play,
not observed behavior.

## Mischief

Unprompted every few minutes, it also does one of these:

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

Calm mode keeps the panda wandering, slower and with longer pauses, but with
no mischief, errands, chasing or pushing. Reduce Motion keeps it still. The
engine only emits requests (`PetEvent.bite`, `.push`); the app decides whether
to act on them.

It also hooks its front paws over a reachable window edge now and then, gives
two pulls and climbs up. **Hop to a window** lets you try it on demand; the
window itself never moves.

**Save & wake** explicitly persists the confirmed pack and settings:

```
~/Library/Application Support/Perch/pet.perchpack
~/Library/Application Support/Perch/preferences.json
```

Preferences hold quiet hours, calm mode, the tree's display and position, and
the mischief switches. Dragging the tree saves its new place.

Sleep works like this:

- After five minutes of system inactivity, or at quiet hours, the panda naps in
  its tree. Quiet and idle sleep stay visible and pause the SpriteKit scene.
- **Send to bed** hides it instead.
- Reduce Motion freezes pose animation and disables wandering.
- All interactions are silent.

**Delete saved pet** removes the saved files and hides the panda; it doesn't
erase your exported packs. A `care.json` left over from the old food bowl is
removed with it.

## Packs

Import/export uses the exact shared `../docs/PACK.md` JSON contract. Version,
rig, colors, finite anchors, timing, size, complete 19-action coverage and
duplicate/unknown actions are validated. The `.perchpack` is UTF-8 JSON, not a
ZIP or executable. Import stages traits for confirmation rather than saving
immediately. Double-clicking a pack opens the same review window in the app.
The registered `perch:` URL scheme does not download remote data.

`Tests/PerchCoreTests/Fixtures/browser.perchpack` reproduces the browser's
19-action manifest, including single-frame sleep. XCTest imports it, exports
it, checks exact top-level keys and round-trips it. Packs from the earlier dog
and cat builder still validate and open as a red panda. Render verification
exports `dist/Maple.perchpack` and `dist/Cinnamon.perchpack`.

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
- Slow moves ride; moves over 1,300 points/second detach. Gravity snaps to the
  highest crossed surface. Closed/minimized/occluded support falls. Display
  changes rebuild overlays; adjacent floors support cross-display walking.
- Polling is 10 Hz normally, 30 Hz while riding, climbing or chasing, 2 Hz while asleep. Motion is
  capped at 30 fps; sleep pauses rendering. Locked/inactive/sleeping sessions
  stop timers and hide windows. Full-screen-size front windows hide that display.
- Global and local **mouseMoved-only** monitors immediately sample
  `NSEvent.mouseLocation` and refresh alpha-based `ignoresMouseEvents` routing
  on the main thread. The global event payload is ignored; local events are
  returned unchanged. No key/button/scroll monitoring, event-content inspection,
  coordinate history, event persistence, camera or screen capture is added.
  With **Chase the pointer** on, each tick also hands the engine the pointer's
  current position (or the bamboo's end). The engine keeps only that position
  and a smoothed speed until the next tick. Mouse moves also reposition the
  bamboo view. While the panda hangs from the pointer the overlay stays
  click-through.
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
dist/Perch-0.3.1-universal.zip
dist/Perch-0.3.1-universal.zip.sha256
```

Individual graphical checks (run from `native/`, a logged-in GUI required):

```sh
dist/Perch.app/Contents/MacOS/Perch --capture-preview
dist/Perch.app/Contents/MacOS/Perch --capture-settings
dist/Perch.app/Contents/MacOS/Perch --verify-fixture
dist/Perch.app/Contents/MacOS/Perch --verify-tree
dist/Perch.app/Contents/MacOS/Perch --verify-mischief
dist/Perch.app/Contents/MacOS/Perch --verify-climb
dist/Perch.app/Contents/MacOS/Perch --verify-cursor
dist/Perch.app/Contents/MacOS/Perch --verify-pointer
dist/Perch.app/Contents/MacOS/Perch --capture-sprites
dist/Perch.app/Contents/MacOS/Perch --capture-climb-poses
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

- `dist/native-preview.png`, `dist/native-preview-cinnamon.png`: twelve actual
  poses each, for two red panda color sets, from the rig used by the overlay.
- `dist/native-sprites.png`: all nineteen actions' distinct frames, plus the
  special poses, in two red panda color sets:
  - chew, push and pounce;
  - climbing up and backing down faces, up and down a window's side, and
    diagonally, straight across and gently downhill;
  - arms-up grab, hanging from the pointer, draped sleep, grooming and apple
    nibbling;
  - gallop and leap.
- `dist/native-climb-face.png`, `dist/native-climb-side.png`,
  `dist/climb-evidence.json`: a red panda on an owned window, captured from the
  real SpriteKit overlay. Ten checks:
  - on the face its pose follows its heading, upright and drawn about its torso;
  - the stride frame on screen is the engine's, from how far it has climbed;
  - on a side it's upright and side on, facing the window;
  - its paws are on the edge and its body is outside it, by the rendered alpha;
  - it rides the window when it moves.
- `dist/native-climb-poses.png`: every climbing pose's four stride frames and
  still frame, large, with the frame's middle marked.
- `dist/pointer-evidence.json`: the bamboo pointer with WindowServer's real
  arrow (`--verify-pointer`). It changes the pointer for a few seconds and
  captures nothing on screen. Ten checks:
  - the arrow becomes the stalk, with its tip as the hotspot, at 1×, 2×, 5× and
    10×;
  - the real arrows are saved first;
  - the pointer on screen is the stalk, then the arrow again (when it was
    showing the arrow);
  - an eaten stalk is shorter, and a nearly gone one is the arrow;
  - putting it away restores the arrow exactly and removes the saved copies;
  - a leftover stalk from a crashed Perch is recovered at launch;
  - the guard restores the arrow after a Perch is killed with `SIGKILL`.
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
  colors and scrolled quiet-hours/tree/mischief/import/export/delete controls.
- `dist/native-fixture-ride.png`, `dist/native-fixture-fall.png`: owned-window
  checks; `dist/native-spritekit.png`: actual SpriteKit render.
- `dist/native-overlay-ride.png`: the actual SpriteKit overlay after six
  frame/bounds-driven rides, with only our fixture's outline/label added for
  alignment evidence. This is our scene texture, never a desktop screenshot.
- `dist/render-evidence.json`, `dist/fixture-evidence.json`: dimensions,
  sampled-color counts, actual ride/fall outcomes and privacy-safe diagnostics.
- `dist/pack-evidence.json`, `dist/imported-roundtrip.perchpack`: executable
  import/export verification of a browser-format fixture.
- `dist/native-tree-climb.png`, `dist/native-tree-nap.png`,
  `dist/tree-evidence.json`: the tree and the panda's rendered frames at the
  positions used by the overlay. Nine checks:
  - the trunk takes clicks and clicks beside it pass through;
  - dragging moves it;
  - at bedtime the panda crawls up the trunk and naps draped over the branch,
    belly on the branch within 1 pt;
  - awake, it backs down the trunk;
  - **Go to its tree** sends it back up;
  - tucking it away hides the tree.
- `dist/pointer-routing-evidence.json`: ten targeted awake/sleeping routing and
  lifecycle checks through the actual monitor callbacks with synthetic owned
  coordinates, including transparent sprite pixels, unchanged local events,
  paused sleep, no timer/engine/window-list tick, and cleanup. The fixture does
  not move the shared cursor or record private input.

## Pixel art

The red panda is hand-placed **32 × 32** sprites in `Sources/PerchCore/Pixel*.swift`,
and **48 × 48** climbing frames in `PandaClimb.swift`:

- **Views:** front, side, from behind and upside down. The fixed parts (front
  head, sitting body, back of the head, side head) are character grids.
- **Tails:** drawn as a ringed curve that tapers from base to tip.
- **Climbing:** an articulated figure rasterized straight into the grid: a
  tapered torso along its spine, jointed limbs ending in paws with pale claws,
  the ringed tail and the character-grid heads. Frames are drawn about the
  torso, or for a window's side about the edge (column 24).
- **Palette:** each pixel names a palette slot. `PixelPalette(pack:)` derives
  hue-shifted ramps from the pack's three colors. A one-pixel warm plum outline
  goes around the silhouette, softened where it only touches the cream face
  mask.

Every action has up to four distinct frames spread over twelve playback slots
(walk cycle, gallop, tail sway, blinks, chewing, a three-step pull-up).

- **Anchors:** paws rest on row 30. The climb's paws hook over row 13, the hang
  pose holds the pointer at row 14, and the drape's belly rests on row 20.
- **Rendering:** nearest-neighbor filtering, with positions snapped to device
  pixels. The tree and the bamboo use the same grid.
- **Hit testing:** reads the rendered sprite's alpha.

`--capture-sprites` writes `dist/native-sprites.png` offscreen, without capturing
any window. `PixelSpriteTests` check that:

- every pose and the tree leave room for their outline;
- climbing poses stride through four distinct frames with claws out, keep their
  body off a window's edge, and carry their head where the engine thinks;
- grounded poses touch the paw row;
- the walking tail is long and ringed;
- the gallop stretches out and gathers;
- the pack colors dress the right parts.

All artifacts are ignored by `native/.gitignore`.

Verified on macOS 26.3 / Swift 6.2.4: **19 focused XCTest cases passed**,
both Mach-O architectures declare macOS 14.0, the ZIP checksum and archive
integrity passed, and the signature is ad-hoc with no Team ID. The owned fixture
rode six real bounds changes (84 points total) with zero paw-alignment error,
then verified fast/minimized/closed-target falls and floor landing. Eight native
PNG captures and JSON counters are persisted in `dist/`. See
`dist/verification.log` for the actual final run rather than inferred results.

The 0.3.1 build passed **70 XCTest cases** and the full signed
`scripts/verify.sh` run. The tests cover:

- **Exploring:** climbing faces and sides with a return over the top; riding
  and falling off a moved window; holding on through a brisk drag; mid-fall
  window catches.
- **Climbing:** gripping a window's side side on and striding up it to pull
  over the top corner, with every stride frame in order and a surge with each
  pull; backing down a side, its stride reversed, and stepping off; climbing up beside a
  tall window instead of floating up to it; following a window dragged away
  mid-errand; coming down only from a window's real corner; poses following the
  heading; the
  climbing art's stride frames, claws, tails and head positions.
- **The pointer:** a screen-wide chase up a window face to the pointer;
  snatching a pointer in mid-air; stalk, swipe, grab, ride, shake-off and
  coming back for more; a low pointer gets batted.
- **Bamboo:** eating it from the bottom up and its regrowth.
- **The tree:** bedtime across displays up the trunk to a draped nap and a
  descent; visits; riding the branch while the tree is dragged.
- **Research poses:** grooming, an apple, sleeping draped over a ledge.
- **Settings respected:** Calm mode, Reduce Motion and the chase switch.
- **Packs:** packs and colors moving to red panda.

The fixtures cover owned-window rides with zero paw error, falls, alpha routing,
ten pointer checks, nine tree checks, nine mischief checks, eight climbing
checks, thirteen cursor and bamboo checks, and pack round trip.

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
windows, a clickable ball, audio, AI/photo-to-3D/generated sprite pipelines,
gift hosting, Accessibility observers, multiple simultaneous pets, and pets
other than the red panda (removed in favor of one fully realized animal).
The two-pull climb is an authored animation, not physics-based wall climbing.

Still **not verified**: real-user keyboard/VoiceOver walks, Escape focus in
every host-app configuration, actual locked/full-screen Spaces transitions,
physical multi-monitor hot-plug on hardware, notarized macOS 14 launch,
Intel hardware launch, actual global-hotkey
delivery from every host app, battery impact and PRD CPU/memory targets. Geometry,
adjacent/negative displays and bed/lock hiding are automated; lock is simulated
in the fixture. Do not confuse that with real lock-screen testing.

No two-week retention, outside testers, pricing validation or target-hardware
performance claims are made. Those require genuine usage. The panda chasing
your real pointer and its battery cost over a working day are not measured.
