# Perch pack v1

A `.perchpack` file is UTF-8 JSON, no ZIP, source image, script, remote URL or
executable payload. Maximum size: 256 KiB. Renderers use the shared
`perch-1` rig; the pack is a palette and animation manifest.

The Mac app (0.2.0 and later) draws `perch-1` as 32 × 32 pixel sprites from
`native/Sources/PerchCore/Pixel*.swift`, anchored on the bottom paw row. Species,
ears, the three colors and marking choose the sprite parts and palette; size
picks 2, 3 or 4 points per art pixel. The pack format did not change, so packs
from either renderer still import.

`site/components/pet-rig.tsx` still draws the earlier flat geometry for the
browser builder and social card. It shows the same traits, but not yet the
pixel-art look the Mac app now renders.

```json
{
  "schemaVersion": 1,
  "rigVersion": "perch-1",
  "name": "Milo",
  "species": "dog",
  "coat": "#C58B55",
  "earColor": "#875C43",
  "markingColor": "#F2EDE4",
  "marking": "chest",
  "ears": "floppy",
  "size": "medium",
  "temperament": "curious",
  "remembrance": false,
  "animations": [
    {"name": "idle", "frameCount": 12, "fps": 12, "loop": "loop", "anchor": {"x": 0.5, "y": 0.0}}
  ]
}
```

Name: 1–40 trimmed characters. Species: dog/cat/redPanda. `redPanda` arrived with
the Mac app 0.2.0, and older apps reject it. The red-panda-only Mac app opens dog
and cat packs as a red panda in its own colors, keeping the name, size and
temperament. All three colors: `#RRGGBB`. For a red panda, `coat` is its fur,
`earColor` its legs, chest and inner ears, and `markingColor` its face mask and
ear rims.
Marking: none/chest/socks/tuxedo. Ears: floppy/pointed. Size:
small/medium/large. Temperament: calm/curious. Remembrance: boolean.
Every animation has finite anchor coordinates in 0…1, frameCount 1…120,
fps 1…30, and loop loop/once/hold. RigVersion and schemaVersion are checked
before import. Unknown animation names and duplicate entries are rejected.

Complete packs declare idle, walk, sit, sleep, fall, ride, held, react, climb,
pet, feed, play, sniff, stretch, yawn, shake, look, highFive, peek.
The nine behavior states from the PRD remain the hub-and-spoke model;
the remaining names are actions/poses within them.
