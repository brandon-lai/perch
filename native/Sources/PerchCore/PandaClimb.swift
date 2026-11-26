import Foundation

/// A point in art space: x to the right, y down, with pixel (x, y) covering [x, x+1) × [y, y+1).
struct V: Sendable {
    var x: Double, y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    static func + (a: V, b: V) -> V { V(a.x + b.x, a.y + b.y) }
    static func - (a: V, b: V) -> V { V(a.x - b.x, a.y - b.y) }
    static func * (a: V, k: Double) -> V { V(a.x * k, a.y * k) }
    func dot(_ b: V) -> Double { x * b.x + y * b.y }
    var length: Double { hypot(x, y) }
    var unit: V { let l = length; return l > 1e-9 ? V(x / l, y / l) : V(0, 0) }
    /// A quarter turn counterclockwise on screen.
    var left: V { V(y, -x) }
}

extension PixelArt {
    /// Fills a tapered capsule from `a` (radius `ra`) to `b` (radius `rb`). `shade` gets each pixel's offset from
    /// the axis, the radius there and how far along it is (0 at `a`), and returns its slot.
    mutating func capsule(_ a: V, _ b: V, _ ra: Double, _ rb: Double, _ shade: (V, Double, Double) -> Character) {
        let d = b - a, l2 = d.dot(d), r = max(ra, rb)
        let x0 = max(1, Int((min(a.x, b.x) - r).rounded(.down))), x1 = min(width - 2, Int((max(a.x, b.x) + r).rounded(.up)))
        let y0 = max(1, Int((min(a.y, b.y) - r).rounded(.down))), y1 = min(height - 2, Int((max(a.y, b.y) + r).rounded(.up)))
        guard x0 <= x1, y0 <= y1 else { return }
        for y in y0...y1 {
            for x in x0...x1 {
                let p = V(Double(x) + 0.5, Double(y) + 0.5)
                let t = l2 < 1e-9 ? 0 : max(0, min(1, (p - a).dot(d) / l2))
                let off = p - (a + d * t), radius = ra + (rb - ra) * t
                if off.length <= radius { self[x, y] = shade(off, radius, t) }
            }
        }
    }

    /// Paints another grid's pixels over this one, shifted, dropping any that would land on the outline border.
    mutating func overClipped(_ other: PixelArt, dx: Int, dy: Int) {
        for y in 0..<other.height {
            for x in 0..<other.width {
                let ch = other[x, y], tx = x + dx, ty = y + dy
                guard ch != ".", tx > 0, ty > 0, tx < width - 1, ty < height - 1 else { continue }
                self[tx, ty] = ch
            }
        }
    }

    /// The painted pixels' bounds, inclusive.
    var paintedBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var b: (Int, Int, Int, Int)?
        for y in 0..<height {
            for x in 0..<width where self[x, y] != "." {
                b = b.map { (min($0.0, x), min($0.1, y), max($0.2, x), max($0.3, y)) } ?? (x, y, x, y)
            }
        }
        return b
    }
}

/// One leg of a climbing figure: from the body through its elbow or knee to a paw gripping at `paw`, claws
/// pointing along `grip`.
struct ClimbLimb {
    var root: V, knee: V, paw: V
    var near: Bool
    var grip: V
}

/// Climbing, always side on and always right way up, drawn after the owner's photos of red pandas gripping
/// trunks: a long body, short chunky legs gripping a window's edge, and the big ringed tail hanging for balance.
/// The limbs move in a diagonal sequence through four stride frames: each paw reaches ahead, stays planted while
/// the body moves past it, pushes off behind, then swings forward. The app picks the stride frame from how far
/// the panda has climbed (backwards when it backs down), so paws never slide. Frames are 48 px square: up a
/// side they're drawn about the edge (column 24), hanging under a window about its torso, with the edge 18 px
/// above it.
extension PixelKit {
    static let climbSize = 48
    /// A paw's place through one stride, as a fraction of its reach along the way it's going, and whether it's
    /// lifted off the surface (swinging forward).
    static let strideAlong: [Double] = [1, 0, -1, 0]
    /// Hanging from a window's bottom edge, the edge's row in the frame.
    static let hangEdgeRow = 6.0

    /// A short, chunky leg. Near legs catch the light along their top edge, so they read on dark desktops too.
    private func limb(_ g: inout PixelArt, _ l: ClimbLimb) {
        let fur: Character = l.near ? "1" : "F", dark: Character = l.near ? "2" : "z"
        let away = V(0.55, 0.83), lit = V(-0.55, -0.83)
        let shade = { (off: V, r: Double, _: Double) -> Character in
            if l.near && off.dot(lit) / r > 0.55 { return "Z" }
            return off.dot(away) / r > 0.55 ? dark : fur
        }
        g.capsule(l.root, l.knee, 2.3, 2.0, shade)
        g.capsule(l.knee, l.paw, 2.0, 1.8, shade)
        g.capsule(l.paw, l.paw, 2.1, 2.1, shade)
        let c = l.grip.unit, s = c.left
        for k in [-0.8, 0.8] {
            let p = l.paw + c * 2.2 + s * k
            let x = Int(p.x.rounded(.down)), y = Int(p.y.rounded(.down))
            if x > 0, y > 0, x < g.width - 1, y < g.height - 1, g[x, y] == "." { g[x, y] = "V" }
        }
    }

    /// A body seen side on: lit back, rust flank, and the dark belly and chest towards what it's gripping.
    private func flank(_ g: inout PixelArt, hip: V, shoulder: V, belly: V) {
        g.capsule(hip, shoulder, 5.0, 4.4) { off, r, t in
            let a = off.dot(belly) / r
            if a > 0.55 || (t > 0.7 && a > 0.05) { return a > 0.86 ? "2" : "1" }
            if a > 0.25 { return "s" }
            return a < -0.55 ? "h" : "c"
        }
    }

    private func tail(_ g: inout PixelArt, _ points: [V]) {
        pandaTail(&g, along: points.map { ($0.x, $0.y) }, base: 3.6, tip: 2.5, lightFromLeft: true)
    }

    private func place(_ g: inout PixelArt, _ head: PixelArt, at c: V) {
        guard let b = head.paintedBounds else { return }
        let dx = Int((c.x - Double(b.minX + b.maxX + 1) / 2).rounded())
        let dy = Int((c.y - Double(b.minY + b.maxY + 1) / 2).rounded())
        g.overClipped(head, dx: dx, dy: dy)
    }

    /// Phase of a limb in frame `k`: diagonal pairs move together, half a stride apart from the other pair.
    private func phase(_ k: Int, _ offset: Int) -> (along: Double, lifted: Bool) {
        let p = (k + offset) % 4
        return (Self.strideAlong[p], p == 3)
    }

    // MARK: Side on, gripping the edge of a window or the trunk (the edge is column 24, on its right)

    /// Belly to the edge, short legs gripping it and the tail hanging straight down. Played backwards, it backs
    /// down the same way.
    func climbEdge(_ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, stretched = frame != nil && k % 2 == 0
        let half = stretched ? 6.2 : 5.6
        let shoulder = V(19.6, 23.6 - half), hip = V(18.6, 23.6 + half)
        let swing = frame == nil ? 0.4 : [-1, -0.3, 1, 0.3][k]
        let tailBase = hip + V(-1.6, 3.4)
        let tailPoints = [tailBase, tailBase + V(-1.4 + 0.3 * swing, 3.8), tailBase + V(-2.6 + 0.7 * swing, 7.5),
                          tailBase + V(-3.2 + 1.2 * swing, 11.2)]
        for near in [false, true] {
            let edge = near ? 24.4 : 23.8
            let (ha, hl) = frame == nil ? (0.0, false) : phase(k, near ? 2 : 0)
            let hroot = hip + V(near ? 2.0 : 1.0, -0.4)
            let foot = V(edge - (hl ? 1.6 : 0), hip.y + 1.4 - ha * 3.0)
            let hknee = V(min(foot.x, hroot.x + 2.4), min(hroot.y, foot.y) - 1.6)
            let (fa, fl) = frame == nil ? (0.3, false) : phase(k, near ? 0 : 2)
            let froot = shoulder + V(near ? 2.4 : 1.2, 1.0)
            let paw = V(edge + 0.2 - (fl ? 1.6 : 0), shoulder.y - 0.6 - fa * 3.0)
            let fknee = (froot + paw) * 0.5 + V(-1.0, 0.8)
            if !near {
                limb(&g, ClimbLimb(root: hroot, knee: hknee, paw: foot, near: false, grip: V(1, 0.3)))
                limb(&g, ClimbLimb(root: froot, knee: fknee, paw: paw, near: false, grip: V(1, -0.3)))
                tail(&g, tailPoints)
                flank(&g, hip: hip, shoulder: shoulder, belly: V(1, 0))
            } else {
                limb(&g, ClimbLimb(root: hroot, knee: hknee, paw: foot, near: true, grip: V(1, 0.3)))
                limb(&g, ClimbLimb(root: froot, knee: fknee, paw: paw, near: true, grip: V(1, -0.3)))
                place(&g, pandaSideHead(eyes: .open, mouth: .smile), at: V(18.8, 9.4))
            }
        }
        return g
    }

    // MARK: Side on, hanging from a window's bottom edge (the edge is row 6), facing the way it's going

    /// Hand over hand along the edge like monkey bars: forepaws gripping it, head just under it, short hind legs
    /// and the ringed tail swinging below.
    func hangUnder(_ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, edge = Self.hangEdgeRow
        let swing = frame == nil ? 0.0 : [-1, -0.3, 1, 0.3][k]
        let sway = swing * 0.6
        let shoulder = V(21.6 + sway * 0.4, 16.4), hip = V(20.6 - sway * 0.4, 28.4)
        func arm(near: Bool) {
            let (along, lifted) = frame == nil ? (near ? 0.4 : -0.4, false) : phase(k, near ? 0 : 2)
            let root = shoulder + V(near ? 1.2 : -0.6, -1.2)
            let paw = V(22 + along * 2.8 + (near ? 1.4 : -1.4), edge + (lifted ? 2.6 : 0.8))
            limb(&g, ClimbLimb(root: root, knee: (root + paw) * 0.5 + V(-0.8, 0), paw: paw, near: near, grip: V(0, -1)))
        }
        func leg(near: Bool) {
            let root = hip + V(near ? 1.6 : -0.4, 1.4)
            let foot = V((near ? 23.4 : 19.8) - swing * 1.6, 37.6 - (near ? 0 : 0.4))
            limb(&g, ClimbLimb(root: root, knee: (root + foot) * 0.5 + V(1.0, 0), paw: foot, near: near, grip: V(0.3, 1)))
        }
        arm(near: false); leg(near: false)
        let base = hip + V(-2.6, 3.0)
        tail(&g, [base, base + V(-1.6, 4.0), base + V(-2.4 - 0.5 * swing, 8.0), base + V(-2.6 - 1.2 * swing, 11.6)])
        flank(&g, hip: hip, shoulder: shoulder, belly: V(1, 0))
        leg(near: true)
        arm(near: true)
        place(&g, pandaSideHead(eyes: .open, mouth: .smile), at: V(27.4, 15.0))
        return g
    }

    // MARK: Pulling up over an edge, side on (32 px; the ledge is row 14, paws on row 13)

    /// Forepaws flat on top of the edge and its chin on it, body hanging below; then hauling up with the hind
    /// feet scrabbling until they're under it.
    func pullUp(_ frame: Int) -> PixelArt {
        var g = PixelArt()
        let lift = [0.0, 2.0, 4.0][min(max(frame, 0), 2)]
        let shoulder = V(18.0, 18.6 - lift * 0.4), hip = V(14.6, 26.0 - lift)
        let feet: [(V, Bool)] = frame == 0 ? [(V(15.4, 28.6), false), (V(12.6, 28.4), true)]
            : frame == 1 ? [(V(19.6, 23.4), true), (V(13.2, 28.0), false)]
            : [(V(20.4, 20.0), true), (V(18.4, 21.6), false)]
        for (foot, near) in feet where !near {
            limb(&g, ClimbLimb(root: hip + V(1.0, 0.6), knee: (hip + foot) * 0.5 + V(1.4, -0.8), paw: foot, near: false, grip: V(1, 0.4)))
        }
        limb(&g, ClimbLimb(root: shoulder + V(0.6, -0.6), knee: V(21.6, 15.4), paw: V(24.4, 12.0), near: false, grip: V(1, 0.2)))
        // The tail curls up behind it for balance.
        let rump = hip + V(-2.2, 0.8)
        pandaTail(&g, along: [(rump.x, rump.y), (rump.x - 3.0, rump.y - 0.6), (rump.x - 5.0, rump.y - 3.4),
                              (rump.x - 5.4, rump.y - 7.0 + lift * 0.3)],
                  base: 3.0, tip: 2.2, lightFromLeft: true)
        flank(&g, hip: hip, shoulder: shoulder, belly: V(0.9, 0.4).unit)
        for (foot, near) in feet where near {
            limb(&g, ClimbLimb(root: hip + V(2.0, 0.6), knee: (hip + foot) * 0.5 + V(1.4, -0.8), paw: foot, near: true, grip: V(1, 0.4)))
        }
        place(&g, pandaSideHead(eyes: frame == 1 ? .effort : .open, mouth: .smile), at: V(16.0, 8.6))
        limb(&g, ClimbLimb(root: shoulder + V(2.0, -0.4), knee: V(24.4, 15.6), paw: V(27.4, 12.2), near: true, grip: V(1, 0.2)))
        return g
    }
}
