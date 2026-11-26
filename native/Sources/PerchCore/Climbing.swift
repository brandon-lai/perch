import Foundation

/// Where an agile pet (a red panda) is holding on to a window, relative to that window's bottom-left corner.
public enum ClingSide: String, Sendable { case front, left, right }

public struct Cling: Equatable, Sendable {
    public var window: UInt32
    public var offset: Point
    public var side: ClingSide
    /// Last movement direction, so sides know whether to draw the pet heading up or down.
    public var heading: Point
    var target: Point
    var until: Double
    /// Heading for the spot under the top edge where it will pull itself up.
    var exiting = false
}

extension Surfaces {
    /// The window you'd see at `point`: windows arrive front to back.
    public static func frontmost(at point: Point, windows: [DesktopWindow]) -> DesktopWindow? {
        windows.first { $0.bounds.contains(point) }
    }
}

extension PetEngine {
    /// Grab the window face just below the edge underfoot, or the window right behind the pet.
    @discardableResult
    public mutating func startScramble(windows: [DesktopWindow]) -> Bool {
        guard agile, state != .held else { return false }
        var options: [(DesktopWindow, Point)] = []
        if let s = support, s.kind == .window, let w = windows.first(where: { $0.id == s.windowID }),
           Surfaces.frontmost(at: Point(position.x, w.bounds.maxY - 12), windows: windows)?.id == w.id {
            // Over the top edge and down the face.
            options.append((w, Point(position.x - w.bounds.x, w.bounds.height - 4)))
        }
        if let w = Surfaces.frontmost(at: Point(position.x, position.y + 24), windows: windows), w.id != support?.windowID {
            options.append((w, Point(position.x - w.bounds.x, max(0, position.y + 4 - w.bounds.y))))
        }
        guard !options.isEmpty else { return false }
        let (window, offset) = options[min(options.count - 1, Int(pick() * Double(options.count)))]
        endTrick(); homeActivity = .exploring
        support = nil; velocity = Point(0, 0); climbTarget = nil
        lastClingOrigin = Point(window.bounds.x, window.bounds.y)
        var grip = Cling(window: window.id, offset: offset, side: .front, heading: Point(0, -1),
                         target: offset, until: clock + 18 + pick() * 22)
        grip.target = faceTarget(on: window, windows: windows) ?? offset
        cling = grip
        change(.climb, .climb); trickPose = .crawl
        nextScramble = clock + 6 + pick() * 8
        return true
    }

    /// Let go of the window face and drop to whatever is below.
    mutating func letGo(fling: Double = 0) {
        cling = nil; lastClingOrigin = nil
        support = nil; velocity = Point(fling, 0); change(.fall, .fall)
    }

    /// A random spot on the window's visible face, as an offset from its bottom-left corner.
    mutating func faceTarget(on window: DesktopWindow, windows: [DesktopWindow]) -> Point? {
        for _ in 0..<8 {
            let a = pick(), b = pick()
            let x = 20 + a * max(0, window.bounds.width - 40), y = b * max(0, window.bounds.height - bodyHalfWidth * 2)
            let point = Point(window.bounds.x + x, window.bounds.y + y + bodyHalfWidth)
            if Surfaces.frontmost(at: point, windows: windows)?.id == window.id { return Point(x, y) }
        }
        return nil
    }

    /// Climbing on a window face or side. The normal physics are skipped while it holds on.
    mutating func tendCling(dt: Double, surfaceDT: Double?, surfaces: [Surface], windows: [DesktopWindow],
                            restless: Bool) {
        guard var grip = cling, let window = windows.first(where: { $0.id == grip.window }) else { letGo(); return }
        let origin = Point(window.bounds.x, window.bounds.y)
        if let last = lastClingOrigin {
            let moved = hypot(origin.x - last.x, origin.y - last.y), interval = max(surfaceDT ?? dt, 0.001)
            if moved / interval > 650 { letGo(fling: max(-220, min(220, (origin.x - last.x) / interval))); return }
        }
        lastClingOrigin = origin
        grip.offset.x = min(max(grip.offset.x, 0), window.bounds.width)
        grip.offset.y = min(max(grip.offset.y, 0), window.bounds.height)
        if (restless || clock > grip.until) && !grip.exiting {
            guard let exit = exitPoint(on: window, surfaces: surfaces, from: grip.offset) else { letGo(); return }
            grip.target = exit; grip.exiting = true
        }
        let dx = grip.target.x - grip.offset.x, dy = grip.target.y - grip.offset.y, distance = hypot(dx, dy)
        if distance > 0.5 {
            let step = min(distance, (grip.side == .front ? 28.0 : 36.0) * dt)
            grip.offset.x += dx / distance * step; grip.offset.y += dy / distance * step
            grip.heading = Point(dx / distance, dy / distance)
            if abs(dx) > 0.5 { direction = dx > 0 ? 1 : -1 }
        } else if grip.exiting {
            mount(on: window, surfaces: surfaces, at: origin.x + grip.offset.x); return
        } else {
            let roll = pick()
            if roll < 0.35, let next = faceTarget(on: window, windows: windows) {
                grip.target = next
            } else if roll < 0.6 {
                // Over to a side, or along the side it's already on.
                let x = grip.side != .front ? grip.offset.x : (pick() < 0.5 ? 0 : window.bounds.width)
                grip.target = Point(x, bodyHalfWidth + pick() * max(0, window.bounds.height - bodyHalfWidth * 2))
            } else if roll < 0.88, let exit = exitPoint(on: window, surfaces: surfaces, from: grip.offset) {
                grip.target = exit; grip.exiting = true
            } else {
                letGo(); return
            }
        }
        grip.side = grip.offset.x <= 0.5 ? .left : grip.offset.x >= window.bounds.width - 0.5 ? .right : .front
        cling = grip
        position = Point(origin.x + grip.offset.x, origin.y + grip.offset.y)
        change(.climb, .climb)
        trickPose = grip.side == .front ? .crawl : .scale
    }

    /// Just under the nearest uncovered stretch of the window's top edge, or nil if it's all covered.
    func exitPoint(on window: DesktopWindow, surfaces: [Surface], from offset: Point) -> Point? {
        let x = window.bounds.x + offset.x
        let tops = surfaces.filter { $0.windowID == window.id && $0.kind == .window && $0.right - $0.left >= 30 }
        guard let top = tops.min(by: { abs(($0.left + $0.right) / 2 - x) < abs(($1.left + $1.right) / 2 - x) }) else { return nil }
        return Point(min(max(x, top.left + 12), top.right - 12) - window.bounds.x, window.bounds.height - 4)
    }

    /// Pull up over the top edge, using the same hop as climbing onto a ledge.
    mutating func mount(on window: DesktopWindow, surfaces: [Surface], at x: Double) {
        cling = nil; lastClingOrigin = nil
        guard let top = surfaces.first(where: { $0.windowID == window.id && $0.kind == .window && $0.supports(x) }) else {
            letGo(); return
        }
        position = Point(x, top.y - 4)
        beginClimb(to: top)
    }
}
