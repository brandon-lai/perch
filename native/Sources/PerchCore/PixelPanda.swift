import Foundation

extension PixelArt {
    /// Paints rows of palette slots starting at column `x`; "." leaves the pixel as it was.
    mutating func paint(_ rows: [Int: String], x: Int = 0, dy: Int = 0) {
        for (y, row) in rows {
            for (i, ch) in row.enumerated() where ch != "." { self[x + i, y + dy] = ch }
        }
    }
    /// Paints sixteen-pixel left halves with their mirror images, for symmetric front views.
    mutating func paintMirrored(_ halves: [Int: String], dy: Int = 0) {
        for (y, half) in halves { paint([y: half + String(half.reversed())], dy: dy) }
    }
    mutating func fill(_ mask: [Int: (Int, Int)], _ ch: Character, dx: Int = 0, dy: Int = 0) {
        for (y, span) in mask { run(y + dy, span.0 + dx, span.1 + dx, ch) }
    }
}

/// The red panda, drawn after the owner's references: a big round head with cream-rimmed ears and dark
/// insides, white brow dots, white cheeks and muzzle split by rust tear-lines, a dark brown chest and legs,
/// and a long tail in alternating orange and rust rings. Slots: c/h/s coat, u/U face mask, f ear rim,
/// 1/2/z legs and chest, T rings and tear-lines, j/i eyes, k nose.
enum PandaArt {
    /// Front head, left halves: ears from row 2, chin on row 17. Eyes sit at x 10–11 and 20–21, rows 10–11.
    static let frontHead: [Int: String] = [
        2: ".......ff.......",
        3: "......f22e......",
        4: ".....f222ee.....",
        5: ".....f222eehhhhh",
        6: ".....f22eehhhhhh",
        7: ".....fecchhhhhhh",
        8: ".....ccchhuuhhhh",
        9: "....ccchhhhhhhhh",
        10: "....cccccccccccc",
        11: "....uccccccccccc",
        12: "....uuuuucTuuuuu",
        13: "....uuuuucTuuukk",
        14: "....uuuuuucTuuuk",
        15: ".....uuuuucTuuuu",
        16: "......UUuuucTuuu",
        17: "........UUUUUUUU",
    ]
    /// Sitting body under the front head, left halves: orange shoulders and flanks, dark chest, forelegs and feet.
    static let sitBody: [Int: String] = [
        18: "........cs111111",
        19: ".......ccs111111",
        20: "......hccs111111",
        21: "......hcc1211111",
        22: ".....hccc1211111",
        23: ".....hcc11211111",
        24: ".....hcc11211111",
        25: ".....ccc11211111",
        26: ".....cc111211111",
        27: ".....cs111211111",
        28: ".....s1111111112",
        29: "....11111..11112",
        30: "....1112...1112.",
    ]
    /// Side head facing right, painted from x 16: one big ear, brow dot, cheek patch, tear-line, muzzle and nose.
    static let sideHead: [Int: String] = [
        3: "...ff...........",
        4: "..f22e..........",
        5: "..f222e.........",
        6: "..f22ehhhhh.....",
        7: ".cf2ehhhhhhhh...",
        8: ".ccchhhhhuuhhc..",
        9: "cccccchhhhhhhcc.",
        10: "ccccccccccccccc.",
        11: "ccccccuuTcccuuk.",
        12: "cccccuuuuTuuuuk.",
        13: "ccccuuuuuTuuuuu.",
        14: ".cccUuuuucTuuu..",
        15: "..ccUUuuuu11....",
        16: "...ccUUU111.....",
        17: "....1111........",
    ]
    /// The side tail's centreline, base to tip: back and up from the rump, curling at the end.
    static let tailCurve: [(Double, Double)] = [(10.5, 17.5), (7, 16), (4.6, 14), (3, 11.4), (2.6, 8.8), (3.4, 6.6)]
    static let torso: [Int: (Int, Int)] = [14: (11, 19), 15: (9, 21), 16: (9, 22), 17: (9, 22), 18: (8, 22), 19: (8, 22),
                                           20: (8, 22), 21: (8, 22), 22: (9, 22), 23: (10, 21), 24: (11, 20)]
}

extension PixelKit {
    // MARK: Front view

    func pandaFrontEyes(_ g: inout PixelArt, _ eyes: Eyes, row y: Int) {
        for x in [10, 20] {
            switch eyes {
            case .open: g.spans("j", [y: (x, x + 1), y + 1: (x, x + 1)]); g.dot("i", (x, y))
            case .blink: g.dot("o", (x, y + 1), (x + 1, y + 1))
            case .happy: g.dot("o", (x, y), (x + 1, y), (x - 1, y + 1), (x + 2, y + 1))
            case .wide: g.spans("j", [y - 1: (x, x + 1), y: (x, x + 1), y + 1: (x, x + 1)]); g.dot("i", (x, y - 1))
            case .effort:
                let a = x == 10 ? x : x + 1, b = x == 10 ? x + 1 : x
                g.dot("o", (a, y), (b, y + 1), (a, y + 2))
            }
        }
    }

    func pandaFrontHead(eyes: Eyes?, mouth: Mouth) -> PixelArt {
        var g = PixelArt()
        g.paintMirrored(PandaArt.frontHead)
        if let eyes { pandaFrontEyes(&g, eyes, row: 10) }
        switch mouth {
        case .tongue: g.dot("o", (14, 15), (17, 15)); g.dot("p", (16, 16))
        case .smile: g.dot("o", (14, 15), (17, 15))
        case .yawn: g.spans("m", [15: (14, 17), 16: (14, 17)]); g.dot("p", (15, 16), (16, 16))
        case .gasp: g.spans("m", [15: (15, 16), 16: (15, 16)])
        }
        return g
    }

    func pandaSit(tail: Int, eyes: Eyes, mouth: Mouth, paw: Int?) -> PixelArt {
        var g = PixelArt()
        g.paintMirrored(PandaArt.sitBody)
        pandaSitTail(&g, tail: tail)
        g.over(pandaFrontHead(eyes: eyes, mouth: mouth))
        if let paw {
            // The viewer-right forepaw raised high beside its head for a high five.
            let up = paw
            g.spans("1", [20: (20, 22), 19: (21, 23), 18: (22, 24), 17: (23, 25), 16: (24, 26), 15: (25, 27)])
            g.spans("1", [14 - up: (26, 28), 13 - up: (26, 29), 12 - up: (26, 29), 11 - up: (26, 29), 10 - up: (27, 29)])
            if up == 1 { g.run(14, 26, 28, "1") }
            g.dot("2", (23, 19), (24, 18), (25, 17), (26, 16), (27, 15), (29, 12 - up), (29, 13 - up))
        }
        return g
    }

    /// Curled around the right side while sitting, in rings.
    func pandaSitTail(_ g: inout PixelArt, tail: Int) {
        let k = tail == 0 ? 0 : 1
        let mask: [Int: (Int, Int)] = [30: (18, 27), 29: (22, 28), 28: (24, 29), 27: (25, 29), 26: (25, 29), 25: (25, 29),
                                       24: (25 + k, 28 + k), 23: (24 + k, 28 + k), 22: (24 + k, 28 + k), 21: (25 + k, 27 + k)]
        for (y, span) in mask {
            for x in span.0...span.1 where g[x, y] == "." || y >= 29 { g[x, y] = [28, 25, 22].contains(y) ? "T" : "c" }
        }
        g.dot("h", (25, 27), (25 + k, 24), (25 + k, 21))
    }

    // MARK: Side view, facing right

    func pandaSideHead(eyes: Eyes, mouth: Mouth) -> PixelArt {
        var g = PixelArt()
        g.paint(PandaArt.sideHead, x: 16)
        switch eyes {
        case .open: g.spans("j", [10: (25, 26), 11: (25, 26)]); g.dot("i", (25, 10))
        case .blink, .effort: g.dot("o", (25, 11), (26, 11))
        case .happy: g.dot("o", (24, 11), (25, 10), (26, 10), (27, 11))
        case .wide: g.spans("j", [9: (25, 26), 10: (25, 26), 11: (25, 26)]); g.dot("i", (25, 9))
        }
        switch mouth {
        case .tongue: g.dot("o", (28, 14), (29, 14)); g.dot("p", (28, 15))
        case .smile: g.dot("o", (28, 14), (29, 14))
        case .yawn, .gasp: g.dot("m", (28, 14), (29, 14), (28, 15))
        }
        return g
    }

    /// The long tail sweeping back and up from the rump, then curling at the tip, as in the owner's walking
    /// reference. The tip sways up a pixel on the second frame.
    func pandaSideTail(_ g: inout PixelArt, tail: Int) {
        let sway = tail == 0 ? 0.0 : 1.0
        let curve = PandaArt.tailCurve.enumerated().map { i, p in (p.0, p.1 - (i >= 3 ? sway * Double(i - 2) * 0.5 : 0)) }
        pandaTail(&g, along: curve, base: 3.3, tip: 2.1)
    }

    /// A thick ringed tail along a curve from its base (first point) to its tip, tapering from `base` to `tip`
    /// pixels of radius; rings alternate every 2.3 px along it, ending in a dark tip. Light catches the top of
    /// each column of fur, or the left of each row for a tail hanging straight down or up.
    func pandaTail(_ g: inout PixelArt, along points: [(Double, Double)], base r0: Double, tip r1: Double,
                   lightFromLeft: Bool = false) {
        var lengths = [0.0]
        for i in 1..<points.count {
            lengths.append(lengths[i - 1] + hypot(points[i].0 - points[i - 1].0, points[i].1 - points[i - 1].1))
        }
        let total = lengths.last ?? 1
        let xs = points.map(\.0), ys = points.map(\.1)
        let x0 = max(1, Int((xs.min() ?? 0) - r0 - 1)), x1 = min(g.width - 2, Int((xs.max() ?? 0) + r0 + 1))
        let y0 = max(1, Int((ys.min() ?? 0) - r0 - 1)), y1 = min(g.height - 2, Int((ys.max() ?? 0) + r0 + 1))
        var mine: [(Int, Int)] = []
        for y in y0...y1 {
            for x in x0...x1 {
                var best = (d: Double.infinity, s: 0.0)
                for i in 0..<(points.count - 1) {
                    let (ax, ay) = points[i], (bx, by) = points[i + 1], vx = bx - ax, vy = by - ay, l2 = vx * vx + vy * vy
                    let t = max(0, min(1, ((Double(x) + 0.5 - ax) * vx + (Double(y) + 0.5 - ay) * vy) / l2))
                    let d = hypot(Double(x) + 0.5 - (ax + t * vx), Double(y) + 0.5 - (ay + t * vy))
                    if d < best.d { best = (d, lengths[i] + t * l2.squareRoot()) }
                }
                guard best.d <= r0 + (r1 - r0) * best.s / total else { continue }
                g[x, y] = Int((total - best.s) / 2.3) % 2 == 0 ? "T" : "c"
                mine.append((x, y))
            }
        }
        if lightFromLeft {
            for y in y0...y1 {
                if let left = mine.filter({ $0.1 == y }).map(\.0).min(), g[left, y] == "c" { g[left, y] = "h" }
            }
        } else {
            for x in x0...x1 {
                if let top = mine.filter({ $0.0 == x }).map(\.1).min(), g[x, top] == "c" { g[x, top] = "h" }
            }
        }
    }

    /// Low, long body: orange back with a peach highlight, dark brown chest and belly.
    func pandaSideBody(tail: Int) -> PixelArt {
        var g = PixelArt()
        pandaSideTail(&g, tail: tail)
        for (y, span) in PandaArt.torso {
            for x in span.0...span.1 {
                var ch: Character = y <= 15 || (y == 16 && x < 18) ? "h" : y == 21 ? "s" : y >= 22 ? (y < 24 ? "1" : "2") : "c"
                if x >= 19 && y >= 17 { ch = x < 22 ? "1" : "2" }
                g[x, y] = ch
            }
        }
        return g
    }

    /// Walking and standing, on short, stubby legs. The head rides lower than a dog's, as red pandas carry it.
    func pandaSide(gait: Gait, headDY: Int, bodyDY low: Int, headDX: Int, tail: Int, eyes: Eyes, mouth: Mouth) -> PixelArt {
        var g = PixelArt()
        let bodyDY = low + 1
        leg(&g, rootX: 16, top: 23 + bodyDY, width: 2, offset: gait.farFront, near: false)
        leg(&g, rootX: 12, top: 23 + bodyDY, width: 2, offset: gait.farHind, near: false)
        g.over(pandaSideBody(tail: tail), dy: bodyDY)
        leg(&g, rootX: 9, top: 24 + bodyDY, width: 3, offset: gait.nearHind, near: true)
        leg(&g, rootX: 18, top: 23 + bodyDY, width: 3, offset: gait.nearFront, near: true)
        g.over(pandaSideHead(eyes: eyes, mouth: mouth), dx: max(headDX, -1), dy: bodyDY + headDY + 2)
        return g
    }

    // MARK: Carried, peeking, asleep

    func pandaHeld(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.paintMirrored([
            18: ".........cc11111", 19: "........ccc11111", 20: "......11cc111111", 21: ".....111cc111111",
            22: ".....11.cc111111", 23: ".....11.cc111111", 24: "......1.cc111111", 25: ".........c111111",
            26: "..........111111",
        ])
        let kick = frame == 0 ? 0 : 1
        g.spans("1", [27: (10, 12), 28: (10, 12), 29: (10, 12), 30: (10, 12)])
        g.spans("1", [27 - kick: (19, 21), 28 - kick: (19, 21), 29 - kick: (19, 21), 30 - kick: (19, 21)])
        g.dot("2", (12, 30), (21, 30 - kick))
        for y in 26...30 { g.run(y, 14, 17, y % 2 == 0 ? "T" : "c") }
        g.over(pandaFrontHead(eyes: .wide, mouth: .gasp))
        return g
    }

    /// Upside down from the menu bar: forepaws hooked over the top, face peering down.
    func pandaPeek(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.over(pandaFrontHead(eyes: nil, mouth: .smile), flip: true, dy: -11)
        pandaFrontEyes(&g, frame == 0 ? .open : .blink, row: 9)
        var paw = PixelArt()
        paw.spans("1", [1: (4, 7), 2: (4, 7), 3: (6, 8)]); paw.dot("2", (5, 2), (7, 2))
        g.over(paw); g.over(paw, mirror: true)
        return g
    }

    /// Sprawled belly down, legs stretched out flat and the big tail curled up behind: warm-weather sleep.
    func pandaSleep() -> PixelArt {
        var g = PixelArt()
        let tail: [Int: (Int, Int)] = [9: (6, 10), 10: (4, 11), 11: (3, 12), 12: (2, 12), 13: (2, 12), 14: (2, 12), 15: (2, 12),
                                       16: (2, 12), 17: (3, 12), 18: (3, 12), 19: (4, 12), 20: (5, 12), 21: (6, 12)]
        for (y, span) in tail { g.run(y, span.0, span.1, [10, 11, 14, 15, 18, 19].contains(y) ? "T" : "c") }
        g.dot("h", (7, 9), (8, 9), (2, 12), (2, 16), (3, 17), (4, 20))
        g.spans("1", [25: (3, 9), 26: (1, 8), 27: (1, 6)]); g.dot("2", (1, 27), (2, 27))
        let body: [Int: (Int, Int)] = [19: (9, 20), 20: (6, 22), 21: (5, 23), 22: (4, 23), 23: (4, 23), 24: (4, 23), 25: (5, 23), 26: (6, 22)]
        for (y, span) in body { g.run(y, span.0, span.1, y <= 20 ? "h" : y <= 23 ? "c" : y == 24 ? "s" : "1") }
        g.spans("1", [27: (16, 24), 28: (17, 28), 29: (20, 30)]); g.dot("2", (30, 29), (28, 28))
        g.over(pandaSideHead(eyes: .blink, mouth: .smile), dy: 12)
        g.spans("1", [29: (10, 19), 30: (11, 20)]); g.dot("2", (20, 30))
        return g
    }

    // MARK: Running

    /// A low, four-beat gallop on short, stubby legs, all four of them always in view: reaching out, front paws
    /// striking, gathered under, then hind legs pushing off, with the ringed tail streaming behind. Frame 0 is
    /// also its mid-leap pose.
    func run(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let k = frame % 4
        let dy = [1, 1, 0, 1][k]
        // Paw offsets from each leg's root, forward positive: near front, far front, near hind, far hind.
        let paws = [(3, 2, -3, -2), (0, 1, -1, 0), (-2, -1, 2, 2), (2, 3, 0, -1)][k]
        let wave = [0.0, -0.5, -1.0, -0.5][k]
        leg(&g, rootX: 18, top: 25 + dy, width: 2, offset: paws.1, near: false)
        leg(&g, rootX: 12, top: 25 + dy, width: 2, offset: paws.3, near: false)
        pandaTail(&g, along: [(10.5, 17.5 + Double(dy)), (7, 16.2 + Double(dy) + wave * 0.5),
                              (4.4, 14.2 + Double(dy) + wave), (3.0, 11.4 + Double(dy) + wave)], base: 3.2, tip: 2.3)
        var torso: [Int: (Int, Int)] = [:]
        for (y, span) in PandaArt.torso { torso[y + dy] = span }
        paintTorso(&g, torso)
        leg(&g, rootX: 9, top: 25 + dy, width: 3, offset: paws.2, near: true)
        leg(&g, rootX: 18, top: 25 + dy, width: 3, offset: paws.0, near: true)
        g.over(pandaSideHead(eyes: .open, mouth: .smile), dy: dy + 3)
        return g
    }

    /// Fills a side torso: peach back, orange flank, rust shadow, dark chest and belly.
    func paintTorso(_ g: inout PixelArt, _ mask: [Int: (Int, Int)]) {
        let top = mask.keys.min() ?? 0, bottom = mask.keys.max() ?? 0
        for (y, span) in mask {
            for x in span.0...span.1 {
                var ch: Character = y <= top + 1 ? "h" : y >= bottom - 1 ? "1" : y == bottom - 2 ? "s" : "c"
                if x >= span.1 - 3 && y >= top + 3 { ch = x == span.1 ? "2" : "1" }
                g[x, y] = ch
            }
        }
    }

    // MARK: Cursor play and research-based pauses

    /// Up on its hind legs with forepaws high and spread: the startle stance, and a swipe at the pointer.
    func grab(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        var tail = PixelArt()
        pandaSitTail(&tail, tail: frame)
        g.over(tail)
        g.paintMirrored([
            19: "..........111111", 20: ".........1111111", 21: ".........cc11111", 22: ".........cc11111",
            23: ".........cc11111", 24: ".........cc11111", 25: "..........c11111", 26: "..........111111",
            27: "..........111...", 28: "..........111...", 29: ".........1111...", 30: ".........1112...",
        ])
        g.over(pandaFrontHead(eyes: .wide, mouth: .gasp), dy: 2)
        // Arms straight up past its ears, paws open with pale claws, like the owner's arms-up reference.
        var arm = PixelArt()
        arm.spans("1", [21: (6, 9), 20: (5, 8), 19: (4, 7), 18: (3, 6), 17: (3, 5), 16: (2, 5), 15: (2, 5), 14: (2, 5),
                        13: (2, 5), 12: (2, 5), 11: (2, 5), 10: (2, 5), 9: (2, 5), 8: (1, 5), 7: (1, 5), 6: (1, 5), 5: (2, 4)])
        arm.dot("2", (7, 20), (6, 19), (5, 18), (5, 17), (5, 16), (5, 15), (5, 13), (5, 11))
        arm.dot("V", (2, 4), (4, 4), (1, 5)); arm.dot("1", (3, 4))
        g.over(arm, dy: -frame + 1); g.over(arm, mirror: true, dy: frame)
        return g
    }

    /// Dangling from the pointer (or the bamboo on it): teeth on it, forepaws gripping either side, legs kicking.
    func hang(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let s = frame
        g.spans("c", [20: (8, 10), 21: (7, 10), 22: (6, 9), 23: (6, 9), 24: (5, 9), 25: (5, 8),
                      26: (5 + s, 8 + s), 27: (5 + s, 8 + s), 28: (6 + s, 8 + s), 29: (6 + s, 7 + s)])
        g.run(22, 6, 9, "T"); g.run(23, 6, 9, "T"); g.run(26, 5 + s, 8 + s, "T"); g.run(27, 5 + s, 8 + s, "T")
        g.run(29, 6 + s, 7 + s, "T"); g.dot("h", (8, 20), (5, 24))
        let a = frame, b = 1 - frame
        for y in 23...(27 + a) { g.run(y, 12, 14, "1") }
        g.run(28 + a, 11, 14, "1"); g.dot("2", (14, 24), (14, 25), (11, 28 + a))
        for y in 23...(27 + b) { g.run(y, 17, 19, "1") }
        g.run(28 + b, 17, 20, "1"); g.dot("2", (19, 24), (19, 25), (20, 28 + b))
        g.spans("1", [16: (11, 20), 17: (10, 21), 18: (10, 21), 19: (10, 21), 20: (10, 21), 21: (10, 21),
                      22: (11, 20), 23: (12, 19), 24: (13, 18)])
        g.spans("c", [17: (10, 11), 18: (10, 11), 19: (10, 10)]); g.spans("c", [17: (20, 21), 18: (20, 21), 19: (21, 21)])
        g.over(pandaFrontHead(eyes: .happy, mouth: .smile), dy: -1)
        g.spans("m", frame == 0 ? [14: (15, 16), 15: (15, 16)] : [14: (15, 16)])
        // Forepaws up on either side of its mouth, gripping.
        var arm = PixelArt()
        arm.spans("1", [12: (11, 12), 13: (10, 12), 14: (10, 12), 15: (10, 12), 16: (10, 12), 17: (10, 11)])
        arm.dot("2", (12, 14), (12, 15))
        g.over(arm); g.over(arm, mirror: true)
        return g
    }

    /// Asleep stretched along a window's top edge, legs and tail hanging limp in front of it.
    func drape() -> PixelArt {
        var g = PixelArt()
        let tail: [Int: (Int, Int)] = [16: (4, 7), 17: (3, 7), 18: (3, 7), 19: (2, 6), 20: (2, 6), 21: (2, 6), 22: (2, 6),
                                       23: (2, 6), 24: (2, 6), 25: (2, 6), 26: (3, 6), 27: (3, 5)]
        for (y, span) in tail { g.run(y, span.0, span.1, [19, 20, 23, 24, 27].contains(y) ? "T" : "c") }
        g.dot("h", (4, 16), (3, 17), (2, 21), (2, 22), (2, 25))
        g.spans("z", [21: (11, 12), 22: (11, 12), 23: (11, 12), 24: (11, 12), 25: (11, 13)])
        g.spans("z", [21: (22, 23), 22: (22, 23), 23: (22, 23), 24: (22, 23), 25: (22, 24)])
        g.spans("1", [21: (8, 10), 22: (8, 10), 23: (8, 10), 24: (8, 10), 25: (8, 10), 26: (8, 11), 27: (9, 11)])
        g.spans("1", [21: (18, 20), 22: (18, 20), 23: (18, 20), 24: (18, 20), 25: (18, 20), 26: (18, 21), 27: (19, 21)])
        g.dot("2", (10, 23), (10, 24), (11, 27), (20, 23), (20, 24), (21, 27))
        g.spans("c", [14: (10, 18), 15: (8, 20), 16: (6, 22), 17: (5, 23), 18: (5, 23), 19: (5, 23), 20: (6, 22)])
        g.run(14, 10, 17, "h"); g.run(15, 8, 13, "h"); g.dot("h", (6, 16), (7, 16)); g.run(20, 7, 21, "s")
        g.over(pandaSideHead(eyes: .blink, mouth: .smile), dy: 5)
        return g
    }

    /// Washing up after a nap or a meal: lick a forepaw, then wipe it over the face.
    func groom(_ frame: Int) -> PixelArt {
        var g = pandaSit(tail: frame, eyes: .blink, mouth: frame == 0 ? .tongue : .smile, paw: nil)
        for y in 21...27 { g.run(y, 20, 21, "1") }
        if frame == 0 {
            g.spans("1", [15: (16, 19), 16: (16, 20), 17: (17, 21), 18: (18, 21), 19: (19, 21), 20: (19, 21)])
            g.dot("2", (20, 16), (21, 18), (21, 20))
        } else {
            g.spans("1", [9: (19, 22), 10: (19, 23), 11: (20, 23), 12: (21, 23), 13: (21, 23), 14: (21, 23),
                          15: (21, 23), 16: (21, 23), 17: (20, 22), 18: (20, 22), 19: (19, 21), 20: (19, 21)])
            g.dot("2", (23, 11), (23, 13), (23, 15), (22, 18))
        }
        return g
    }

    /// A snack held in both forepaws: an apple, a zoo favourite. Lowered, then lifted for a bite.
    func nibble(_ frame: Int) -> PixelArt {
        var g = pandaSit(tail: frame, eyes: frame == 0 ? .happy : .blink, mouth: .smile, paw: nil)
        let top = frame == 0 ? 18 : 15
        apple(&g, x: 13, y: top, bitten: frame == 1)
        for x0 in [11, 19] {
            g.spans("1", [top + 2: (x0, x0 + 1), top + 3: (x0, x0 + 1), top + 4: (x0, x0 + 1)])
            for y in (top + 5)...25 { g.run(y, x0, x0 + 1, "1") }
        }
        g.dot("2", (12, top + 4), (20, top + 4))
        return g
    }

    /// Six pixels of apple with a stem and leaf; a bite shows its cream flesh.
    func apple(_ g: inout PixelArt, x: Int, y: Int, bitten: Bool = false) {
        g.dot("Q", (x + 2, y)); g.dot("J", (x + 3, y), (x + 4, y))
        g.spans("A", [y + 1: (x + 1, x + 4), y + 2: (x, x + 5), y + 3: (x, x + 5), y + 4: (x, x + 5), y + 5: (x + 1, x + 4)])
        g.dot("O", (x + 1, y + 2)); g.dot("E", (x + 5, y + 4), (x + 4, y + 5), (x + 3, y + 5))
        if bitten { g.dot("u", (x + 4, y + 1), (x + 5, y + 2)); g.dot("U", (x + 5, y + 3)) }
    }
}
