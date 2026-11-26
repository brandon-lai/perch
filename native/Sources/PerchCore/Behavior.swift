import Foundation

public enum PetState: String, CaseIterable, Sendable { case idle, react, sit, sleep, held, fall, ride, walk, climb }
public struct Rhythm: Sendable {
    public var hour: Int
    public var idleSeconds: Double
    public var calm: Bool
    public var quietStart: Int
    public var quietEnd: Int
    public var quietEnabled: Bool
    public init(hour: Int = 12, idleSeconds: Double = 0, calm: Bool = false,
                quietStart: Int = 22, quietEnd: Int = 7, quietEnabled: Bool = true) {
        self.hour = hour; self.idleSeconds = idleSeconds; self.calm = calm
        self.quietStart = quietStart; self.quietEnd = quietEnd; self.quietEnabled = quietEnabled
    }
    public var quiet: Bool {
        guard quietEnabled else { return false }
        if quietStart == quietEnd { return true }
        return quietStart < quietEnd ? hour >= quietStart && hour < quietEnd : hour >= quietStart || hour < quietEnd
    }
}
public struct PetEngine: Sendable {
    public private(set) var state: PetState = .fall
    public private(set) var action: Action = .fall
    public var position: Point
    public private(set) var velocity = Point(0, 0)
    public private(set) var support: Surface?
    public private(set) var direction: Double = 1
    public private(set) var bed = false
    private var elapsed: Double = 0
    private var nextChoice: Double = 4
    private var random: UInt64 = 0x5045524348
    private var overrideUntil = 0.0
    private var clock = 0.0
    private var actionRemaining = 0.0
    private var climbTarget: Surface?
    private var climbFrom = Point(0, 0)
    public init(position: Point) { self.position = position }
    public mutating func setBed(_ value: Bool) {
        bed = value
        if value { change(.sleep, .sleep) } else { overrideUntil = clock + 300; change(support == nil ? .fall : .idle, support == nil ? .fall : .idle) }
    }
    public mutating func hold(at point: Point) { climbTarget = nil; position = point; support = nil; velocity = Point(0, 0); change(.held, .held) }
    public mutating func drag(to point: Point) { if state == .held { position = point } }
    public mutating func release() { climbTarget = nil; support = nil; velocity = Point(0, 0); change(.fall, .fall) }
    public mutating func react(_ selected: Action = .pet) {
        guard state != .held else { return }
        bed = false; overrideUntil = clock + 300
        change(.react, selected); actionRemaining = 2
    }
    public mutating func relocate(_ point: Point) { position = point; release(); bed = false }
    public mutating func perch(on surface: Surface, x: Double) {
        climbTarget = nil
        support = surface; position = Point(x, surface.y); velocity = Point(0, 0); change(.sit, .sit)
    }
    public mutating func climb(to surface: Surface) {
        bed = false; overrideUntil = clock + 300
        climbFrom = position; climbTarget = surface
        support = nil; change(.climb, .climb); elapsed = 0
    }
    private mutating func change(_ newState: PetState, _ newAction: Action) {
        if state != newState || action != newAction { elapsed = 0 }
        state = newState; action = newAction
    }
    private mutating func pick() -> Double {
        random = random &* 6364136223846793005 &+ 1
        return Double(random >> 32) / Double(UInt32.max)
    }
    public mutating func tick(dt rawDT: Double, surfaces: [Surface], screens: [Rect], rhythm: Rhythm, surfaceDT: Double? = nil) {
        let dt = max(0, min(rawDT.isFinite ? rawDT : 0, 0.1))
        let wallDT = max(0, min(rawDT.isFinite ? rawDT : 0, 1))
        clock += wallDT; elapsed += wallDT; actionRemaining -= wallDT
        guard state != .held else { return }
        if bed { change(.sleep, .sleep); return }
        if state == .climb, let target = climbTarget {
            guard let current = surfaces.first(where: {
                target.windowID != nil ? $0.windowID == target.windowID && $0.supports((target.left + target.right) / 2) : $0.id == target.id
            }) else { release(); return }
            let t = min(1, elapsed / 0.7), eased = 1 - pow(1 - t, 2)
            let x = min(max(climbFrom.x, current.left + 20), current.right - 20)
            position = Point(climbFrom.x + (x - climbFrom.x) * eased,
                climbFrom.y + (current.y - climbFrom.y) * eased + sin(t * .pi) * 32)
            if t >= 1 {
                climbTarget = nil; support = current; position = Point(x, current.y)
                change(.sit, current.kind == .menu ? .peek : .sit)
            }
            return
        }
        var riding = false
        var detachedWindow: UInt32?
        if let previous = support {
            let current = surfaces.first {
                if let id = previous.windowID { return $0.windowID == id && $0.supports(position.x + $0.origin.x - previous.origin.x) }
                return $0.id == previous.id
            }
            if let current {
                let dx = current.origin.x - previous.origin.x, dy = current.origin.y - previous.origin.y
                let movementDT = max(surfaceDT ?? dt, 0.001)
                let speed = hypot(dx, dy) / movementDT
                if speed > 650 {
                    detachedWindow = previous.windowID
                    velocity = Point(max(-220, min(220, dx / movementDT)), 20)
                    support = nil; change(.fall, .fall)
                } else {
                    position.x += dx; position.y = current.y; support = current
                    riding = hypot(dx, dy) > 0.05
                }
            } else { support = nil; change(.fall, .fall) }
        }
        if support == nil {
            change(.fall, .fall)
            let oldY = position.y
            velocity.y = max(-1000, velocity.y - 1150 * dt)
            position.x += velocity.x * dt; position.y += velocity.y * dt
            let landing = surfaces.filter {
                $0.kind != .menu && (detachedWindow == nil || $0.windowID != detachedWindow) &&
                $0.supports(position.x) && $0.y <= oldY + 0.5 && $0.y >= position.y
            }.max { $0.y < $1.y }
            if let landing {
                support = landing; position.y = landing.y; velocity = Point(0, 0)
                change(.react, .shake); actionRemaining = 1
            }
        } else if riding {
            change(.ride, .ride); elapsed = 0
        } else if state == .ride && elapsed > 0.18 { change(.idle, .idle) }
        if support != nil && !riding {
            if (rhythm.quiet || rhythm.idleSeconds >= 300) && clock >= overrideUntil {
                change(.sleep, .sleep)
            } else if state == .sleep { change(.idle, .stretch); actionRemaining = 2 }
            if state == .react || state == .climb {
                if actionRemaining <= 0 { change(.idle, .idle) }
            } else if state != .sleep {
                if rhythm.calm { change(.sit, .sit) }
                else if elapsed >= nextChoice {
                    let value = pick()
                    let morning = rhythm.hour >= 7 && rhythm.hour < 12
                    if value < (morning ? 0.52 : 0.3) { change(.walk, .walk) }
                    else if value < 0.65 { change(.sit, .sit) }
                    else if value < 0.85 { change(.idle, .sniff) }
                    else { change(.idle, .yawn) }
                    elapsed = 0; nextChoice = 3 + pick() * 6
                }
                if state == .walk, let surface = support {
                    position.x += direction * 24 * dt
                    if !surface.supports(position.x, margin: 12) {
                        let edge = direction > 0 ? surface.right : surface.left
                        let continuation = surfaces.first {
                            $0.id != surface.id && $0.kind == surface.kind && $0.windowID == surface.windowID &&
                            abs($0.y - surface.y) < 1 && $0.supports(edge + direction)
                        }
                        if let continuation {
                            if !surface.supports(position.x) { support = continuation }
                        } else {
                            direction *= -1; position.x = min(max(position.x, surface.left + 12), surface.right - 12)
                        }
                    }
                }
            }
        }
        if let screen = screens.first(where: { $0.contains(position) }) ?? screens.min(by: {
            abs(($0.minX + $0.maxX) / 2 - position.x) < abs(($1.minX + $1.maxX) / 2 - position.x)
        }) {
            let leftContinues = screens.contains { $0 != screen && $0.contains(Point(screen.minX - 1, position.y)) }
            let rightContinues = screens.contains { $0 != screen && $0.contains(Point(screen.maxX + 1, position.y)) }
            position.x = min(max(position.x, screen.minX + (leftContinues ? 0 : 12)), screen.maxX - (rightContinues ? 0 : 12))
            if position.y < screen.minY {
                position.y = screen.minY; velocity = Point(0, 0)
            }
            if support == nil { position.y = min(position.y, screen.maxY - 32) }
        }
    }
}
