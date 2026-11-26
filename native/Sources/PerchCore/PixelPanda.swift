import Foundation

/// Red panda parts: white face mask and ear rims, dark legs and chest, a big ringed tail ("T" marks the rings).
extension PixelKit {
    func pandaEar(back: Bool) -> PixelArt {
        var g = PixelArt()
        g.spans("e", [3: (9, 11), 4: (8, 12), 5: (8, 12), 6: (8, 12), 7: (9, 12)])
        g.dot("f", (9, 3), (10, 3), (11, 3), (8, 4), (8, 5), (8, 6))
        g.dot(back ? "d" : "p", (10, 5), (11, 5), (10, 6), (11, 6))
        g.dot("d", (12, 4), (12, 7))
        return g
    }

    func pandaFrontHead(eyes: Eyes?, mouth: Mouth) -> PixelArt {
        var g = PixelArt()
        g.spans("c", [8: (11, 20), 9: (9, 22), 10: (8, 23), 11: (8, 23), 12: (8, 23), 13: (8, 23),
                      14: (8, 23), 15: (8, 23), 16: (9, 22), 17: (10, 21), 18: (12, 19)])
        g.run(8, 11, 20, "h"); g.run(9, 9, 14, "h"); g.dot("h", (8, 10), (8, 11))
        g.dot("s", (23, 11), (23, 12), (22, 16), (21, 17), (12, 18), (19, 18))
        g.run(10, 10, 12, "u"); g.run(10, 19, 21, "u")
        g.spans("u", [13: (8, 10), 14: (8, 11), 15: (8, 11), 16: (9, 11)])
        g.spans("u", [13: (21, 23), 14: (20, 23), 15: (20, 23), 16: (20, 22)])
        g.spans("u", [14: (13, 18), 15: (13, 18), 16: (13, 18), 17: (14, 17)])
        g.dot("U", (9, 16), (22, 16), (13, 16), (18, 16), (14, 17), (17, 17))
        g.dot("T", (12, 13), (12, 14), (19, 13), (19, 14))
        g.run(18, 13, 18, "1")
        g.run(14, 15, 16, "k"); g.dot("k", (15, 15), (16, 15)); g.dot("q", (15, 14))
        switch mouth {
        case .tongue: g.dot("o", (14, 16), (17, 16)); g.dot("p", (15, 16), (16, 16)); g.dot("P", (16, 17))
        case .smile: g.dot("o", (14, 16), (15, 16), (16, 16), (17, 16))
        case .yawn: g.spans("m", [16: (14, 17), 17: (14, 17)]); g.dot("p", (15, 17), (16, 17))
        case .gasp: g.dot("m", (15, 16), (16, 16), (15, 17), (16, 17))
        }
        if let eyes { frontEyes(&g, eyes, row: 11) }
        let ear = pandaEar(back: false)
        g.over(ear); g.over(ear, mirror: true)
        return g
    }

    func pandaSideHead(eyes: Eyes, mouth: Mouth, earsUp: Bool, collar showCollar: Bool) -> PixelArt {
        var g = PixelArt()
        g.spans("d", [5: (17, 18), 6: (16, 18), 7: (17, 18)]); g.dot("f", (17, 5), (16, 6))
        g.spans("c", [8: (19, 24), 9: (18, 25), 10: (17, 26), 11: (17, 26), 12: (17, 27), 13: (17, 28),
                      14: (17, 28), 15: (18, 27), 16: (19, 25), 17: (20, 23)])
        g.run(8, 19, 24, "h"); g.run(9, 18, 22, "h"); g.dot("h", (17, 10), (17, 11))
        g.dot("s", (18, 15), (19, 16), (17, 14))
        g.run(9, 23, 24, "u")
        g.spans("u", [13: (24, 27), 14: (23, 28), 15: (24, 27), 16: (24, 25)]); g.dot("U", (24, 15), (24, 16))
        g.dot("T", (22, 13), (22, 14))
        g.run(17, 20, 23, "1")
        g.dot("k", (28, 13), (27, 13)); g.dot("q", (27, 13))
        switch mouth {
        case .tongue: g.dot("o", (26, 15)); g.dot("p", (27, 16))
        case .smile: g.dot("o", (26, 15))
        case .yawn, .gasp: g.dot("m", (26, 15), (27, 15))
        }
        switch eyes {
        case .open: g.dot("i", (23, 11)); g.dot("j", (24, 11), (23, 12), (24, 12))
        case .blink, .effort: g.dot("o", (23, 12), (24, 12))
        case .happy: g.dot("o", (22, 12), (23, 11), (24, 12))
        case .wide: g.spans("j", [10: (23, 24), 11: (23, 24), 12: (23, 24)]); g.dot("i", (23, 10))
        }
        let lift = earsUp ? -1 : 0
        var ear = PixelArt()
        ear.spans("e", [4: (20, 22), 5: (19, 23), 6: (19, 23), 7: (20, 23)])
        ear.dot("f", (20, 4), (21, 4), (22, 4), (19, 5), (19, 6)); ear.dot("p", (21, 6), (22, 6))
        g.over(ear, dy: lift)
        if showCollar {
            g.dot("b", (19, 18), (20, 18), (21, 18), (22, 18), (20, 19)); g.dot("n", (19, 19), (21, 19))
            g.dot("y", (22, 19)); g.dot("Y", (22, 20))
        }
        return g
    }

    /// Long and bushy, held low behind while walking.
    func pandaSideTail(_ g: inout PixelArt, tail: Int) {
        // Starts at x 2 so a one-pixel shake still leaves room for the outline.
        let k = tail == 0 ? 0 : 1
        g.spans("c", [16: (5, 7), 17: (4, 7), 18: (3, 7), 19: (2, 6), 20: (2, 6)])
        g.spans("c", [21: (2 + k, 5 + k), 22: (2 + k, 5 + k), 23: (2 + k, 5 + k), 24: (3 + k, 4 + k)])
        g.dot("h", (5, 16), (4, 17), (3, 18))
        g.run(19, 2, 6, "T"); g.run(22, 2 + k, 5 + k, "T"); g.run(24, 3 + k, 4 + k, "T")
    }

    /// Curled up the right side while sitting.
    func pandaSitTail(_ g: inout PixelArt, tail: Int) {
        let k = tail == 0 ? 0 : 1
        g.spans("c", [27: (25, 28), 26: (26, 29), 25: (26, 29), 24: (26, 29)])
        g.spans("c", [23: (26 + k, 29 + k), 22: (26 + k, 29 + k), 21: (25 + k, 28 + k), 20: (25 + k, 28 + k), 19: (26 + k, 27 + k)])
        g.dot("h", (26, 26), (26, 24), (26 + k, 23), (25 + k, 21))
        g.run(25, 26, 29, "T"); g.run(22, 26 + k, 29 + k, "T"); g.run(19, 26 + k, 27 + k, "T")
    }

    // MARK: Gripping a window face: back to us, face turned toward us, chunky limbs splayed

    /// Back, limbs and tail without the head. One arm reaches high while the opposite leg pushes,
    /// so alternating frames read as a lateral-sequence climb; the tail tip swings for balance.
    private func crawlBody(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        var limbs = PixelArt()
        limbs.spans("1", [17: (9, 11), 16: (8, 11), 15: (7, 10), 14: (6, 9), 13: (5, 8), 12: (4, 8), 11: (3, 7), 10: (3, 6)])
        limbs.dot("2", (11, 16), (10, 15), (9, 14), (8, 13), (8, 12), (7, 11))
        limbs.spans("1", [17: (20, 22), 16: (21, 24), 15: (22, 26), 14: (24, 27), 13: (25, 28), 12: (25, 28)])
        limbs.dot("2", (22, 17), (24, 16), (26, 15), (27, 14), (28, 13))
        limbs.spans("1", [22: (9, 11), 23: (7, 10), 24: (5, 9), 25: (4, 8), 26: (4, 7)])
        limbs.dot("2", (10, 23), (9, 24), (8, 25), (7, 26))
        limbs.spans("1", [23: (20, 22), 24: (21, 23), 25: (21, 24), 26: (22, 24), 27: (22, 25), 28: (23, 26), 29: (23, 26)])
        limbs.dot("2", (22, 24), (24, 25), (24, 26), (25, 27), (26, 28), (26, 29))
        g.over(limbs, mirror: frame == 1)
        // Tail hanging below, ringed, its tip swinging out to one side and then the other.
        let sway = frame == 0 ? [0, 0, -1, -1, -2, -2, -2] : [0, 0, 1, 1, 2, 2, 2]
        for (i, y) in (24...29).enumerated() { g.run(y, 14 + sway[i], 17 + sway[i], y % 2 == 1 ? "T" : "c") }
        g.run(30, 15 + sway[6], 16 + sway[6], "T")
        for (i, y) in (26...28).enumerated() where y % 2 == 0 { g.dot("h", (14 + sway[i + 2], y)) }
        g.spans("c", [14: (12, 19), 15: (11, 20), 16: (10, 21), 17: (10, 21), 18: (10, 21), 19: (10, 21),
                      20: (10, 21), 21: (10, 21), 22: (10, 21), 23: (11, 20), 24: (11, 20), 25: (12, 19)])
        g.dot("h", (10, 16), (10, 17), (10, 18), (10, 19), (11, 15), (11, 20), (15, 18), (15, 19), (16, 20))
        g.dot("s", (21, 17), (21, 18), (21, 19), (21, 20), (21, 21), (20, 23), (20, 24), (19, 25), (12, 25), (13, 25))
        return g
    }

    func crawl(_ frame: Int) -> PixelArt {
        var g = crawlBody(frame)
        g.over(pandaFrontHead(eyes: .open, mouth: .smile), dy: -2)
        collar(&g, y: 17, from: 11, to: 20, tag: false)
        return g
    }

    /// Coming down head first, gripping with the hind claws: the climb turned over, face upside down.
    func descend(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.over(crawlBody(frame), flip: true)
        g.over(pandaFrontHead(eyes: nil, mouth: .smile), flip: true, dy: 2)
        frontEyes(&g, .open, row: 21)
        return g
    }

    // MARK: Cursor play and research-based pauses

    /// Up on its hind legs with forepaws high and spread: the startle stance, and a swipe at the pointer.
    func grab(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        var tail = PixelArt()
        pandaSitTail(&tail, tail: frame)
        g.over(tail, dy: 3)
        g.spans("c", [19: (11, 20), 20: (10, 21), 21: (10, 21), 22: (10, 21), 23: (10, 21), 24: (10, 21),
                      25: (10, 21), 26: (11, 20), 27: (11, 20)])
        g.dot("h", (10, 21), (10, 22), (10, 23), (11, 26))
        g.dot("s", (21, 21), (21, 22), (21, 23), (21, 24), (20, 26), (20, 27))
        g.spans("w", [21: (13, 18), 22: (13, 18), 23: (13, 18), 24: (13, 18), 25: (14, 17), 26: (14, 17)])
        g.dot("v", (18, 22), (18, 23), (17, 25))
        g.spans("1", [27: (11, 13), 28: (11, 13), 29: (10, 13), 30: (10, 14)])
        g.spans("1", [27: (18, 20), 28: (18, 20), 29: (18, 21), 30: (17, 21)])
        g.dot("2", (13, 27), (13, 28), (14, 30), (20, 27), (20, 28), (21, 29), (21, 30))
        var arm = PixelArt()
        arm.spans("1", [20: (8, 10), 19: (7, 9), 18: (6, 8), 17: (5, 8), 16: (4, 7), 15: (4, 7), 14: (3, 6),
                        13: (3, 6), 12: (2, 6), 11: (2, 6), 10: (3, 5)])
        arm.dot("2", (8, 18), (8, 17), (7, 16), (7, 15), (6, 14), (6, 13), (6, 12))
        g.over(arm, dy: -frame); g.over(arm, mirror: true, dy: frame - 1)
        g.over(pandaFrontHead(eyes: .wide, mouth: .gasp), dy: 2)
        collar(&g, y: 21, from: 11, to: 20, tag: false)
        return g
    }

    /// Dangling from the pointer: teeth on its tip, forepaws hugging it, legs kicking and tail swinging.
    func hang(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let s = frame
        g.spans("c", [21: (9, 11), 22: (8, 11), 23: (7, 10), 24: (7, 10), 25: (6, 10), 26: (6, 9),
                      27: (6 + s, 9 + s), 28: (6 + s, 9 + s), 29: (7 + s, 9 + s), 30: (7 + s, 8 + s)])
        g.run(24, 7, 10, "T"); g.run(27, 6 + s, 9 + s, "T"); g.run(30, 7 + s, 8 + s, "T"); g.dot("h", (7, 25), (6, 26))
        let a = frame, b = 1 - frame
        for y in 23...(27 + a) { g.run(y, 12, 14, "1") }
        g.run(28 + a, 11, 14, "1"); g.dot("2", (14, 24), (14, 25), (11, 28 + a))
        for y in 23...(27 + b) { g.run(y, 17, 19, "1") }
        g.run(28 + b, 17, 20, "1"); g.dot("2", (19, 24), (19, 25), (20, 28 + b))
        g.spans("c", [16: (12, 19), 17: (11, 20), 18: (11, 20), 19: (11, 20), 20: (11, 20), 21: (11, 20),
                      22: (11, 20), 23: (12, 19), 24: (13, 18), 25: (14, 17)])
        g.dot("h", (11, 18), (11, 19), (11, 20), (12, 22), (14, 19), (15, 20), (14, 21))
        g.dot("s", (20, 18), (20, 19), (20, 20), (20, 21), (19, 23), (18, 24), (17, 25))
        g.over(pandaFrontHead(eyes: .happy, mouth: frame == 0 ? .gasp : .smile), dy: -2)
        // Forepaws hugging up under the chin, around the pointer.
        var arm = PixelArt()
        arm.spans("1", [21: (8, 10), 20: (8, 10), 19: (9, 11), 18: (10, 12), 17: (11, 13), 16: (12, 14)])
        arm.dot("2", (10, 21), (10, 20), (11, 19), (12, 18), (13, 17))
        g.over(arm); g.over(arm, mirror: true)
        return g
    }

    /// Asleep stretched along a window's top edge, legs and tail hanging limp in front of it.
    func drape() -> PixelArt {
        var g = PixelArt()
        g.spans("c", [17: (4, 7), 18: (3, 7), 19: (3, 6), 20: (3, 6), 21: (3, 6), 22: (3, 6), 23: (3, 6),
                      24: (3, 6), 25: (3, 6), 26: (3, 6), 27: (4, 6), 28: (4, 5)])
        g.run(20, 3, 6, "T"); g.run(23, 3, 6, "T"); g.run(26, 3, 6, "T"); g.dot("T", (4, 28), (5, 28))
        g.dot("h", (3, 18), (3, 19), (3, 21), (3, 22))
        g.spans("z", [21: (11, 12), 22: (11, 12), 23: (11, 12), 24: (11, 12), 25: (11, 13)])
        g.spans("z", [21: (22, 23), 22: (22, 23), 23: (22, 23), 24: (22, 23), 25: (22, 24)])
        g.spans("1", [21: (8, 10), 22: (8, 10), 23: (8, 10), 24: (8, 10), 25: (8, 10), 26: (8, 11), 27: (9, 11)])
        g.spans("1", [21: (18, 20), 22: (18, 20), 23: (18, 20), 24: (18, 20), 25: (18, 20), 26: (18, 21), 27: (19, 21)])
        g.dot("2", (10, 23), (10, 24), (11, 27), (20, 23), (20, 24), (21, 27))
        g.spans("c", [14: (10, 18), 15: (8, 20), 16: (6, 22), 17: (5, 23), 18: (5, 23), 19: (5, 23), 20: (6, 22)])
        g.run(14, 10, 17, "h"); g.run(15, 8, 13, "h"); g.dot("h", (6, 16), (7, 16)); g.run(20, 7, 21, "s")
        g.over(pandaSideHead(eyes: .blink, mouth: .smile, earsUp: false, collar: false), dy: 5)
        return g
    }

    /// Washing up after a nap or a meal: lick a forepaw, then wipe it over the face.
    func groom(_ frame: Int) -> PixelArt {
        var g = sit(tail: frame, eyes: .blink, mouth: frame == 0 ? .tongue : .smile)
        for y in 25...30 { for x in 17...20 where g[x, y] == "1" || g[x, y] == "2" { g[x, y] = "s" } }
        if frame == 0 {
            g.spans("1", [16: (17, 20), 17: (17, 20), 18: (18, 20), 19: (18, 20), 20: (18, 20), 21: (18, 20)])
            g.dot("2", (20, 17), (20, 19), (20, 21))
        } else {
            g.spans("1", [11: (19, 22), 12: (19, 22), 13: (19, 22), 14: (20, 22), 15: (20, 22), 16: (20, 22),
                          17: (19, 21), 18: (19, 21), 19: (18, 20), 20: (18, 20), 21: (18, 20)])
            g.dot("2", (22, 13), (22, 15), (21, 18), (20, 20))
        }
        return g
    }

    /// A snack held in both forepaws: an apple, a zoo favourite. Lowered, then lifted for a bite.
    func nibble(_ frame: Int) -> PixelArt {
        var g = sit(tail: frame, eyes: frame == 0 ? .happy : .blink, mouth: .smile)
        for y in 25...30 {
            for x in Array(12...14) + Array(17...19) where g[x, y] == "1" || g[x, y] == "2" { g[x, y] = "s" }
        }
        let top = frame == 0 ? 18 : 16
        apple(&g, x: 13, y: top, bitten: frame == 1)
        for (x0, x1) in [(11, 13), (18, 20)] {
            g.spans("1", [top + 2: (x0, x1), top + 3: (x0, x1), top + 4: (x0, x1)])
            for y in (top + 5)...24 { g.run(y, x0 == 11 ? 11 : 19, x0 == 11 ? 12 : 20, "1") }
        }
        g.dot("2", (13, top + 4), (20, top + 4))
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
