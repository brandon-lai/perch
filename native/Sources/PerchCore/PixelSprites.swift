import Foundation

extension PixelKit {
    // MARK: Pulling up onto a window edge, seen from behind

    func climb(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        var legs = PixelArt()
        legs.spans("c", [25: (19, 21), 26: (19, 21), 27: (19, 21)])
        legs.spans("1", [28: (18, 22), 29: (18, 22), 30: (18, 22)])
        legs.dot("s", (21, 25), (21, 26), (21, 27)); legs.dot("2", (22, 30))
        legs.dot("p", (18, 28), (20, 28), (22, 28)); legs.dot("P", (19, 29), (20, 29), (21, 29), (20, 30))
        legs.spans("c", [24: (9, 12), 25: (8, 11)]); legs.spans("1", [26: (6, 10), 27: (6, 10)])
        legs.dot("s", (11, 25)); legs.dot("2", (10, 26), (10, 27))
        legs.dot("p", (6, 26), (6, 27)); legs.dot("P", (7, 26), (8, 26), (7, 27), (8, 27), (9, 27))
        var lower = PixelArt()
        lower.over(legs, mirror: frame == 1)
        for y in 16...23 { lower.run(y, 10, 21, "c") }
        lower.spans("c", [24: (11, 20), 25: (12, 19)])
        lower.run(16, 10, 21, "s"); lower.run(17, 12, 19, "s")
        lower.dot("h", (10, 18), (10, 19), (10, 20), (11, 18), (14, 19), (15, 20), (15, 21))
        lower.dot("s", (21, 18), (21, 19), (21, 20), (21, 21), (21, 22), (21, 23), (20, 24), (19, 25),
                  (12, 25), (13, 25), (15, 24), (16, 24), (16, 23))
        if cat {
            lower.spans("c", [24: (21, 22), 23: (22, 23), 22: (23, 24), 21: (24, 25), 20: (24, 25), 19: (24, 25)])
            lower.dot("s", (22, 24), (23, 23), (24, 22)); lower.dot("5", (25, 18), (26, 18), (25, 17))
        } else {
            lower.spans("c", [24: (21, 22), 23: (22, 23), 22: (23, 24), 21: (24, 25)])
            lower.dot("s", (22, 24), (23, 23), (24, 22)); lower.dot("5", (25, 20), (26, 20), (26, 19), (25, 21))
        }
        g.over(lower, dy: -frame)
        var arm = PixelArt()
        arm.spans("c", [14: (6, 8), 15: (7, 9), 16: (8, 10)]); arm.spans("1", [12: (4, 8), 13: (4, 8)])
        arm.dot("2", (5, 13), (7, 13)); arm.dot("h", (7, 15), (8, 16))
        g.over(arm); g.over(arm, mirror: true, remap: ["h": "s"])
        g.spans("c", [6: (12, 19), 7: (10, 21), 8: (9, 22), 9: (8, 23), 10: (8, 23), 11: (8, 23),
                      12: (8, 23), 13: (8, 23), 14: (9, 22), 15: (11, 20)])
        g.run(6, 12, 19, "h"); g.run(7, 10, 16, "h"); g.run(8, 9, 13, "h"); g.dot("h", (8, 9), (8, 10))
        for y in 10...13 { g.run(y, 22, 23, "s") }
        g.run(14, 19, 22, "s"); g.dot("s", (9, 14), (10, 14))
        let ear = frontEar(back: true)
        let lift = !cat && !pointed ? -1 : 0
        g.over(ear, dy: lift); g.over(ear, mirror: true, dy: lift)
        g.run(15, 11, 20, "b"); g.dot("n", (11, 15), (19, 15), (20, 15))
        return g
    }

    // MARK: Curled up nose to tail

    func sleep() -> PixelArt {
        var g = PixelArt()
        g.spans("c", [18: (10, 19), 19: (8, 21), 20: (6, 23), 21: (5, 24), 22: (4, 25), 23: (3, 26),
                      24: (3, 26), 25: (3, 26), 26: (3, 26), 27: (3, 26), 28: (4, 26)])
        g.run(18, 10, 19, "h"); g.run(19, 8, 15, "h"); g.run(20, 6, 11, "h"); g.run(21, 5, 7, "h")
        g.dot("h", (4, 22), (4, 23)); g.run(28, 4, 26, "s"); g.dot("s", (3, 27))
        g.dot("s", (10, 22), (11, 22), (12, 22), (9, 23), (13, 23), (8, 24), (14, 24), (8, 25), (14, 25))
        g.dot("h", (10, 23), (11, 23), (9, 24))
        if pointed { g.spans("d", [16: (20, 20), 17: (20, 21), 18: (20, 22)]) }
        g.spans("c", [19: (19, 25), 20: (18, 26), 21: (17, 27), 22: (17, 28), 23: (17, 28), 24: (17, 28),
                      25: (17, 28), 26: (18, 27)])
        g.run(19, 19, 25, "h"); g.run(20, 18, 21, "h")
        if cat {
            g.spans("u", [23: (25, 28), 24: (25, 28), 25: (25, 27)]); g.dot("U", (25, 25)); g.dot("p", (28, 23))
        } else {
            g.dot("w", (26, 20), (27, 21), (26, 21))
            g.spans("u", [22: (26, 29), 23: (25, 30), 24: (25, 30), 25: (25, 29), 26: (25, 28)])
            g.dot("U", (25, 25), (25, 26), (28, 26), (29, 25))
            g.dot("k", (29, 22), (30, 23), (30, 22)); g.dot("q", (29, 22))
        }
        g.dot("o", (22, 22), (23, 23), (24, 23), (25, 22)); g.dot("r", (24, 25))
        switch (cat, pointed) {
        case (false, false):
            g.spans("e", [19: (18, 21), 20: (17, 21), 21: (17, 21), 22: (17, 21), 23: (17, 20), 24: (18, 20), 25: (18, 19)])
            g.run(19, 18, 20, "f"); g.run(20, 18, 20, "f")
            g.dot("d", (21, 21), (21, 22), (20, 23), (20, 24), (19, 25), (18, 25), (17, 23))
        case (_, true):
            g.spans("e", [16: (18, 19), 17: (18, 21), 18: (19, 22)]); g.dot("f", (18, 16), (18, 17))
            g.dot(cat ? "p" : "d", (20, 18), (21, 18))
        case (true, false):
            g.spans("e", [18: (19, 22), 17: (20, 21)]); g.dot("f", (20, 17))
        }
        g.spans("1", [27: (21, 25), 28: (20, 25)]); g.dot("2", (25, 27), (25, 28), (22, 28))
        g.spans("1", [27: (17, 19), 28: (16, 19)]); g.dot("2", (19, 27), (19, 28))
        g.run(29, cat ? 5 : 6, 25, "c"); g.run(29, 8, 15, "h"); g.run(30, cat ? 6 : 7, 24, "s")
        g.dot("5", (26, 29), (27, 29), (27, 28), (28, 28), (26, 30))
        return g
    }
}

/// Poses outside the pack's nineteen actions: eating at the home bowl and the mischief tricks.
public enum SpecialPose: String, CaseIterable, Sendable { case dine, chew, push, pounce }

public enum PixelSprites {
    public static let side = 32
    /// In the climb pose, the outline row under the hooked paws; its lower edge rests on the ledge.
    public static let climbLedgeRow = 14

    public struct Animation: Sendable {
        public let frames: [PixelArt]
        /// Twelve playback slots, each an index into `frames`.
        public let slots: [Int]
    }

    public static func animation(_ action: Action, species: Species, ears: Ears, atDish: Bool = false) -> Animation {
        let k = PixelKit(cat: species == .cat, pointed: ears == .pointed)
        func a(_ frames: [PixelArt], _ slots: [Int]) -> Animation { Animation(frames: frames, slots: slots) }
        let halves = [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]
        switch action {
        case .idle:
            return a([k.side(), k.side(tail: 1), k.side(tail: 1, eyes: .blink)], [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2])
        case .walk:
            let stride = Gait(nearFront: 2, nearHind: -2, farFront: -1, farHind: 1)
            let back = Gait(nearFront: -2, nearHind: 2, farFront: 1, farHind: -1)
            return a([k.side(gait: stride), k.side(bodyDY: -1, tail: 1), k.side(gait: back), k.side(bodyDY: -1, tail: 1)],
                     [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3])
        case .sit:
            return a([k.sit(), k.sit(tail: 1), k.sit(tail: 1, eyes: .blink)], [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2])
        case .sleep: return a([k.sleep()], Array(repeating: 0, count: 12))
        case .fall: return a([k.fall(0), k.fall(1)], [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .ride: return a([k.side(gait: .brace, bodyDY: 1, mouth: .smile), k.side(gait: .brace, bodyDY: 1, tail: 1, mouth: .smile)], halves)
        case .held: return a([k.held(0), k.held(1)], [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .react, .pet:
            return a((0..<3).map { f in var g = k.sit(tail: f % 2, eyes: .happy); heart(&g, top: 3 - f); return g },
                     [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2])
        case .climb: return a([k.climb(0), k.climb(1), k.climb(2)], [0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 1])
        case .feed: return a([k.eat(0, bowl: !atDish), k.eat(1, bowl: !atDish)], [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .play: return a((0..<4).map { k.bow(tail: $0 % 2, ball: $0) }, [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3])
        case .sniff:
            return a([k.side(headDY: 4, mouth: .smile), k.side(headDY: 5, tail: 1, mouth: .smile)], [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .stretch: return a([k.bow(tail: 0, eyes: .blink), k.bow(tail: 1, eyes: .blink)], halves)
        case .yawn:
            return a([k.sit(eyes: .effort, mouth: .smile), k.sit(eyes: .effort, mouth: .yawn)], [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0])
        case .shake:
            return a([k.side(bodyDX: -1, eyes: .blink, mouth: .smile, earsUp: true), k.side(tail: 1, eyes: .blink, mouth: .smile)],
                     [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
        case .look: return a([k.side(headDY: -1, eyes: .wide), k.side(headDY: -1, tail: 1, eyes: .wide)], halves)
        case .highFive:
            return a([k.sit(eyes: .happy, paw: 0), k.sit(tail: 1, eyes: .happy, paw: 1)], [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .peek: return a([k.peek(0), k.peek(1)], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        }
    }

    public static func special(_ pose: SpecialPose, species: Species, ears: Ears) -> Animation {
        let k = PixelKit(cat: species == .cat, pointed: ears == .pointed)
        switch pose {
        case .dine: return animation(.feed, species: species, ears: ears, atDish: true)
        case .chew: return Animation(frames: [k.chew(0), k.chew(1)], slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .push: return Animation(frames: [k.push(0), k.push(1)], slots: [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .pounce:
            return Animation(frames: [k.bow(tail: 0, eyes: .wide), k.bow(tail: 1, eyes: .wide)], slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        }
    }

    /// An 8 px ball whose stripe turns as it rolls; its bottom outline row rests on the surface.
    public static func ball(_ frame: Int) -> PixelArt {
        var g = PixelArt(width: 8, height: 8)
        g.spans("B", [1: (2, 5), 2: (1, 6), 3: (1, 6), 4: (1, 6), 5: (1, 6), 6: (2, 5)])
        if frame % 2 == 0 { g.col(3, 1, 6, "W"); g.col(4, 1, 6, "W") } else { g.run(3, 1, 6, "W"); g.run(4, 1, 6, "W") }
        g.dot("C", (2, 2)); g.dot("D", (5, 6), (6, 5))
        return g
    }

    /// A scalloped nibble out of a window's top edge. Row 0 sits on the edge; teeth marks point down.
    public static func biteMark() -> PixelArt {
        var g = PixelArt(width: 11, height: 5)
        g.run(0, 1, 9, "K"); g.run(1, 2, 8, "K"); g.dot("K", (2, 2), (3, 2), (5, 2), (7, 2), (8, 2), (3, 3), (7, 3))
        g.dot("G", (4, 1), (6, 1))
        return g
    }

    public static let toyPalette = PixelPalette(colors: [
        "B": RGB(hex: "#E2654F"), "C": RGB(hex: "#F6B49F"), "D": RGB(hex: "#B8473A"), "W": RGB(hex: "#F3E6D3"),
        "K": RGB(hex: "#2A2E38"), "G": RGB(hex: "#4A5160"),
    ], outline: RGB(hex: "#4E2620"))
    /// Light rim so the nibble reads on dark title bars as well as light ones.
    public static let bitePalette = PixelPalette(colors: ["K": RGB(hex: "#2A2E38"), "G": RGB(hex: "#4A5160")],
                                                 outline: RGB(hex: "#E9EEF5"))

    private static func heart(_ g: inout PixelArt, top y: Int) {
        g.dot("H", (25, y), (26, y), (28, y), (29, y))
        g.run(y + 1, 24, 30, "H"); g.run(y + 2, 24, 30, "H"); g.run(y + 3, 25, 29, "H"); g.run(y + 4, 26, 28, "H")
        g.dot("H", (27, y + 5)); g.dot("I", (25, y + 1))
    }
}
