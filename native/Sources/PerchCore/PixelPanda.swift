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

    // MARK: Gripping a window face, seen from behind

    func crawl(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        var limbs = PixelArt()
        limbs.spans("1", [17: (9, 11), 16: (8, 10), 15: (7, 9), 14: (6, 8), 12: (5, 8), 13: (5, 8)])
        limbs.spans("1", [17: (20, 23), 16: (22, 24), 15: (24, 27)]); limbs.run(16, 24, 27, "1")
        limbs.spans("1", [24: (8, 11), 25: (6, 9), 26: (4, 7)]); limbs.run(25, 4, 7, "1")
        limbs.spans("1", [25: (20, 22), 26: (21, 23), 27: (22, 24), 28: (22, 25), 29: (22, 25)])
        limbs.dot("2", (7, 13), (8, 13), (26, 16), (27, 16), (6, 26), (7, 26), (24, 29), (25, 29))
        g.over(limbs, mirror: frame == 1)
        g.spans("c", [26: (14, 17), 27: (14, 17), 28: (14, 17), 29: (14, 17), 30: (15, 16)])
        g.run(27, 14, 17, "T"); g.run(29, 14, 17, "T"); g.run(30, 15, 16, "T"); g.dot("h", (14, 26), (14, 28))
        g.spans("c", [15: (12, 19), 16: (11, 20), 17: (10, 21), 18: (10, 21), 19: (10, 21), 20: (10, 21),
                      21: (10, 21), 22: (10, 21), 23: (11, 20), 24: (11, 20), 25: (12, 19)])
        g.dot("h", (10, 17), (10, 18), (10, 19), (11, 16), (11, 20), (15, 17), (15, 18), (16, 19))
        g.dot("s", (21, 18), (21, 19), (21, 20), (21, 21), (20, 23), (20, 24), (19, 25), (12, 25), (13, 25))
        g.spans("c", [6: (13, 18), 7: (11, 20), 8: (10, 21), 9: (10, 21), 10: (10, 21), 11: (10, 21),
                      12: (10, 21), 13: (11, 20), 14: (12, 19)])
        g.run(6, 13, 18, "h"); g.run(7, 11, 16, "h"); g.dot("h", (10, 8), (10, 9))
        g.dot("s", (21, 10), (21, 11), (21, 12), (20, 13), (19, 14), (12, 14))
        let ear = pandaEar(back: true)
        g.over(ear, dy: -1); g.over(ear, mirror: true, dy: -1)
        return g
    }
}
