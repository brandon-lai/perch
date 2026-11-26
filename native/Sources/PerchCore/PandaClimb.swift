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

/// Climbing, drawn after the owner's photos of red pandas on trunks and branches: a long body stretched between
/// gripping paws, the big ringed tail hanging for balance (or held up when it comes down head first), and the
/// limbs moving in a diagonal sequence through four stride frames: each paw reaches ahead, stays planted while
/// the body moves past it, pushes off behind, then swings forward off the surface. The app picks the stride
/// frame from how far the panda has climbed, so paws never slide. Frames are 48 px square, centred on the
/// torso, or for a window's side on the edge itself.
extension PixelKit {
    static let climbSize = 48
    /// A paw's place through one stride, as a fraction of its reach along the way it's going, and whether it's
    /// lifted off the surface (swinging forward).
    static let strideAlong: [Double] = [1, 0, -1, 0]

    private func limb(_ g: inout PixelArt, _ l: ClimbLimb) {
        let fur: Character = l.near ? "1" : "F", dark: Character = l.near ? "2" : "z"
        let away = V(0.55, 0.83)
        let shade = { (off: V, r: Double, _: Double) -> Character in off.dot(away) / r > 0.5 ? dark : fur }
        g.capsule(l.root, l.knee, 1.9, 1.5, shade)
        g.capsule(l.knee, l.paw, 1.5, 1.25, shade)
        g.capsule(l.paw, l.paw, 1.7, 1.7) { _, _, _ in fur }
        let c = l.grip.unit, s = c.left
        for k in [-0.8, 0.8] {
            let p = l.paw + c * 1.9 + s * k
            let x = Int(p.x.rounded(.down)), y = Int(p.y.rounded(.down))
            if x > 0, y > 0, x < g.width - 1, y < g.height - 1 { g[x, y] = "V" }
        }
    }

    /// The back seen from behind: rust with a lit left flank and a shaded right.
    private func back(_ g: inout PixelArt, hip: V, shoulder: V) {
        g.capsule(hip, shoulder, 6.0, 5.3) { off, r, _ in
            off.dot(V(-0.75, -0.66)) / r > 0.55 ? "h" : off.dot(V(0.86, 0.5)) / r > 0.62 ? "s" : "c"
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

    private func tail(_ g: inout PixelArt, _ points: [V], hanging: Bool) {
        pandaTail(&g, along: points.map { ($0.x, $0.y) }, base: 3.6, tip: 2.5, lightFromLeft: hanging)
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

    // MARK: Seen from behind, on a window face or the trunk

    /// Going up, head high and tail hanging. Still (`frame` nil), it looks back over its shoulder at you.
    func climbUp(_ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, stretched = frame != nil && k % 2 == 0
        let sway = frame == nil ? 0 : [0.8, 0, -0.8, 0][k]
        let shoulder = V(24 - sway, stretched ? 17.6 : 18.4), hip = V(24 + sway * 0.6, stretched ? 31.4 : 30.6)
        for s in [-1.0, 1.0] {
            let (along, lifted) = frame == nil ? (0.3, false) : phase(k, s < 0 ? 2 : 0)
            let root = hip + V(s * 3.2, 0.4)
            let foot = V(24 + s * (lifted ? 9.2 : 10.6), hip.y + 1.2 - along * 4.5)
            limb(&g, ClimbLimb(root: root, knee: (root + foot) * 0.5 + V(s * 2.6, -1.6), paw: foot, near: true,
                               grip: V(s * 0.5, -1)))
        }
        for s in [-1.0, 1.0] {
            let (along, lifted) = frame == nil ? (0.5, false) : phase(k, s < 0 ? 0 : 2)
            let root = shoulder + V(s * 3.0, 1.0)
            let paw = V(24 + s * (lifted ? 12.6 : 14.0), shoulder.y - 4.2 - along * 4.5)
            limb(&g, ClimbLimb(root: root, knee: (root + paw) * 0.5 + V(s * 0.6, 2.3), paw: paw, near: true,
                               grip: V(s * 0.3, -1)))
        }
        back(&g, hip: hip, shoulder: shoulder)
        let swing = frame == nil ? 0.4 : [-1, -0.3, 1, 0.3][k]
        let base = V(24 + sway * 0.6, 33.2)
        tail(&g, [base, base + V(0.3 * swing, 4), base + V(0.8 * swing, 8), base + V(1.6 * swing, 11.6)], hanging: true)
        let head = frame == nil ? pandaFrontHead(eyes: .open, mouth: .smile) : backHead()
        place(&g, head, at: V(24 - sway * 0.5, 11))
        return g
    }

    /// Coming down head first, tail held up, the hind feet turned back to grip and the face looking out at you.
    func climbDown(_ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, stretched = frame != nil && k % 2 == 0
        let sway = frame == nil ? 0 : [0.8, 0, -0.8, 0][k]
        let hip = V(24 + sway * 0.6, stretched ? 16.4 : 17.2), shoulder = V(24 - sway, stretched ? 30.4 : 29.6)
        let swing = frame == nil ? 0.4 : [1, 0.3, -1, -0.3][k]
        let base = V(24 + sway * 0.6, 14.6)
        tail(&g, [base, base + V(0.3 * swing, -3.8), base + V(0.8 * swing, -7.6), base + V(1.5 * swing, -11.2)], hanging: true)
        for s in [-1.0, 1.0] {
            let (along, lifted) = frame == nil ? (0.0, false) : phase(k, s < 0 ? 2 : 0)
            let root = hip + V(s * 3.2, -0.4)
            let foot = V(24 + s * (lifted ? 9.2 : 10.6), hip.y - 1.2 + along * 4.5)
            limb(&g, ClimbLimb(root: root, knee: (root + foot) * 0.5 + V(s * 2.6, 1.6), paw: foot, near: true,
                               grip: V(s * 0.5, -1)))
        }
        for s in [-1.0, 1.0] {
            let (along, lifted) = frame == nil ? (0.3, false) : phase(k, s < 0 ? 0 : 2)
            let root = shoulder + V(s * 3.0, -1.0)
            let paw = V(24 + s * (lifted ? 12.6 : 14.0), shoulder.y + 4.0 + along * 4.5)
            limb(&g, ClimbLimb(root: root, knee: (root + paw) * 0.5 + V(s * 0.6, -2.3), paw: paw, near: true,
                               grip: V(s * 0.3, 1)))
        }
        back(&g, hip: hip, shoulder: shoulder)
        place(&g, pandaFrontHead(eyes: .open, mouth: .smile), at: V(24 - sway * 0.5, 38.6))
        return g
    }

    /// The back of the head and ears, for climbing away from you.
    func backHead() -> PixelArt {
        var g = PixelArt()
        g.paintMirrored(PandaArt.backHead)
        return g
    }

    // MARK: Side on, gripping the edge of a window (the edge is column 24, on its right)

    /// Up the edge: forepaws reaching up it, hind feet pushing, belly to the edge and tail hanging straight down.
    func climbEdge(up: Bool, _ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, stretched = frame != nil && k % 2 == 0
        let v: Double = up ? -1 : 1 // the way it's heading, in art rows
        let mid = up ? 23.6 : 23.2, half = stretched ? 6.4 : 5.8
        let shoulder = V(18.8, mid + v * half), hip = V(17.6, mid - v * half)
        let swing = frame == nil ? 0.4 : [-1, -0.3, 1, 0.3][k]
        let tailBase = hip + V(-1.6, -v * 3.4)
        let tailEnd = up ? 11.4 : 10.6
        let tailPoints = [tailBase, tailBase + V(-1.4 + 0.3 * swing, -v * tailEnd * 0.33),
                          tailBase + V(-2.6 + 0.7 * swing, -v * tailEnd * 0.66), tailBase + V(-3.2 + 1.2 * swing, -v * tailEnd)]
        // Far legs, behind the body, darker.
        for near in [false, true] {
            let edge = near ? 24.5 : 23.9
            let (ha, hl) = frame == nil ? (0.0, false) : phase(k, near ? 2 : 0)
            let hroot = hip + V(near ? 2.2 : 1.2, v * 0.4)
            let foot = V(edge - (hl ? 2 : 0), hip.y - v * 1.2 + v * ha * 4.5)
            let hknee = V(min(foot.x, 23) - 2.2, up ? min(hroot.y, foot.y) - 2.0 : max(hroot.y, foot.y) + 2.0)
            let (fa, fl) = frame == nil ? (0.3, false) : phase(k, near ? 0 : 2)
            let froot = shoulder + V(near ? 2.6 : 1.4, -v * 1.0)
            let paw = V(edge + 0.2 - (fl ? 2 : 0), shoulder.y + v * 2.2 + v * fa * 4.5)
            let fknee = (froot + paw) * 0.5 + V(-1.8, -v * 1.6)
            if !near {
                limb(&g, ClimbLimb(root: hroot, knee: hknee, paw: foot, near: false, grip: V(1, -v * 0.3)))
                limb(&g, ClimbLimb(root: froot, knee: fknee, paw: paw, near: false, grip: V(1, v * 0.3)))
                tail(&g, tailPoints, hanging: true)
                flank(&g, hip: hip, shoulder: shoulder, belly: V(1, 0))
            } else {
                limb(&g, ClimbLimb(root: hroot, knee: hknee, paw: foot, near: true, grip: V(1, -v * 0.3)))
                limb(&g, ClimbLimb(root: froot, knee: fknee, paw: paw, near: true, grip: V(1, v * 0.3)))
                place(&g, pandaSideHead(eyes: .open, mouth: .smile), at: V(18.4, up ? 8.6 : 39.4))
            }
        }
        return g
    }

    // MARK: Side on, across a window face (facing right)

    /// Across a window face, body along its way like a red panda on a branch: up the diagonal with the tail
    /// hanging, straight across, or head first down the diagonal with the tail raised (`rise` 1, 0 or -1).
    func climbSlope(rise: Int, _ frame: Int?) -> PixelArt {
        var g = PixelArt(width: Self.climbSize, height: Self.climbSize)
        let k = frame ?? 1, stretched = frame != nil && k % 2 == 0
        let d = rise > 0 ? V(0.707, -0.707) : rise < 0 ? V(0.707, 0.707) : V(1, 0)
        let belly = d.left * -1
        let c = V(rise == 0 ? 22 : 23, rise > 0 ? 25 : rise < 0 ? 23 : 23), half = stretched ? 6.6 : 6.0
        let shoulder = c + d * half, hip = c - d * half
        let swing = frame == nil ? 0.4 : [-1, -0.3, 1, 0.3][k]
        let rump = hip - d * 3.0
        let tailPoints: [V]
        switch rise {
        case 1: tailPoints = [rump, rump + V(-3.4, 1.6), rump + V(-6.0, 4.8 + 0.6 * swing), rump + V(-7.2 + 0.6 * swing, 9.4 + swing)]
        case 0: tailPoints = [rump, rump + V(-2.8, 2.6), rump + V(-4.0 + 0.5 * swing, 6.6), rump + V(-4.2 + swing, 11.0)]
        default: tailPoints = [rump, rump + V(-2.8, -3.0), rump + V(-4.2 + 0.5 * swing, -7.0), rump + V(-4.4 + swing, -11.0)]
        }
        func legs(near: Bool) {
            let (ha, hl) = frame == nil ? (0.0, false) : phase(k, near ? 2 : 0)
            let hroot = hip + belly * 2.4 + d * (near ? 0.6 : -0.4)
            let foot = hip + belly * (hl ? 6.6 : 8.4) + d * (ha * 4.0)
            let (fa, fl) = frame == nil ? (0.3, false) : phase(k, near ? 0 : 2)
            let froot = shoulder + belly * 2.4 + d * (near ? -0.2 : -1.2)
            let paw = shoulder + belly * (fl ? 6.4 : 8.2) + d * (fa * 4.0 + 0.6)
            limb(&g, ClimbLimb(root: hroot, knee: (hroot + foot) * 0.5 + d * 1.6, paw: foot, near: near, grip: belly))
            limb(&g, ClimbLimb(root: froot, knee: (froot + paw) * 0.5 - d * 1.4, paw: paw, near: near, grip: belly))
        }
        legs(near: false)
        tail(&g, tailPoints, hanging: rise <= 0)
        flank(&g, hip: hip, shoulder: shoulder, belly: belly)
        legs(near: true)
        let lift = rise > 0 ? V(1.6, -1.0) : rise < 0 ? V(1.8, 0.4) : V(0.8, -2.8)
        place(&g, pandaSideHead(eyes: .open, mouth: .smile), at: shoulder + d * 5.6 + lift)
        return g
    }
}
