import Foundation

enum Eyes { case open, blink, happy, effort, wide }
enum Mouth { case tongue, smile, yawn, gasp }

/// Hand-placed 32 px parts. Coordinates are top-down; paws rest on row 30 and row 31 holds the outline.
struct PixelKit {
    let cat: Bool
    let pointed: Bool
    var panda = false

    // MARK: Front ears (viewer's left; mirrored for the right)

    func frontEar(back: Bool = false) -> PixelArt {
        if panda { return pandaEar(back: back) }
        var g = PixelArt()
        switch (cat, pointed) {
        case (false, true):
            g.spans("e", [1: (8, 9), 2: (8, 10), 3: (8, 10), 4: (8, 11), 5: (9, 12), 6: (9, 13), 7: (9, 10)])
            g.dot("f", (8, 2), (8, 3), (8, 4), (9, 5))
            g.dot(back ? "e" : "p", (9, 3), (9, 4), (10, 4), (10, 5), (11, 5), (11, 6), (12, 6))
            g.dot("d", (13, 6), (10, 7))
        case (false, false):
            g.spans("e", [6: (10, 13), 7: (8, 14), 8: (7, 12), 9: (6, 10), 10: (6, 9), 11: (6, 9),
                          12: (6, 9), 13: (6, 9), 14: (7, 8)])
            g.run(6, 10, 13, "f"); g.run(7, 9, 13, "f"); g.dot("f", (8, 9), (7, 9))
            g.dot("d", (14, 7), (12, 8), (11, 8), (10, 9), (9, 10), (9, 11), (9, 12), (9, 13), (8, 14), (7, 14), (6, 13))
        case (true, true):
            g.spans("e", [3: (9, 9), 4: (9, 10), 5: (9, 11), 6: (9, 12), 7: (9, 13)])
            g.dot("f", (9, 4), (9, 5), (9, 6))
            g.dot(back ? "e" : "p", (10, 5), (10, 6), (11, 6), (11, 7), (12, 7))
        case (true, false):
            g.spans("e", [5: (10, 12), 6: (9, 13), 7: (9, 13)])
            g.dot("f", (10, 5), (11, 5)); g.dot("d", (12, 7), (13, 7), (13, 6))
        }
        return g
    }

    // MARK: Front head

    func frontHead(eyes: Eyes?, mouth: Mouth) -> PixelArt {
        if panda { return pandaFrontHead(eyes: eyes, mouth: mouth) }
        var g = PixelArt()
        if cat {
            g.spans("c", [8: (10, 21), 9: (9, 22), 10: (8, 23), 11: (8, 23), 12: (8, 23), 13: (8, 23),
                          14: (8, 23), 15: (8, 23), 16: (9, 22), 17: (10, 21), 18: (12, 19)])
            g.run(8, 10, 15, "h"); g.run(9, 9, 12, "h"); g.dot("h", (8, 10), (8, 11))
            g.dot("s", (22, 13), (23, 13), (22, 14), (23, 14), (22, 15), (23, 15), (21, 16), (22, 16),
                  (20, 17), (21, 17), (14, 8), (15, 9), (16, 9), (17, 8))
            g.spans("u", [14: (14, 17), 15: (12, 19), 16: (12, 19), 17: (13, 18), 18: (14, 17)])
            g.dot("U", (12, 16), (19, 16), (13, 17), (18, 17))
            g.dot("p", (15, 14), (16, 14)); g.dot("P", (15, 15))
            switch mouth {
            case .tongue: g.dot("o", (16, 15), (14, 16), (17, 16), (16, 16)); g.dot("p", (15, 16))
            case .smile: g.dot("o", (16, 15), (14, 16), (17, 16), (16, 16))
            case .yawn: g.spans("m", [16: (14, 17), 17: (14, 17)]); g.dot("p", (15, 17), (16, 17))
            case .gasp: g.dot("m", (15, 16), (16, 16))
            }
            g.dot("x", (4, 14), (5, 14), (6, 15), (4, 17), (5, 16), (6, 16),
                  (27, 14), (26, 14), (25, 15), (27, 17), (26, 16), (25, 16))
        } else {
            g.spans("c", [7: (11, 20), 8: (9, 22), 9: (8, 23), 10: (8, 23), 11: (8, 23), 12: (8, 23),
                          13: (8, 23), 14: (8, 23), 15: (9, 22), 16: (9, 22), 17: (10, 21), 18: (12, 19)])
            g.run(7, 11, 20, "h"); g.run(8, 9, 14, "h"); g.run(9, 8, 10, "h"); g.dot("h", (8, 10))
            for y in 11...14 { g.run(y, 22, 23, "s") }
            g.run(15, 21, 22, "s"); g.run(16, 20, 22, "s"); g.run(17, 19, 21, "s")
            g.dot("s", (10, 17), (11, 17), (12, 18), (13, 18), (18, 18), (19, 18))
            for y in 8...11 { g.run(y, 15, 16, "w") }
            g.run(12, 14, 17, "w")
            g.spans("u", [13: (13, 18), 14: (12, 19), 15: (12, 19), 16: (13, 18), 17: (14, 17)])
            g.dot("U", (12, 15), (19, 15), (13, 16), (18, 16), (14, 17), (17, 17))
            g.run(13, 14, 17, "k"); g.run(14, 15, 16, "k"); g.dot("q", (15, 13))
            switch mouth {
            case .tongue:
                g.dot("o", (15, 15), (16, 15), (14, 16), (17, 16)); g.dot("p", (15, 16), (16, 16), (15, 17)); g.dot("P", (16, 17))
            case .smile: g.dot("o", (15, 15), (16, 15), (14, 16), (17, 16))
            case .yawn:
                g.dot("o", (14, 15), (17, 15)); g.dot("m", (15, 15), (16, 15), (14, 16), (15, 16), (16, 16), (17, 16))
                g.dot("p", (15, 17), (16, 17))
            case .gasp: g.dot("m", (15, 16), (16, 16), (15, 17), (16, 17))
            }
        }
        g.dot("r", (10, 14), (21, 14))
        if let eyes { frontEyes(&g, eyes, row: 11) }
        let ear = frontEar()
        g.over(ear); g.over(ear, mirror: true)
        return g
    }

    func frontEyes(_ g: inout PixelArt, _ eyes: Eyes, row y: Int) {
        let iris: Character = cat ? "g" : "j"
        switch eyes {
        case .open:
            for x in [11, 19] {
                g.dot("i", (x, y)); g.dot(iris, (x + 1, y), (x, y + 1)); g.dot("j", (x + 1, y + 1))
            }
        case .blink: g.dot("o", (11, y + 1), (12, y + 1), (19, y + 1), (20, y + 1))
        case .happy: g.dot("o", (10, y + 1), (11, y), (12, y + 1), (19, y + 1), (20, y), (21, y + 1))
        case .effort: g.dot("o", (11, y), (12, y + 1), (11, y + 2), (20, y), (19, y + 1), (20, y + 2))
        case .wide:
            for x in [11, 19] {
                g.run(y, x, x + 1, iris); g.run(y + 1, x, x + 1, iris); g.run(y + 2, x, x + 1, iris)
                g.dot("j", (x + 1, y + 1), (x + 1, y + 2)); g.dot("i", (x, y))
            }
        }
    }

    func collar(_ g: inout PixelArt, y: Int, from x0: Int, to x1: Int, tag: Bool = true) {
        g.run(y, x0, x1, "b"); g.dot("n", (x0, y), (x1 - 1, y), (x1, y))
        if tag { g.dot("y", (15, y + 1), (16, y + 1), (15, y + 2)); g.dot("Y", (16, y + 2)) }
    }

    // MARK: Sitting, facing us

    func sit(tail: Int = 0, eyes: Eyes = .open, mouth: Mouth = .tongue, paw: Int? = nil) -> PixelArt {
        var g = cat ? catSitBody(tail: tail, paw: paw) : dogSitBody(tail: tail, paw: paw)
        g.over(frontHead(eyes: eyes, mouth: mouth))
        if cat { collar(&g, y: 19, from: 12, to: 19) } else { collar(&g, y: 19, from: 11, to: 20) }
        return g
    }

    private func dogSitBody(tail: Int, paw: Int?) -> PixelArt {
        var g = PixelArt()
        g.spans("c", [19: (11, 20), 20: (10, 21), 21: (10, 21), 22: (9, 22), 23: (9, 22), 24: (7, 24),
                      25: (6, 25), 26: (6, 25), 27: (6, 25), 28: (6, 25), 29: (5, 26), 30: (5, 26)])
        g.dot("h", (10, 20), (10, 21), (9, 22), (9, 23), (7, 24), (8, 24), (7, 25), (8, 25), (6, 26))
        g.dot("s", (21, 20), (21, 21), (22, 22), (22, 23), (23, 24), (24, 24), (25, 25), (25, 26), (25, 27))
        g.spans("w", [20: (13, 18), 21: (13, 18), 22: (13, 18), 23: (14, 17), 24: (14, 17)])
        g.dot("v", (18, 21), (18, 22), (17, 23), (17, 24))
        g.col(15, 25, 29, "s"); g.col(16, 25, 29, "s"); g.dot("o", (15, 30), (16, 30))
        g.col(11, 25, 28, "s"); g.col(20, 25, 28, "s")
        let leg: Character = panda ? "1" : "c", legShade: Character = panda ? "2" : "s"
        for y in 25...26 { g.run(y, 12, 13, leg); g.dot(legShade, (14, y)); g.run(y, 17, 18, leg); g.dot(legShade, (19, y)) }
        for y in 27...28 { g.run(y, 12, 13, "1"); g.dot("2", (14, y)); g.run(y, 17, 18, "1"); g.dot("2", (19, y)) }
        for y in 29...30 { g.run(y, 11, 14, "1"); g.run(y, 17, 20, "1"); g.run(y, 5, 9, "1"); g.run(y, 22, 26, "1") }
        g.dot("2", (14, 29), (14, 30), (20, 29), (20, 30), (12, 30), (18, 30), (9, 30), (26, 29), (26, 30), (25, 30))
        g.run(28, 6, 10, "s"); g.run(28, 21, 25, "s")
        g.dot("s", (10, 29), (21, 29)); g.dot("o", (10, 30), (21, 30))
        if panda {
            pandaSitTail(&g, tail: tail)
        } else {
            let lean = tail == 0 ? 0 : 1
            g.dot("c", (26, 27), (27, 26), (27 + lean, 25), (27 + lean, 24))
            g.dot("s", (27, 27), (28, 26), (28 + lean, 25), (28 + lean, 24))
            g.dot("5", (27 + lean, 23), (28 + lean, 23), (27 + lean, 22), (28 + lean, 22))
        }
        if let paw { raisePaw(&g, frame: paw, legX: 17...20, pawX: 21) }
        return g
    }

    private func catSitBody(tail: Int, paw: Int?) -> PixelArt {
        var g = PixelArt()
        g.spans("c", [19: (12, 19), 20: (12, 19), 21: (11, 20), 22: (11, 20), 23: (10, 21), 24: (10, 21),
                      25: (9, 22), 26: (9, 22), 27: (9, 22), 28: (9, 22), 29: (9, 22), 30: (10, 21)])
        g.dot("h", (12, 20), (11, 21), (11, 22), (10, 23), (10, 24), (9, 25), (9, 26))
        g.dot("s", (19, 20), (20, 21), (20, 22), (21, 23), (21, 24), (22, 25), (22, 26), (22, 27), (22, 28))
        g.spans("w", [20: (14, 17), 21: (13, 18), 22: (13, 18), 23: (14, 17), 24: (14, 17), 25: (14, 17)])
        g.dot("v", (18, 22), (17, 23), (17, 24), (17, 25))
        g.col(15, 26, 28, "s"); g.col(16, 26, 28, "s")
        for y in 26...27 { g.run(y, 12, 13, "c"); g.dot("s", (14, y)); g.run(y, 17, 18, "c"); g.dot("s", (19, y)) }
        for y in 28...29 { g.run(y, 12, 14, "1"); g.run(y, 17, 19, "1") }
        g.dot("2", (14, 29), (19, 29)); g.dot("o", (15, 29), (16, 29))
        g.col(11, 26, 29, "s"); g.col(20, 26, 29, "s")
        g.spans("c", [26: (23, 24), 27: (23, 25), 28: (23, 25), 29: (21, 25), 30: (9, 24)])
        g.run(30, 9, 24, "s"); g.dot("h", (24, 26)); g.dot("s", (25, 28), (25, 29))
        g.run(30, 9, 11, "5"); g.dot("5", (8, 30), (8, 29))
        if tail == 1 { g.dot("5", (7, 28), (8, 28)) }
        if let paw { raisePaw(&g, frame: paw, legX: 17...19, pawX: 22) }
        return g
    }

    /// Lifts the viewer-right front paw for a high five, pads toward us.
    private func raisePaw(_ g: inout PixelArt, frame: Int, legX: ClosedRange<Int>, pawX: Int) {
        for y in 25...30 { for x in legX where g[x, y] != "." { g[x, y] = "s" } }
        let r0 = (cat ? 17 : 16) - frame
        g.spans("c", [r0 + 3: (pawX, pawX + 2), r0 + 4: (pawX - 1, pawX + 1), r0 + 5: (pawX - 2, pawX)])
        g.dot("s", (pawX + 2, r0 + 3), (pawX + 1, r0 + 4), (pawX, r0 + 5))
        for y in r0...(r0 + 2) { g.run(y, pawX, pawX + 3, "1") }
        g.dot("2", (pawX + 3, r0 + 2)); g.dot("P", (pawX + 1, r0 + 1), (pawX + 2, r0 + 1), (pawX + 1, r0 + 2), (pawX + 2, r0 + 2))
        g.dot("p", (pawX, r0), (pawX + 3, r0))
    }

    // MARK: Dangling while carried

    func held(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.spans("c", [19: (11, 20), 20: (10, 21), 21: (10, 21), 22: (10, 21), 23: (11, 20), 24: (11, 20),
                      25: (12, 19), 26: (12, 19)])
        g.dot("h", (10, 20), (10, 21), (10, 22), (11, 23))
        g.dot("s", (21, 20), (21, 21), (21, 22), (20, 23), (20, 24), (19, 25), (19, 26), (12, 26), (13, 26))
        g.spans("w", [20: (13, 18), 21: (13, 18), 22: (14, 17), 23: (14, 17)])
        g.dot("v", (18, 21), (17, 22), (17, 23))
        g.dot("c", (9, 20), (9, 21), (22, 20), (22, 21)); g.dot("s", (22, 21))
        g.spans("1", [22: (8, 10), 23: (8, 10)]); g.spans("1", [22: (21, 23), 23: (21, 23)])
        g.dot("2", (10, 23), (23, 23), (23, 22))
        g.spans("c", [26: (12, 13), 27: (12, 13), 28: (12, 13)]); g.spans("1", [29: (11, 13), 30: (11, 13)])
        g.dot("s", (13, 27), (13, 28)); g.dot("2", (13, 30))
        if frame == 0 {
            g.spans("c", [26: (18, 19), 27: (18, 19), 28: (18, 19)]); g.spans("1", [29: (18, 20), 30: (18, 20)])
            g.dot("s", (19, 27), (19, 28)); g.dot("2", (20, 30))
        } else {
            g.spans("c", [26: (18, 19), 27: (19, 20)]); g.spans("1", [28: (19, 21), 29: (19, 21)])
            g.dot("s", (20, 27)); g.dot("2", (21, 29))
        }
        g.dot("c", (15, 27), (16, 27), (15, 28)); g.dot("s", (16, 28)); g.dot("5", (15, 29), (16, 29))
        g.over(frontHead(eyes: .wide, mouth: .gasp))
        collar(&g, y: 19, from: 11, to: 20)
        return g
    }

    // MARK: Peeking down from the menu bar, upside down

    func peek(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.over(frontHead(eyes: nil, mouth: .tongue), flip: true, dy: -11)
        frontEyes(&g, frame == 0 ? .open : .blink, row: 8)
        var paw = PixelArt()
        paw.spans("1", [1: (4, 7), 2: (4, 7)]); paw.dot("2", (5, 2), (7, 2))
        paw.spans("c", [3: (6, 8), 4: (7, 8)]); paw.dot("s", (8, 3))
        g.over(paw); g.over(paw, mirror: true)
        return g
    }
}
