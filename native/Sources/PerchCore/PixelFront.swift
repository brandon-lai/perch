import Foundation

enum Eyes { case open, blink, happy, effort, wide }
enum Mouth { case tongue, smile, yawn, gasp }

/// Hand-placed 32 px red panda poses. Coordinates are top-down; paws rest on row 30 and row 31 holds the outline.
struct PixelKit {
    func sit(tail: Int = 0, eyes: Eyes = .open, mouth: Mouth = .smile, paw: Int? = nil) -> PixelArt {
        pandaSit(tail: tail, eyes: eyes, mouth: mouth, paw: paw)
    }
    func held(_ frame: Int) -> PixelArt { pandaHeld(frame) }
    func peek(_ frame: Int) -> PixelArt { pandaPeek(frame) }
}
