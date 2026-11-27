# Perch native alpha

Native Swift 6.2 package, macOS **14 or newer**. AppKit transparent overlays,
SpriteKit pixel art and a SwiftUI settings window; not a web shell. No cloud,
account, generation provider, uploads, audio, or telemetry.

Perch is a little **red panda** that lives on your desktop. It lives its own
life: it explores your windows and the edges of your screen, nibbles window
edges, naps draped over a window's top edge or up in its tree and, now and
then, chases the bamboo on your pointer.

It is deliberately opinionated: one red panda in one look, with no style
packs, colors, sizes or temperaments to choose.

## Run and verify

From `/Users/brandon/Documents/Dev/perch/native`:

```sh
swift test
swift run Perch
```

First launch shows Maple, a red panda. Settings lets you rename it; the name is
saved with **Save & wake**. The rest of Settings is quiet hours, its tree and the
mischief switches.

The menu-bar paw offers these actions:

- wake, take a nap, tuck away (hide it), and pet;
- go to its tree, play ball, and tidy up bite marks;
- high five, climb a window, peek from the menu bar, and move to the next
  display;
- settings and quit.

How you interact with it:

- **Pet it:** click the panda's opaque pixels. Asleep, it snuggles in.
- **Wake it:** double-click it while it sleeps, or choose **Wake**.
- **Look:** hover over it. Asleep, it lifts its head and peeks.
- **Pick it up:** drag to hold it, then release and it falls. The first press
  works even though Perch is never the active app (its overlay accepts the
  first mouse). Picked up asleep, it dozes on in your hand.
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
  walks to the tree, crossing displays if needed. It grips the side of the
  trunk under the branch, climbs it side on, pulls itself onto the branch and
  sleeps draped over it.
- **Waking:** when you're back, it stretches, walks to the trunk and backs down
  its side.
- **Visits:** it also climbs up for short rests (washing, an apple, a doze),
  sometimes after eating a stalk of bamboo. **Go to its tree** in the menu or
  Settings sends it now.
- **Moving the tree with the panda on it:** the panda rides the branch.
- **Naps:** it also naps up here in the day (see [Naps](#naps)).
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

It is small: 32 × 32 art at 1.5 points per pixel. On Retina displays every art
pixel stays square and crisp.

There is one look. A pet saved by an earlier version (any colors, size,
temperament or species) opens as this red panda, keeping only its name.

### Exploring, between rests

Like a real red panda it rests most of the day (see [Naps](#naps)). In its
spells awake it explores: errands across its display up a window's side, to a
window's top edge, up the side of the screen, the far end of the floor, or its
tree.

When it hurries it simply walks faster: the same walk cycle on its short legs,
played quicker. It never stands up on its hind legs.

It moves with moderate realism. It only hops up and pulls itself onto a ledge
within half again its own height, and leaps a little over twice its height at
most. Anything higher it climbs to: up a window's side when the window comes
down to within a reach of where it stands, or by leaping up to hang from a
higher window's bottom edge and climbing round. It never jumps from the ground
straight onto a tall window, and it only picks nap spots it can get to.

It climbs around a window's **edges** only, never across its face, and always
side on:

- **Up and down a side:** belly to the edge, short chunky legs with claws
  hooked over it, its body outside the window and the ringed tail hanging for
  balance. Going down it backs down, head up, never upside down.
- **Along the bottom:** where a window floats above the floor, it swings round
  the bottom corner and hangs from the bottom edge, going hand over hand like
  monkey bars, and round the other corner and up that side.
- **Over the top:** at a top corner it pulls itself up, forepaws flat on the
  edge and hind feet scrabbling, then walks along the top. At a top corner it
  often backs down the side rather than hopping off.

- **The screen's own edges:** at either end of the floor it grips the side of
  the screen and climbs it the same way, turns the top corner and goes hand
  over hand along the top of the screen just under the menu bar, then round
  the far corner and back down. It stays inside the visible screen.

To get onto a window it walks over to its side and grips the edge, leaps up to
hang from the bottom edge of a window above it, or grabs a side it's falling
past. Its legs catch the light along their top edge, so they don't vanish
against a dark desktop.

The paws move in a diagonal sequence through four stride frames. The engine
picks the frame from how far the panda has climbed, so paws never slide, and
the body surges as each pair of paws pulls.

Holding on works like riding: a slowly moved window carries the panda along, a
flung or closed one makes it fall, and windows in front hide it.

Red pandas are sticky:

- They hold on through a brisk drag, letting go only above 1,300
  points/second.
- When falling right past a window's side, they usually grab the edge partway
  down.

Picking it up or sending it to bed makes it let go. Reduce Motion keeps it
still. Only window positions and sizes are read;
climbing never needs Accessibility and never changes the window.

### Chasing the pointer

With **Chase the pointer** on (Settings → Mischief, on by default), the panda
mostly ignores the pointer and gets on with its own life. Now and then (about
every 40–90 seconds of being awake, and less often after it misses) it decides
to go after it:

- **Noticing:** it looks round at the pointer, then goes after it, along edges
  and up the side of the window nearer the pointer, or up the side of the
  screen when that is closer. Level with a pointer, it leaps off the edge for
  it. A pointer out of reach just gets a look.
- **Leaping:** a pointer above what it can reach standing gets a leap, and it
  snatches it in mid-air.
- **Grabbing:** in reach, it crouches, pounces and grabs on, staying on all
  fours. It holds a pointer high enough to dangle from and bats a low one.
- **Riding:** it hangs from the pointer, forepaws gripping and legs kicking,
  rides along wherever it goes and swings out behind it.
- **Shaking it off:** ordinary moves keep it on. A quick back-and-forth shake
  (three reversals in under a second) or a hard fling drops it.
- **Afterwards:** after a shake-off it leaves the pointer alone for 25–45
  seconds, after a chase 40–80 seconds (longer after two misses), and after a
  whole stalk of bamboo a minute and a half or more.

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
real pointer is never moved. Reduce Motion, quiet hours, bedtime and tree
visits all pause the game.

### Moving like a red panda

The behaviors draw on zoo and field sources:

- Smithsonian's National Zoo, San Diego Zoo Wildlife Alliance, Animal
  Diversity Web and the Red Panda Network for anatomy and behavior.
- Plocek & Dunham (2023) for the lateral-sequence gait.
- Bugler et al. (2023) for captive activity budgets.

What the panda does with them:

- **Gait:** a low amble on short legs, slower along narrow edges, and the same
  walk, quicker, when chasing or hurrying.
- **Climbing:** short, chunky dark limbs, one arm reaching as the opposite leg
  pushes. The ringed tail swings for balance. Real red pandas come down head
  first, but upside down looked odd on a desktop, so it backs down instead.
- **Pauses:** sniffing, **washing its face** (licks a forepaw, then wipes),
  **nibbling an apple** held in both forepaws, and sudden short bounds.
- **Sleep:** up high it **drapes over a branch or window edge**, legs and tail
  hanging, as red pandas stretch out on branches in warm weather. On the floor
  it sleeps sprawled flat with its tail curled up.
- **Toys:** its ball is an apple, and its treat is the bamboo on your pointer.

The cursor game itself is a playful interpretation of red panda object play,
not observed behavior.

## Naps

Red pandas rest most of the day, and so does this one. After a short spell of
exploring (a minute or two, or a few minutes after you wake it) it gets sleepy
and rests for five to ten minutes. Over a day it's asleep roughly three
quarters of the time. The first rest comes under a minute after launch.

- **Where:** a window's top edge, which it treats as a branch: right where it is
  if it's on one, otherwise up the side of a nearby window. Now and then its
  tree instead. With neither around, it sprawls out on the floor.
- **How:** it walks out along the edge, clear of the corners, yawns and lies
  down belly first. Its chin flops over the edge, all four short legs dangle
  limp in front of the window and its long ringed tail hangs straight down. It
  breathes slowly and little z's drift up from its head.
- **Waking:** a long stretch, a yawn and a quick wash, then off it goes. Waking
  by itself it sometimes comes to find the bamboo on your pointer.
- **Take a nap** (menu or Settings) sends it for a nap now, on a window's top
  or in its tree, and it sleeps until you wake it.

While it naps you can play with it:

- **Hover** over it and it lifts its head and peeks at you.
- **Pet it** (click) and it snuggles in with a happy face and a little heart,
  dozing a little longer.
- **Double-click** it, or choose **Wake**, and it wakes with a stretch, stays up
  a few minutes and comes to play with the bamboo.
- **Pick it up** and it dangles limp, dozing on with its z's. Set it down
  gently (just above a window's top or the branch) and it naps on there; drop
  it from high up and it wakes with a start.
- **Hold the bamboo by its nose** (with Chase the pointer on): after a couple of
  sniffs it wakes up and goes for the snack. A bare pointer only makes it peek.
- **Drag its window gently** and it sleeps on, carried along. A fling, a closed
  window or a window covering it wakes it with a jolt.

It doesn't chase the pointer, chew or start errands while it naps. Bedtime
(quiet hours, or five minutes away) takes over from a nap and sends it to its
tree.

## Mischief

Unprompted every few minutes, it also does one of these:

- **Plays ball.** A ball rolls with friction, falls off edges, bounces off
  windows in front, and rides windows that move. The pet runs after it, jumps
  down (going around a window that's in the way), climbs up to it, and bats it
  three to five times. **Play ball** in the menu or Settings starts a game.
- **Chews a window edge.** On a window's top it lies down and gnaws; climbing
  a window's side it stops, grips and gnaws the side edge. Either way it leaves
  a nibble mark at that spot, on the top or on the side. It often chews right
  after climbing onto a window. Marks are Perch overlay drawings
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

Reduce Motion keeps it still. The
engine only emits requests (`PetEvent.bite`, `.push`); the app decides whether
to act on them.

It also hooks its front paws over a window edge within reach now and then,
gives two pulls and climbs up. **Climb a window** lets you try it on demand,
picking the nearest window it has a way up: within reach it hops up, otherwise
it climbs the side or leaps to hang from the bottom edge and climbs round. With
no such window it says so. **Peek from menu bar** sends it up the nearer side of the screen
and along its top. The window itself never moves.

**Save & wake** saves its name and the settings:

```
~/Library/Application Support/Perch/pet.perchpack
~/Library/Application Support/Perch/preferences.json
```

Preferences hold quiet hours, the tree's display and position, and the
mischief switches. `pet.perchpack` is an internal file holding the name; there
is no import or export. Dragging the tree saves its new place.

Sleep works like this:

- After five minutes of system inactivity, or at quiet hours, the panda naps in
  its tree. Asleep (at bedtime or in a nap) it stays visible, and the SpriteKit
  view draws only four frames a second for its breathing and z's.
- **Tuck away** (⌃⌥⌘B, formerly Send to bed) hides it instead.
- Reduce Motion freezes pose animation and disables wandering.
- All interactions are silent.

**Reset Perch…** removes the saved files and starts again with Maple. A
`care.json` left over from the old food bowl is removed with it.

## No packs

Earlier versions imported and exported `.perchpack` style files and the site
had a pack maker. Both are gone: Perch no longer registers the file type, and
the registered `perch:` URL scheme does not download remote data. The saved
file is still validated (version, rig, colors, finite anchors, timing and
complete 19-action coverage) before it is read.

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
- Polling is 10 Hz normally, 30 Hz while riding, climbing or chasing, 2 Hz while asleep (4 Hz asleep on a
  window, and 30 Hz for a moment after a drag carries it). Motion is
  capped at 30 fps; asleep it draws four frames a second. Locked/inactive/sleeping sessions
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
dist/Perch-0.7.0-universal.zip
dist/Perch-0.7.0-universal.zip.sha256
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
dist/Perch.app/Contents/MacOS/Perch --verify-drag
dist/Perch.app/Contents/MacOS/Perch --verify-pointer
dist/Perch.app/Contents/MacOS/Perch --capture-sprites
dist/Perch.app/Contents/MacOS/Perch --capture-climb-poses
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

- `dist/native-preview.png`: twelve actual poses from the rig used by the
  overlay.
- `dist/native-sprites.png`: all nineteen actions' distinct frames, plus the
  special poses:
  - chew, push and pounce;
  - gnawing a window's side;
  - up and backing down a window's side, hanging under one, and pulling up over
    an edge, all side on;
  - arms-up grab, hanging from the pointer, grooming and apple nibbling;
  - napping draped over an edge and sprawled on the floor, each breathing,
    peeking and snuggling;
  - dozing in your hand, and the leap.
- `dist/native-climb-side.png`, `dist/native-climb-under.png`,
  `dist/climb-evidence.json`: a red panda on an owned window, captured from the
  real SpriteKit overlay. Eight checks:
  - it backs down the window's side upright and side on, facing the window;
  - its paws are on the edge and its body is outside it, by the rendered alpha;
  - the stride frame on screen is the engine's, from how far it has climbed;
  - too high to step off, it swings under and hangs from the bottom edge, side
    on, its forepaws on the edge and nothing above it;
  - it never climbs onto the window's face;
  - it rides the window when it moves.
- `dist/native-climb-poses.png`: every climbing pose's four stride frames and
  still frame, the pull-up, the gnaw, the walk and the leap,
  large, on light and dark desktops, with the window each grips drawn in.
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
  pointer is never moved. It covers sixteen checks:
  - it stalks the pointer's bamboo, crouches, pounces and grabs it, never
    standing up;
  - the bamboo view sits on the pointer tip and never takes clicks;
  - its teeth sit on the stalk's bottom end (within 1.5 pt), and it eats the
    stalk from the bottom up;
  - the overlay stays click-through with the pointer over the pet;
  - it rides a brisk move swinging out behind;
  - a shake drops it;
  - it grabs the window's side while falling past it;
  - it sleeps draped over the edge, with its belly on the edge;
  - asked to nap, it lies down on the window's top with z's over its head and
    the view drawing four frames a second; a click (the real click path)
    makes it snuggle in with a heart, and a double-click wakes it with a
    stretch (`dist/native-nap.png`, `dist/native-nap-snuggle.png`).
- `dist/native-mischief.png`, `dist/mischief-evidence.json`: two owned windows;
  the walk stops at the front window and requests a push, a chew leaves a nibble
  that follows its window, hides behind the front window and goes when its
  window closes, and the ball is drawn in the overlay. Records whether
  Accessibility was granted; it was not on the verification machine, so the
  actual window slide is **unverified**.
- `dist/native-settings.png`, `dist/native-settings-files.png`: the name field
  and scrolled quiet-hours/tree/mischief/reset controls.
- `dist/native-fixture-ride.png`, `dist/native-fixture-fall.png`: owned-window
  checks; `dist/native-spritekit.png`: actual SpriteKit render.
- `dist/native-overlay-ride.png`: the actual SpriteKit overlay after six
  frame/bounds-driven rides, with only our fixture's outline/label added for
  alignment evidence. This is our scene texture, never a desktop screenshot.
- `dist/render-evidence.json`, `dist/fixture-evidence.json`: dimensions,
  sampled-color counts, actual ride/fall outcomes and privacy-safe diagnostics.
- `dist/native-tree-climb.png`, `dist/native-tree-nap.png`,
  `dist/tree-evidence.json`: the tree and the panda's rendered frames at the
  positions used by the overlay. Nine checks:
  - the trunk takes clicks and clicks beside it pass through;
  - dragging moves it;
  - at bedtime the panda climbs the trunk side on and naps draped over the branch,
    belly on the branch within 1 pt;
  - awake, it backs down the trunk;
  - **Go to its tree** sends it back up;
  - tucking it away hides the tree.
- `dist/native-carried-asleep.png`, `dist/drag-evidence.json`: picking up and
  carrying the panda through AppKit's own mouse-event dispatch
  (`--verify-drag`). Synthesized events go only to Perch's panel, which isn't
  key, so every press is a first press; the real pointer is never moved. Nine
  checks:
  - the first press picks it up, a drag carries it, and letting go drops it
    onto the window below;
  - picked up asleep it dozes on in your hand with its z's, and set down
    gently it naps on where it's put;
  - asleep, a click makes it snuggle in and a double-click wakes it;
  - the first press on the tree's trunk drags the tree.
- `dist/pointer-routing-evidence.json`: ten targeted awake/sleeping routing and
  lifecycle checks through the actual monitor callbacks with synthetic owned
  coordinates, including transparent sprite pixels, unchanged local events,
  sleep drawn at four frames a second, no timer/engine/window-list tick, and cleanup. The fixture does
  not move the shared cursor or record private input.

## Pixel art

The red panda is hand-placed **32 × 32** sprites in `Sources/PerchCore/Pixel*.swift`,
and **48 × 48** climbing frames in `PandaClimb.swift`:

- **Views:** front, side, and upside down peeking from the menu bar. The fixed
  parts (front head, sitting body, side head) are character grids.
- **Tails:** drawn as a ringed curve that tapers from base to tip.
- **Climbing:** an articulated figure rasterized straight into the grid: a
  tapered torso along its spine, jointed limbs ending in paws with pale claws,
  the ringed tail and the side-on head. Every climbing pose is side on. Frames
  are drawn about the edge for a window's side (column 24) and about the torso
  hanging under one, with the edge on row 6.
- **Palette:** each pixel names a palette slot. `PixelPalette(pack:)` derives
  hue-shifted ramps from the red panda's three fixed colors. A one-pixel warm plum outline
  goes around the silhouette, softened where it only touches the cream face
  mask.

Every action has up to four distinct frames spread over twelve playback slots
(walk cycle, tail sway, blinks, chewing, breathing, a three-step pull-up).

- **Anchors:** paws rest on row 30. The climb's paws hook over row 13, the hang
  pose holds the pointer at row 14, and the drape's belly rests on row 17,
  with the outline row 18 on the edge.
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
- the walk is on short, stubby legs;
- the colors dress the right parts.

All artifacts are ignored by `native/.gitignore`.

Verified on macOS 26.3 / Swift 6.2.4: **19 focused XCTest cases passed**,
both Mach-O architectures declare macOS 14.0, the ZIP checksum and archive
integrity passed, and the signature is ad-hoc with no Team ID. The owned fixture
rode six real bounds changes (84 points total) with zero paw-alignment error,
then verified fast/minimized/closed-target falls and floor landing. Eight native
PNG captures and JSON counters are persisted in `dist/`. See
`dist/verification.log` for the actual final run rather than inferred results.

The 0.7.0 build passed **91 XCTest cases**. In its signed verification the
tree, dragging, bamboo pointer, cursor and nap checks and the captures passed.
The owned-window ride, mischief, climbing and fall-catch fixtures failed, but
the published 0.6.0 build failed them identically on the same desktop at the
same time, so this was the desktop's state rather than the change; they
weren't re-verified for 0.7.0. The tests cover:

- **Exploring:** climbing only a window's edges, with a return over the top;
  climbing the screen's side, hanging along its top and coming back down;
  gnawing a window's side and leaving a mark there; riding
  and falling off a moved window; holding on through a brisk drag; mid-fall
  window catches.
- **Climbing:** gripping a window's side side on and striding up it to pull
  over the top corner, with every stride frame in order and a surge with each
  pull; backing down a side, its stride reversed, and stepping off; swinging
  under a floating window and going hand over hand along its bottom edge;
  leaping up to hang from one; climbing up beside a tall window instead of
  floating up to it; following a window dragged away mid-errand; coming down
  only from a window's real corner; getting off a floating window to rest
  rather than freezing at a corner; leaping onto a top whose corner is
  covered; no futile leaps at a pointer far across a window; the climbing art
  being side on, right way up and striding, with claws on the edge.
- **The pointer:** a screen-wide chase up a window's side and a leap for the
  pointer; a chase up the screen's edge and a leap; snatching a pointer in
  mid-air; stalk, pounce, grab, ride, shake-off and coming back for more; a
  low pointer gets batted; chases being occasional and never standing up.
- **Bamboo:** eating it from the bottom up and its regrowth.
- **The tree:** bedtime across displays up the trunk to a draped nap and a
  descent; visits; riding the branch while the tree is dragged.
- **Research poses:** grooming, an apple, sleeping draped over a ledge.
- **Realism:** over eight minutes of errands, chases and play it never gets from
  the ground onto a ledge out of reach without climbing; asked to climb a tall
  window it goes up its side; a window floating a little above it is climbed by
  reaching up its side, a higher one by leaping to hang from its bottom edge,
  and one out of reach isn't offered; peeking from a window top or a grip goes
  down and up the screen's edge; with nowhere reachable it still rests on the
  floor; running is the walk, sped up.
- **Naps:** resting most of half an hour, draped over a window's top,
  then a stretch and a wash, and never chasing in its sleep; snuggling when
  petted and waking on a double-click; the bamboo by its nose waking it for a
  snack while a bare pointer only makes it peek; woken by you, staying up and
  coming for the bamboo; carried asleep, dozing on and napping on where it's
  set down, but waking when dropped from high; sleeping through a gentle
  drag but not a fling; a requested nap in the tree lasting until woken, and
  climbing down however a tree nap ends; no fresh nap straight after bedtime;
  the bamboo waking it in about two seconds even at the app's slow sleeping
  tick; a window top or the floor without a tree; breathing, peeking art and
  upright z's.
- **Settings respected:** Reduce Motion and the chase switch.
- **Saved pets:** older saved pets opening as the red panda.

The fixtures cover owned-window rides with zero paw error, falls, alpha routing,
ten pointer checks, nine tree checks, nine mischief checks, eight climbing
checks, sixteen cursor, bamboo and nap checks, and nine dragging checks.

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

An idea for later: more than one red panda, playing with each other. The engine
already keeps each panda's whole state in one `PetEngine` value, so a future
version could run several side by side.
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
