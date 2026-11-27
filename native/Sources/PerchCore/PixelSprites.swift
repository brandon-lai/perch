import Foundation

extension PixelKit {
    // MARK: Pulling up onto a window edge, side on

    func climb(_ frame: Int) -> PixelArt { pullUp(frame) }

    func sleep() -> PixelArt { pandaSleep() }
}

/// Poses outside the pack's nineteen actions: mischief, climbing, cursor play and red panda pauses.
public enum SpecialPose: String, CaseIterable, Sendable {
    case chew, push, pounce
    /// Side on, gripping a window's side edge or the trunk: going up it, and backing down it.
    case scale, scaleDown
    /// Side on, hanging hand over hand from a window's bottom edge.
    case shimmy
    /// Side on to a window's edge, gnawing it.
    case gnaw
    /// Reared up, forepaws high (startled, or swiping at the pointer); and dangling from the pointer.
    case grab, hang
    /// Asleep draped over a window edge or branch; washing its face; nibbling an apple.
    case drape, groom, nibble
    /// Galloping after the pointer, and mid-leap.
    case run, leap
}

public enum PixelSprites {
    public static let side = 32
    /// In the climb pose, the outline row under the hooked paws; its lower edge rests on the ledge.
    public static let climbLedgeRow = 14
    /// In the hang pose, the row with its teeth on the pointer's tip.
    public static let hangGripRow = 14
    /// In the drape pose, the outline row under its belly; its lower edge rests on the window edge.
    public static let drapeLedgeRow = 21

    /// Climbing frames are this many pixels square. Up a side their middle is on the edge; hanging under a
    /// window it's the torso, with the edge `hangEdgeDrop` pixels above it.
    public static let climbSide = PixelKit.climbSize
    public static let hangEdgeRow = PixelKit.hangEdgeRow
    public static let hangEdgeDrop = Double(PixelKit.climbSize) / 2 - PixelKit.hangEdgeRow
    /// In a climbing pose's frames, the one held while it isn't moving (after the four stride frames).
    public static let stillFrame = 4
    /// Pixels of climbing per four-frame stride: each frame stands for a quarter of it, so paws stay planted.
    public static let strideLength = 9.0
    /// Poses played with their stride frames backwards: backing down.
    public static func backsDown(_ pose: SpecialPose) -> Bool { pose == .scaleDown }

    /// Where the head is in a climbing pose, in pixels from the frame's middle (x right, y up), facing right.
    public static func climbHead(_ pose: SpecialPose) -> (x: Double, y: Double)? {
        switch pose {
        case .scale, .scaleDown, .gnaw: return (-5.2, 14.6)
        case .shimmy: return (3.4, 9.8)
        default: return nil
        }
    }

    public struct Animation: Sendable {
        public let frames: [PixelArt]
        /// Twelve playback slots, each an index into `frames`.
        public let slots: [Int]
    }

    public static func animation(_ action: Action) -> Animation {
        let k = PixelKit()
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
        case .ride: return a([k.side(gait: .brace, bodyDY: 1), k.side(gait: .brace, bodyDY: 1, tail: 1)], halves)
        case .held: return a([k.held(0), k.held(1)], [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .react, .pet:
            return a((0..<3).map { f in var g = k.sit(tail: f % 2, eyes: .happy); heart(&g, top: 3 - f); return g },
                     [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2])
        case .climb: return a([k.climb(0), k.climb(1), k.climb(2)], [0, 0, 0, 1, 1, 1, 2, 2, 2, 1, 1, 1])
        // Its meal is held in its forepaws, so feeding is the apple snack.
        case .feed: return special(.nibble)
        case .play: return a((0..<4).map { k.bow(tail: $0 % 2, ball: $0) }, [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3])
        case .sniff:
            return a([k.side(headDY: 4), k.side(headDY: 5, tail: 1)], [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .stretch: return a([k.bow(tail: 0, eyes: .blink), k.bow(tail: 1, eyes: .blink)], halves)
        case .yawn:
            return a([k.sit(eyes: .effort), k.sit(eyes: .effort, mouth: .yawn)], [0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0])
        case .shake:
            return a([k.side(bodyDX: -1, eyes: .blink), k.side(tail: 1, eyes: .blink)], [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
        case .look: return a([k.side(headDY: -1, eyes: .wide), k.side(headDY: -1, tail: 1, eyes: .wide)], halves)
        case .highFive:
            return a([k.sit(eyes: .happy, paw: 0), k.sit(tail: 1, eyes: .happy, paw: 1)], [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1])
        case .peek: return a([k.peek(0), k.peek(1)], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        }
    }

    public static func special(_ pose: SpecialPose) -> Animation {
        let k = PixelKit()
        let pairs = [0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1]
        switch pose {
        case .chew: return Animation(frames: [k.chew(0), k.chew(1)], slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .push: return Animation(frames: [k.push(0), k.push(1)], slots: pairs)
        case .pounce:
            return Animation(frames: [k.bow(tail: 0, eyes: .wide), k.bow(tail: 1, eyes: .wide)], slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .scale, .scaleDown: return stride { k.climbEdge($0) }
        case .shimmy: return stride(k.hangUnder)
        case .gnaw:
            return Animation(frames: [k.climbEdge(nil, eyes: .happy, mouth: .gasp), k.climbEdge(nil, eyes: .happy, mouth: .smile)],
                             slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .grab: return Animation(frames: [k.grab(0), k.grab(1)], slots: pairs)
        case .hang: return Animation(frames: [k.hang(0), k.hang(1)], slots: [0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1])
        case .drape: return Animation(frames: [k.drape()], slots: Array(repeating: 0, count: 12))
        case .groom: return Animation(frames: [k.groom(0), k.groom(1)], slots: [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1])
        case .nibble: return Animation(frames: [k.nibble(0), k.nibble(1)], slots: [0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1])
        case .run: return Animation(frames: (0..<4).map { k.run($0) }, slots: [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3])
        case .leap: return Animation(frames: [k.run(0)], slots: Array(repeating: 0, count: 12))
        }
    }

    /// Four stride frames and the still one. Played by time (in previews), the strides loop once a second.
    private static func stride(_ make: (Int?) -> PixelArt) -> Animation {
        Animation(frames: (0..<4).map { make($0) } + [make(nil)], slots: [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3])
    }

    /// The red panda's toy: an 8 px apple whose stem turns as it rolls; its bottom outline row rests on the surface.
    public static func apple(_ frame: Int) -> PixelArt {
        var g = PixelArt(width: 8, height: 8)
        if frame % 2 == 0 {
            g.spans("A", [2: (2, 5), 3: (1, 6), 4: (1, 6), 5: (1, 6), 6: (2, 5)])
            g.dot("Q", (3, 1)); g.dot("J", (4, 1), (5, 1)); g.dot("O", (2, 3)); g.dot("E", (6, 4), (5, 5), (4, 6))
        } else {
            g.spans("A", [1: (2, 5), 2: (1, 5), 3: (1, 5), 4: (1, 5), 5: (1, 5), 6: (2, 5)])
            g.dot("Q", (6, 3)); g.dot("J", (6, 2)); g.dot("O", (2, 2)); g.dot("E", (5, 5), (4, 6), (3, 6))
        }
        return g
    }

    /// An 8 px ball whose stripe turns as it rolls; its bottom outline row rests on the surface.
    public static func ball(_ frame: Int) -> PixelArt {
        var g = PixelArt(width: 8, height: 8)
        g.spans("B", [1: (2, 5), 2: (1, 6), 3: (1, 6), 4: (1, 6), 5: (1, 6), 6: (2, 5)])
        if frame % 2 == 0 { g.col(3, 1, 6, "W"); g.col(4, 1, 6, "W") } else { g.run(3, 1, 6, "W"); g.run(4, 1, 6, "W") }
        g.dot("C", (2, 2)); g.dot("D", (5, 6), (6, 5))
        return g
    }

    /// A scalloped nibble out of a window's edge. On the top edge row 0 sits on the edge and the teeth marks
    /// point down; on a side it's turned so they point into the window.
    /// Half the bite mark's length along its edge, in art pixels.
    public static let biteMarkHalfLength = 5.5
    public static func biteMark(edge: BiteEdge = .top) -> PixelArt {
        let top = biteMarkTop()
        guard edge != .top else { return top }
        var g = PixelArt(width: top.height, height: top.width)
        for y in 0..<top.height {
            for x in 0..<top.width where top[x, y] != "." {
                g[edge == .left ? y : top.height - 1 - y, x] = top[x, y]
            }
        }
        return g
    }

    private static func biteMarkTop() -> PixelArt {
        var g = PixelArt(width: 11, height: 5)
        g.run(0, 1, 9, "K"); g.run(1, 2, 8, "K"); g.dot("K", (2, 2), (3, 2), (5, 2), (7, 2), (8, 2), (3, 3), (7, 3))
        g.dot("G", (4, 1), (6, 1))
        return g
    }

    public static let toyPalette = PixelPalette(colors: [
        "B": RGB(hex: "#E2654F"), "C": RGB(hex: "#F6B49F"), "D": RGB(hex: "#B8473A"), "W": RGB(hex: "#F3E6D3"),
        "K": RGB(hex: "#2A2E38"), "G": RGB(hex: "#4A5160"),
        "A": appleRed, "E": appleShade, "O": appleShine, "J": leaf, "Q": stem,
    ], outline: RGB(hex: "#4E2620"))
    static let appleRed = RGB(hex: "#D9473B"), appleShade = RGB(hex: "#A8312F"), appleShine = RGB(hex: "#F59A84")
    static let leaf = RGB(hex: "#74B347"), stem = RGB(hex: "#5B3A26")
    /// Light rim so the nibble reads on dark title bars as well as light ones.
    public static let bitePalette = PixelPalette(colors: ["K": RGB(hex: "#2A2E38"), "G": RGB(hex: "#4A5160")],
                                                 outline: RGB(hex: "#E9EEF5"))

    private static func heart(_ g: inout PixelArt, top y: Int) {
        g.dot("H", (25, y), (26, y), (28, y), (29, y))
        g.run(y + 1, 24, 30, "H"); g.run(y + 2, 24, 30, "H"); g.run(y + 3, 25, 29, "H"); g.run(y + 4, 26, 28, "H")
        g.dot("H", (27, y + 5)); g.dot("I", (25, y + 1))
    }
}
