import Foundation

/// A bamboo stalk carried on the pointer for a red panda to chase and eat. Its top end sits on the pointer's
/// tip; the panda eats it from the bottom up, and it grows back. Perch makes it the system arrow itself where
/// macOS allows, and otherwise draws it beside the arrow.
public enum Bamboo {
    /// Stalk length in pixels when whole.
    public static let fullLength = 22
    /// Even, so as the system pointer it's a whole number of points at every pet size.
    public static let width = 14, height = 24
    /// Centre of the stalk's three columns (8–10), in pixels from the art's left edge.
    public static let centerX = 9.5

    /// How many stalk pixels are left for a remaining fraction (1 is a whole stalk).
    public static func pixels(remaining: Double) -> Int {
        Int((max(0, min(1, remaining)) * Double(fullLength)).rounded(.up))
    }

    /// The art's bounds in screen points (y up) for a pointer tip, at `scale` points per pixel.
    public static func frame(tip: Point, scale: Double) -> Rect {
        let top = tip.y + 1.5 * scale
        return Rect(tip.x - centerX * scale, top - Double(height) * scale, Double(width) * scale, Double(height) * scale)
    }

    /// The middle of the stalk's bottom pixel row: where a hanging panda's teeth go.
    public static func end(tip: Point, remaining: Double, scale: Double) -> Point {
        Point(tip.x, tip.y + 1.5 * scale - (Double(pixels(remaining: remaining)) + 0.5) * scale)
    }

    /// The stalk, `length` pixels long from its top, with node bands and a leafy sprig on the left
    /// (the pointer's arrow covers its right side).
    public static func art(length: Int) -> PixelArt {
        var g = PixelArt(width: width, height: height)
        let length = max(0, min(fullLength, length))
        guard length > 0 else { return g }
        for y in 1...length { g.dot("M", (8, y)); g.dot("L", (9, y)); g.dot("N", (10, y)) }
        g.dot("R", (8, 1), (10, 1)); g.dot("N", (9, 1))
        for node in [8, 16] where node < length {
            g.run(node, 7, 11, "R")
            g.dot("K", (8, node + 1), (9, node + 1))
        }
        g.dot("N", (8, length)); g.dot("M", (9, length)); g.dot("R", (10, length))
        if length >= 9 {
            g.paint([1: ".JJ.....", 2: "..JJJ...", 3: "...KJJ..", 4: "....JJQ.", 5: "......Q.",
                     6: "...JJ.Q.", 7: ".JJKJJQ.", 8: "..JJ...Q"])
        }
        return g
    }

    public static let palette = PixelPalette(colors: [
        "L": RGB(hex: "#9BE07A"), "M": RGB(hex: "#57AE4E"), "N": RGB(hex: "#2E7446"), "R": RGB(hex: "#1F5236"),
        "K": RGB(hex: "#C8F2A6"), "J": RGB(hex: "#7CC453"), "Q": RGB(hex: "#3F8A3C"),
    ], outline: RGB(hex: "#17261C"))
}
