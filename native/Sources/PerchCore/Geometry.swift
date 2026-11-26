import Foundation

public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}
public struct Rect: Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var minX: Double { x }
    public var maxX: Double { x + width }
    public var minY: Double { y }
    public var maxY: Double { y + height }
    public func contains(_ p: Point) -> Bool { p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY }
    public func intersects(_ other: Rect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }
    public static func fromCG(_ bounds: Rect, primaryTop: Double) -> Rect {
        Rect(bounds.x, primaryTop - bounds.y - bounds.height, bounds.width, bounds.height)
    }
}
public struct DesktopWindow: Sendable {
    public var id: UInt32
    public var bounds: Rect
    public init(id: UInt32, bounds: Rect) { self.id = id; self.bounds = bounds }
}
public enum SurfaceKind: Sendable { case window, floor, menu }
public struct Surface: Equatable, Sendable {
    public var id: String
    public var windowID: UInt32?
    public var left: Double, right: Double, y: Double
    public var kind: SurfaceKind
    public var origin: Point
    public init(id: String, windowID: UInt32? = nil, left: Double, right: Double, y: Double,
                kind: SurfaceKind = .window, origin: Point? = nil) {
        self.id = id; self.windowID = windowID; self.left = left; self.right = right; self.y = y
        self.kind = kind; self.origin = origin ?? Point(left, y)
    }
    public func supports(_ x: Double, margin: Double = 0) -> Bool { x >= left + margin && x <= right - margin }
}
public enum Surfaces {
    public static func subtract(_ interval: ClosedRange<Double>, blockers: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        var remaining = [interval]
        for blocker in blockers {
            remaining = remaining.flatMap { part -> [ClosedRange<Double>] in
                guard blocker.upperBound > part.lowerBound && blocker.lowerBound < part.upperBound else { return [part] }
                var pieces: [ClosedRange<Double>] = []
                if blocker.lowerBound > part.lowerBound { pieces.append(part.lowerBound...min(part.upperBound, blocker.lowerBound)) }
                if blocker.upperBound < part.upperBound { pieces.append(max(part.lowerBound, blocker.upperBound)...part.upperBound) }
                return pieces
            }
        }
        return remaining.filter { $0.upperBound - $0.lowerBound >= 18 }
    }
    /// Windows arrive front-to-back. No owner names, titles or content are needed.
    public static func build(windows: [DesktopWindow], screens: [Rect], visible: [Rect]) -> [Surface] {
        var result: [Surface] = []
        for (index, screen) in screens.enumerated() {
            let safe = visible.indices.contains(index) ? visible[index] : screen
            result.append(Surface(id: "floor-\(index)", left: safe.minX, right: safe.maxX, y: safe.minY, kind: .floor))
            result.append(Surface(id: "menu-\(index)", left: safe.minX, right: safe.maxX, y: safe.maxY, kind: .menu))
            for (z, window) in windows.enumerated() where window.bounds.maxY > safe.minY && window.bounds.maxY <= safe.maxY {
                let left = max(safe.minX, window.bounds.minX)
                let right = min(safe.maxX, window.bounds.maxX)
                guard left < right else { continue }
                let blockers = windows.prefix(z).filter {
                    $0.bounds.minY < window.bounds.maxY + 1 && $0.bounds.maxY >= window.bounds.maxY - 1
                }.map { $0.bounds.minX...$0.bounds.maxX }
                for (part, segment) in subtract(left...right, blockers: blockers).enumerated() {
                    result.append(Surface(id: "window-\(window.id)-\(index)-\(part)", windowID: window.id,
                        left: segment.lowerBound, right: segment.upperBound, y: window.bounds.maxY,
                        origin: Point(window.bounds.minX, window.bounds.maxY)))
                }
            }
        }
        return result
    }
    public static func occluded(pet: Rect, target: UInt32?, windows: [DesktopWindow]) -> Bool {
        guard let target, let index = windows.firstIndex(where: { $0.id == target }) else { return false }
        return windows.prefix(index).contains { $0.bounds.intersects(pet) }
    }
}
