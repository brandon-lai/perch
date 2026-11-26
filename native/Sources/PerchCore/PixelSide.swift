import Foundation

struct Gait {
    var nearFront = 0, nearHind = 0, farFront = 0, farHind = 0
    static let stand = Gait()
    static let brace = Gait(nearFront: 2, nearHind: -2, farFront: 1, farHind: -1)
}

extension PixelKit {
    // MARK: Side view, facing right

    func side(gait: Gait = .stand, headDY: Int = 0, bodyDY: Int = 0, bodyDX: Int = 0, tail: Int = 0,
              eyes: Eyes = .open, mouth: Mouth = .smile) -> PixelArt {
        pandaSide(gait: gait, headDY: headDY, bodyDY: bodyDY, headDX: bodyDX, tail: tail, eyes: eyes, mouth: mouth)
    }

    /// A dark leg from `top` down to its paw on row 30, slanted by `offset` at the paw. Near paws show pale claws.
    func leg(_ g: inout PixelArt, rootX: Int, top: Int, width: Int, offset: Int, near: Bool) {
        for y in top...28 {
            let shift = Int((Double(offset) * Double(y - top) / Double(max(1, 28 - top))).rounded())
            let x0 = rootX + shift
            g.run(y, x0, x0 + width - 1, near ? "1" : "F")
            if near { g[x0 + width - 1, y] = "2" }
        }
        let px = rootX + offset
        for y in 29...30 { g.run(y, px, px + width, near ? "1" : "z") }
        if near { g.dot("V", (px + width, 30), (px + width - 1, 30)) }
    }

    func sideBody(tail: Int) -> PixelArt { pandaSideBody(tail: tail) }
    func sideHead(eyes: Eyes, mouth: Mouth) -> PixelArt { pandaSideHead(eyes: eyes, mouth: mouth) }

    // MARK: Play bow, used for stretching and playing with a ball

    func bow(tail: Int, eyes: Eyes = .happy, ball: Int? = nil) -> PixelArt {
        var g = PixelArt()
        leg(&g, rootX: 10, top: 21, width: 2, offset: 0, near: false)
        g.spans("F", [28: (14, 16)]); g.run(29, 13, 17, "z"); g.run(30, 13, 17, "z")
        var raisedTail = PixelArt()
        pandaSideTail(&raisedTail, tail: tail)
        g.over(raisedTail, dy: -1)
        g.spans("c", [13: (8, 12), 14: (6, 14), 15: (5, 16), 16: (5, 17), 17: (5, 18), 18: (5, 19), 19: (6, 20),
                      20: (6, 21), 21: (7, 22), 22: (9, 22), 23: (12, 22), 24: (14, 22), 25: (15, 21)])
        g.run(13, 8, 12, "h"); g.run(14, 6, 12, "h"); g.dot("h", (5, 15), (5, 16))
        g.dot("s", (6, 19), (7, 20), (8, 21), (9, 22), (10, 22), (11, 22), (12, 23), (13, 23), (14, 24), (15, 25),
              (16, 25), (17, 25), (18, 25), (19, 25), (20, 25), (21, 25))
        g.spans("w", [20: (21, 22), 21: (21, 22), 22: (20, 22), 23: (20, 22), 24: (19, 21)])
        leg(&g, rootX: 6, top: 21, width: 3, offset: 0, near: true)
        g.spans("1", [26: (17, 19), 27: (17, 19), 28: (17, 20)]); g.dot("2", (19, 26), (19, 27))
        g.run(29, 17, 23, "1"); g.run(30, 17, 23, "2"); g.spans("1", [29: (24, 27), 30: (24, 27)]); g.dot("V", (27, 30), (26, 30))
        g.over(pandaSideHead(eyes: eyes, mouth: .tongue), dy: 6)
        if let ball {
            let top = [26, 24, 23, 24][ball % 4]
            g.spans("B", [top: (28, 29), top + 1: (27, 30), top + 2: (27, 30), top + 3: (28, 29)])
            g.dot("C", (28, top + 1))
        }
        return g
    }

    // MARK: Falling: legs out

    func fall(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let k = frame
        g.spans("F", [24: (16, 17), 25: (17, 18), 26: (18 + k, 19 + k)]); g.dot("z", (19 + k, 27), (20 + k, 27))
        g.spans("F", [24: (12, 13), 25: (11, 12), 26: (10 - k, 11 - k)]); g.dot("z", (9 - k, 27), (10 - k, 27))
        g.over(pandaSideBody(tail: frame))
        g.spans("1", [24: (19, 21), 25: (20, 22), 26: (21, 23), 27: (22 - k, 24 - k)]); g.dot("2", (23, 26))
        g.spans("1", [24: (8, 10), 25: (7, 9), 26: (6, 8), 27: (5 + k, 7 + k)]); g.dot("2", (8, 26))
        g.over(pandaSideHead(eyes: .wide, mouth: .gasp))
        return g
    }

    // MARK: Lying on a window edge, gnawing it

    func chew(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        g.over(pandaSideBody(tail: frame), dy: 5)
        g.spans("1", [26: (8, 12), 27: (7, 13), 28: (7, 13)]); g.dot("2", (13, 27), (13, 28), (12, 26))
        g.spans("1", [29: (5, 10), 30: (5, 10)]); g.dot("V", (10, 30))
        g.run(29, 16, 23, "1"); g.run(30, 16, 23, "2")
        g.spans("1", [29: (24, 27), 30: (24, 27)]); g.dot("V", (27, 30), (26, 30))
        g.over(pandaSideHead(eyes: .happy, mouth: frame == 0 ? .smile : .gasp), dy: 11 - frame)
        return g
    }

    // MARK: Shoving a window that's in the way

    func push(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        leg(&g, rootX: 12, top: 23, width: 2, offset: -2, near: false)
        leg(&g, rootX: 16, top: 23, width: 2, offset: 1, near: false)
        g.over(pandaSideBody(tail: frame), dy: frame)
        leg(&g, rootX: 9, top: 24 + frame, width: 3, offset: -3, near: true)
        g.spans("1", [21 + frame: (19, 24), 22 + frame: (19, 22)]); g.dot("2", (22, 22 + frame), (24, 21 + frame))
        g.spans("1", [20 + frame: (25, 30), 21 + frame: (25, 30)]); g.dot("V", (30, 21 + frame), (30, 20 + frame))
        g.over(pandaSideHead(eyes: .effort, mouth: .smile), dy: 2 + frame)
        return g
    }
}
