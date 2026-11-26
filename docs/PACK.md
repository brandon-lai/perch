# Perch pack v1

A `.perchpack` file is UTF-8 JSON, no ZIP, source image, script, remote URL or
executable payload. Maximum size: 256 KiB. Renderers use the shared
`perch-1` procedural 2D rig; the pack is a palette and animation manifest.

Canonical geometry is in `native/Sources/Perch/Rig.swift`, a 160×144 y-up
canvas anchored on the paw line. `site/components/pet-rig.tsx` mirrors that
geometry for the browser and social card. The web preview shows representative
poses and a tail loop, not the full native frame playback engine. Keep both
renderers consistent when changing the versioned rig.

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

Name: 1–40 trimmed characters. Species: dog/cat. All three colors: `#RRGGBB`.
Marking: none/chest/socks/tuxedo. Ears: floppy/pointed. Size:
small/medium/large. Temperament: calm/curious. Remembrance: boolean.
Every animation has finite anchor coordinates in 0…1, frameCount 1…120,
fps 1…30, and loop loop/once/hold. RigVersion and schemaVersion are checked
before import. Unknown animation names and duplicate entries are rejected.

Complete packs declare idle, walk, sit, sleep, fall, ride, held, react, climb,
pet, feed, play, sniff, stretch, yawn, shake, look, highFive, peek.
The nine behavior states from the PRD remain the hub-and-spoke model;
the remaining names are actions/poses within them.
