import Foundation

struct Gait {
    var nearFront = 0, nearHind = 0, farFront = 0, farHind = 0
    static let stand = Gait()
    static let brace = Gait(nearFront: 2, nearHind: -2, farFront: 1, farHind: -1)
}

extension PixelKit {
    // MARK: Side view, facing right

    func side(gait: Gait = .stand, headDY: Int = 0, bodyDY: Int = 0, bodyDX: Int = 0, tail: Int = 0,
              eyes: Eyes = .open, mouth: Mouth = .tongue, earsUp: Bool = false) -> PixelArt {
        if panda { return pandaSide(gait: gait, headDY: headDY, bodyDY: bodyDY, headDX: bodyDX, tail: tail, eyes: eyes, mouth: mouth) }
        var g = PixelArt()
        leg(&g, rootX: 15, top: 23 + bodyDY, width: 2, offset: gait.farFront, near: false)
        leg(&g, rootX: 10, top: 23 + bodyDY, width: 2, offset: gait.farHind, near: false)
        g.over(sideBody(tail: tail), dx: bodyDX, dy: bodyDY)
        leg(&g, rootX: 6, top: 24 + bodyDY, width: 3, offset: gait.nearHind, near: true)
        leg(&g, rootX: 18, top: 23 + bodyDY, width: 3, offset: gait.nearFront, near: true)
        g.over(sideHead(eyes: eyes, mouth: mouth, earsUp: earsUp, collar: headDY <= 2), dx: bodyDX, dy: bodyDY + headDY)
        return g
    }

    func leg(_ g: inout PixelArt, rootX: Int, top: Int, width: Int, offset: Int, near: Bool) {
        for y in top...28 {
            let shift = Int((Double(offset) * Double(y - top) / Double(max(1, 28 - top))).rounded())
            let x0 = rootX + shift, sock = near && (y >= 26 || panda)
            g.run(y, x0, x0 + width - 1, near ? (sock ? "1" : "c") : "F")
            if near { g[x0 + width - 1, y] = sock ? "2" : "s" }
        }
        let px = rootX + offset
        for y in 29...30 { g.run(y, px, px + width, near ? "1" : "z") }
        if near { g[px + width, 30] = "2" }
    }

    func sideBody(tail: Int) -> PixelArt {
        if panda { return pandaSideBody(tail: tail) }
        var g = PixelArt()
        sideTail(&g, tail: tail)
        g.spans("c", [16: (10, 19), 17: (8, 20), 18: (7, 22), 19: (6, 22), 20: (6, 22), 21: (6, 21),
                      22: (6, 20), 23: (7, 19), 24: (9, 17)])
        g.run(16, 10, 18, "h"); g.run(17, 8, 13, "h"); g.dot("h", (7, 18))
        g.run(23, 9, 16, "s"); g.run(24, 9, 17, "s"); g.dot("s", (6, 22), (7, 23))
        g.dot("s", (11, 20), (12, 21), (12, 22), (11, 23))
        g.spans("w", [18: (21, 22), 19: (21, 22), 20: (21, 22), 21: (20, 21), 22: (19, 20)])
        g.dot("v", (20, 22), (21, 21))
        return g
    }

    func sideTail(_ g: inout PixelArt, tail: Int) {
        if panda { pandaSideTail(&g, tail: tail); return }
        if cat {
            let lean = tail == 0 ? 0 : -1
            g.spans("c", [18: (5, 6), 17: (4, 5), 16: (3, 4), 15: (3, 4), 14: (3, 4), 13: (3, 4)])
            g.dot("c", (3 + lean, 12), (4 + lean, 12), (4 + lean, 11), (5 + lean, 11))
            g.dot("s", (3, 15), (3, 14), (3, 13), (4, 16), (5, 18))
            g.dot("5", (5 + lean, 10), (6 + lean, 10), (6 + lean, 9), (7 + lean, 9))
        } else {
            let lean = tail == 0 ? 0 : -1
            g.spans("c", [18: (5, 6), 17: (4, 5), 16: (3, 4), 15: (2, 3)])
            g.dot("c", (2 + lean, 14), (3 + lean, 14)); g.dot("s", (5, 18), (4, 17), (3, 16), (2, 15))
            g.dot("5", (2 + lean, 13), (3 + lean, 13), (2 + lean, 12), (3 + lean, 12), (3 + lean, 11))
        }
    }

    func sideHead(eyes: Eyes, mouth: Mouth, earsUp: Bool = false, collar showCollar: Bool = true) -> PixelArt {
        if panda { return pandaSideHead(eyes: eyes, mouth: mouth) }
        var g = PixelArt()
        if pointed {
            if cat { g.spans("d", [4: (18, 18), 5: (17, 18), 6: (17, 19), 7: (17, 19)]) }
            else { g.spans("d", [3: (18, 18), 4: (18, 19), 5: (17, 19), 6: (17, 20)]) }
        }
        let iris: Character = cat ? "g" : "j"
        if cat {
            g.spans("c", [8: (19, 24), 9: (18, 25), 10: (17, 26), 11: (17, 26), 12: (17, 26), 13: (17, 27),
                          14: (17, 27), 15: (18, 26), 16: (19, 25), 17: (20, 23)])
            g.run(8, 19, 24, "h"); g.run(9, 18, 22, "h"); g.dot("h", (17, 10), (17, 11))
            g.dot("s", (18, 15), (19, 16), (20, 17), (25, 16), (26, 15), (20, 9), (21, 10))
            g.spans("u", [13: (25, 27), 14: (25, 27), 15: (25, 26)]); g.dot("U", (25, 15))
            g.dot("p", (27, 13)); g.dot("r", (23, 14))
            switch mouth {
            case .tongue: g.dot("o", (26, 15)); g.dot("p", (26, 16))
            case .smile: g.dot("o", (26, 15))
            case .yawn, .gasp: g.dot("m", (26, 15), (26, 14))
            }
            switch eyes {
            case .open: g.dot("i", (23, 11)); g.dot("j", (24, 11), (24, 12)); g.dot(iris, (23, 12))
            case .blink, .effort: g.dot("o", (23, 12), (24, 12))
            case .happy: g.dot("o", (22, 12), (23, 11), (24, 12))
            case .wide: g.dot(iris, (23, 10), (23, 11), (23, 12)); g.dot("j", (24, 10), (24, 11), (24, 12)); g.dot("i", (23, 10))
            }
            g.dot("x", (29, 13), (30, 12), (29, 15), (30, 16))
        } else {
            g.spans("c", [7: (19, 24), 8: (18, 25), 9: (17, 26), 10: (17, 26), 11: (17, 26), 12: (17, 26),
                          13: (17, 26), 14: (17, 26), 15: (18, 26), 16: (18, 25), 17: (19, 23)])
            g.run(7, 19, 24, "h"); g.run(8, 18, 23, "h"); g.dot("h", (17, 9), (17, 10))
            g.dot("s", (18, 15), (19, 16), (19, 17), (20, 17), (24, 16), (25, 16), (26, 15))
            g.dot("w", (25, 8), (25, 9), (26, 9), (26, 10), (26, 11))
            g.spans("u", [12: (26, 30), 13: (26, 30), 14: (26, 30), 15: (25, 29), 16: (25, 28)])
            g.dot("U", (25, 15), (25, 16), (26, 16), (29, 15))
            g.dot("k", (29, 12), (30, 12), (30, 13)); g.dot("q", (29, 12)); g.dot("r", (24, 13))
            switch mouth {
            case .tongue: g.dot("o", (27, 15), (28, 15)); g.dot("p", (27, 16), (27, 17)); g.dot("P", (28, 16))
            case .smile: g.dot("o", (27, 15), (28, 15))
            case .yawn, .gasp: g.dot("m", (27, 15), (28, 15), (28, 14))
            }
            switch eyes {
            case .open: g.dot("i", (23, 10)); g.dot(iris, (24, 10), (23, 11), (24, 11))
            case .blink, .effort: g.dot("o", (23, 11), (24, 11))
            case .happy: g.dot("o", (22, 11), (23, 10), (24, 11))
            case .wide: g.spans(iris, [9: (23, 24), 10: (23, 24), 11: (23, 24)]); g.dot("i", (23, 9))
            }
        }
        sideEar(&g, flipped: earsUp)
        if showCollar {
            let y = cat ? 18 : 17
            g.dot("b", (19, y), (20, y), (21, y), (22, y), (20, y + 1)); g.dot("n", (19, y + 1), (21, y + 1))
            g.dot("y", (22, y + 1)); g.dot("Y", (22, y + 2))
        }
        return g
    }

    private func sideEar(_ g: inout PixelArt, flipped: Bool) {
        switch (cat, pointed) {
        case (false, true):
            g.spans("e", [2: (21, 21), 3: (21, 22), 4: (20, 22), 5: (20, 23), 6: (20, 23)])
            g.dot("f", (21, 2), (20, 4), (20, 5)); g.dot("p", (22, 4), (22, 5))
        case (false, false) where flipped:
            g.spans("e", [3: (20, 23), 4: (19, 23), 5: (19, 23), 6: (19, 22), 7: (20, 22)])
            g.run(3, 20, 23, "f"); g.dot("d", (19, 6), (20, 7), (22, 7), (23, 5))
        case (false, false):
            g.spans("e", [8: (19, 22), 9: (18, 22), 10: (18, 22), 11: (18, 22), 12: (18, 22), 13: (18, 22),
                          14: (18, 21), 15: (19, 20)])
            g.run(8, 19, 22, "f"); g.run(9, 19, 21, "f")
            g.dot("d", (22, 10), (22, 11), (22, 12), (22, 13), (21, 14), (18, 14), (19, 15), (20, 15))
        case (true, true):
            g.spans("e", [3: (21, 21), 4: (20, 22), 5: (20, 22), 6: (19, 23), 7: (19, 23)])
            g.dot("f", (20, 4), (20, 5), (19, 6)); g.dot("p", (21, 5), (21, 6), (22, 6), (22, 7))
        case (true, false):
            g.spans("e", [6: (20, 22), 7: (19, 23)]); g.dot("e", (22, 8), (23, 8))
            g.run(6, 20, 21, "f"); g.dot("d", (23, 7), (23, 8))
        }
    }

    // MARK: Play bow, used for stretching and playing with a ball

    func bow(tail: Int, eyes: Eyes = .happy, ball: Int? = nil) -> PixelArt {
        var g = PixelArt()
        leg(&g, rootX: 10, top: 21, width: 2, offset: 0, near: false)
        g.spans("F", [28: (14, 16)]); g.run(29, 13, 17, "z"); g.run(30, 13, 17, "z")
        var raisedTail = PixelArt()
        sideTail(&raisedTail, tail: tail)
        g.over(raisedTail, dy: -3)
        g.spans("c", [13: (8, 12), 14: (6, 14), 15: (5, 16), 16: (5, 17), 17: (5, 18), 18: (5, 19), 19: (6, 20),
                      20: (6, 21), 21: (7, 22), 22: (9, 22), 23: (12, 22), 24: (14, 22), 25: (15, 21)])
        g.run(13, 8, 12, "h"); g.run(14, 6, 12, "h"); g.dot("h", (5, 15), (5, 16))
        g.dot("s", (6, 19), (7, 20), (8, 21), (9, 22), (10, 22), (11, 22), (12, 23), (13, 23), (14, 24), (15, 25),
              (16, 25), (17, 25), (18, 25), (19, 25), (20, 25), (21, 25))
        g.spans("w", [20: (21, 22), 21: (21, 22), 22: (20, 22), 23: (20, 22), 24: (19, 21)])
        leg(&g, rootX: 6, top: 21, width: 3, offset: 0, near: true)
        g.spans("c", [26: (17, 19), 27: (17, 19), 28: (17, 20)]); g.dot("s", (19, 26), (19, 27))
        g.run(29, 17, 23, "c"); g.run(30, 17, 23, "s"); g.spans("1", [29: (24, 27), 30: (24, 27)]); g.dot("2", (27, 30))
        g.over(sideHead(eyes: eyes, mouth: .tongue, collar: false), dy: 6)
        if let ball {
            let top = [26, 24, 23, 24][ball % 4]
            g.spans("B", [top: (28, 29), top + 1: (27, 30), top + 2: (27, 30), top + 3: (28, 29)])
            g.dot("C", (28, top + 1))
        }
        return g
    }

    // MARK: Falling: legs out, ears up

    func fall(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let k = frame
        g.spans("F", [24: (16, 17), 25: (17, 18), 26: (18 + k, 19 + k)]); g.dot("z", (19 + k, 27), (20 + k, 27))
        g.spans("F", [24: (10, 11), 25: (9, 10), 26: (8 - k, 9 - k)]); g.dot("z", (7 - k, 27), (8 - k, 27))
        g.over(sideBody(tail: frame))
        g.spans("c", [24: (19, 21), 25: (20, 22)]); g.spans("1", [26: (21, 23), 27: (22 - k, 24 - k)])
        g.dot("2", (23, 26))
        g.spans("c", [24: (6, 8), 25: (5, 7)]); g.spans("1", [26: (4, 6), 27: (3 + k, 5 + k)])
        g.dot("2", (6, 26))
        g.over(sideHead(eyes: .wide, mouth: .gasp, earsUp: true, collar: true))
        return g
    }

    // MARK: Eating, head down

    func eat(_ frame: Int, bowl: Bool) -> PixelArt {
        var g = PixelArt()
        if bowl {
            g.run(26, 24, 29, "M"); g.spans("L", [27: (23, 30), 28: (23, 30), 29: (24, 29)]); g.run(30, 25, 28, "R")
            g.run(25, 25, 28, "N")
        }
        g.over(side(headDY: 10 - frame, tail: frame, eyes: .happy, mouth: .smile))
        return g
    }
}

extension PixelKit {
    // MARK: Lying on a window edge, gnawing it

    func chew(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.over(sideBody(tail: frame), dy: 5)
        g.spans("c", [26: (6, 10), 27: (5, 11), 28: (5, 11)]); g.dot("s", (11, 27), (11, 28), (10, 26))
        g.dot("h", (6, 26), (7, 26)); g.spans("1", [29: (3, 8), 30: (3, 8)]); g.dot("2", (8, 30))
        g.run(29, 16, 23, "c"); g.run(30, 16, 23, "s")
        g.spans("1", [29: (24, 27), 30: (24, 27)]); g.dot("2", (27, 30), (25, 30))
        g.over(sideHead(eyes: .happy, mouth: frame == 0 ? .smile : .gasp, collar: false), dy: 11 - frame)
        return g
    }

    // MARK: Shoving a window that's in the way

    func push(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        leg(&g, rootX: 10, top: 23, width: 2, offset: -2, near: false)
        leg(&g, rootX: 15, top: 23, width: 2, offset: 1, near: false)
        g.over(sideBody(tail: frame), dy: frame)
        leg(&g, rootX: 6, top: 24 + frame, width: 3, offset: -3, near: true)
        g.spans("c", [21 + frame: (19, 24), 22 + frame: (19, 22)]); g.dot("s", (22, 22 + frame), (24, 21 + frame))
        g.spans("1", [20 + frame: (25, 30), 21 + frame: (25, 30)]); g.dot("2", (30, 21 + frame), (27, 21 + frame))
        g.over(sideHead(eyes: .effort, mouth: .smile, collar: true), dy: 2 + frame)
        return g
    }
}
