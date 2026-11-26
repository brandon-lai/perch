import Foundation

/// Mischief the app allows. The engine never moves windows itself; it only asks.
public struct Mischief: Equatable, Sendable {
    public var play: Bool, chew: Bool, push: Bool
    /// Red pandas only: stalk, grab and ride the pointer.
    public var cursor: Bool
    public init(play: Bool = false, chew: Bool = false, push: Bool = false, cursor: Bool = false) {
        self.play = play; self.chew = chew; self.push = push; self.cursor = cursor
    }
}

/// Requests for the app to act on: draw a bite mark, or nudge a window that is in the way.
public enum PetEvent: Equatable, Sendable {
    case bite(window: UInt32, offset: Double)
    case push(window: UInt32, dx: Double)
}

public struct Ball: Equatable, Sendable {
    public var position: Point
    public var velocity: Point
    public var support: Surface?
    public var moving: Bool { support == nil || velocity.x != 0 }
}

enum Trick: Equatable, Sendable {
    case chew(until: Double)
    case push(window: UInt32, until: Double)
    case chase(bats: Int, goal: Int, until: Double, pounceUntil: Double)
}

extension Surfaces {
    /// A window standing in front of the end of `surface`, close enough to bump into.
    public static func wall(beyond edge: Double, facing: Double, on surface: Surface,
                            windows: [DesktopWindow]) -> DesktopWindow? {
        windows.first { w in
            w.id != surface.windowID &&
                (facing > 0 ? abs(w.bounds.minX - edge) <= 2 : abs(w.bounds.maxX - edge) <= 2) &&
                w.bounds.minY < surface.y + 6 && w.bounds.maxY > surface.y + 6
        }
    }
}

extension PetEngine {
    public mutating func takeEvents() -> [PetEvent] {
        defer { events.removeAll() }
        return events
    }

    /// Set off walking one way for a while, e.g. to demonstrate a wall in owned-window verification.
    public mutating func startWalking(facing: Double) {
        endTrick(); direction = facing >= 0 ? 1 : -1; change(.walk, .walk); elapsed = 0; nextChoice = 30
    }

    /// Bring out the ball and chase it for a few bats.
    public mutating func startPlay() {
        guard state != .held else { return }
        if holdingCursor { dropFromCursor() }
        cursorPlay = nil; lounge = nil
        if cling != nil { letGo() }
        bed = false; overrideUntil = clock + 300; treeActivity = .exploring; treeClimb = nil; errand = nil; climbTarget = nil
        ball = Ball(position: Point(position.x + direction * muzzleReach, position.y + 24),
                    velocity: Point(direction * 140, 160), support: nil)
        ballDeadline = clock + 180
        trick = .chase(bats: 0, goal: 3 + Int(pick() * 3), until: clock + 35, pounceUntil: 0)
        nextPlay = clock + 90 + pick() * 90
    }

    /// Lie down on the window edge underfoot and gnaw it. Returns false when there is nothing to chew.
    @discardableResult
    public mutating func startChew() -> Bool {
        guard let surface = support, surface.kind == .window, state != .held else { return false }
        if !surface.supports(position.x + direction * muzzleReach) { direction = -direction }
        guard surface.supports(position.x + direction * muzzleReach) else { return false }
        trick = .chew(until: clock + 2.6); trickPose = .chew; change(.react, .feed)
        return true
    }

    mutating func endTrick() {
        if trick != nil {
            if ball != nil { ballExpiry = clock + 40 }
            nextChoice = 1 + pick() * 1.5
        }
        trick = nil; trickPose = nil; running = false
    }

    // MARK: Walking

    mutating func wander(on surface: Surface, surfaces: [Surface], windows: [DesktopWindow], dt: Double, pace: Double = 1) {
        // Red pandas amble, and cross narrow ledges more carefully still.
        let speed = (gentle ? 20.0 : 32.0) * (agile ? (surface.kind == .window ? 0.7 : 0.85) : 1) * pace
        position.x += direction * speed * dt
        let leftWall = Surfaces.wall(beyond: surface.left, facing: -1, on: surface, windows: windows)
        let rightWall = Surfaces.wall(beyond: surface.right, facing: 1, on: surface, windows: windows)
        // Stop with the nose at a window in front, rather than walking into it and vanishing behind it.
        let lo = surface.left + (leftWall == nil ? 12 : bodyHalfWidth)
        let hi = surface.right - (rightWall == nil ? 12 : bodyHalfWidth)
        if lo > hi {
            // Narrower than the pet: jump down an open side, or settle in the middle.
            position.x = (surface.left + surface.right) / 2
            if surface.kind.isLedge, leftWall == nil || rightWall == nil {
                direction = rightWall == nil ? 1 : -1
                hopOff(edge: direction > 0 ? surface.right : surface.left)
            } else { change(.sit, .sit) }
            return
        }
        guard direction > 0 ? position.x >= hi : position.x <= lo else { return }
        let edge = direction > 0 ? surface.right : surface.left
        let wall = direction > 0 ? rightWall : leftWall
        if wall == nil, let continuation = continuation(of: surface, at: edge, surfaces: surfaces) {
            if !surface.supports(position.x) { support = continuation }
        } else if let wall, mischief.push, !gentle, clock >= nextPush {
            position.x = direction > 0 ? hi : lo
            trick = .push(window: wall.id, until: clock + 1.8); trickPose = .push; change(.react, .ride)
            nextPush = clock + 45 + pick() * 30
            events.append(.push(window: wall.id, dx: direction * 40))
        } else if wall == nil, surface.kind.isLedge, pick() < (gentle ? 0.15 : 0.45) {
            // At the corner of a window's top: often down its side, tail first, instead of a hop.
            if agile, surface.kind == .window, let id = surface.windowID, let w = windows.first(where: { $0.id == id }),
               abs(edge - (direction > 0 ? w.bounds.maxX : w.bounds.minX)) < 1, pick() < 0.6,
               startEdgeDescent(from: w, toward: direction, surfaces: surfaces, windows: windows) { return }
            hopOff(edge: edge)
        } else {
            direction *= -1
            position.x = lo <= hi ? min(max(position.x, lo), hi) : (surface.left + surface.right) / 2
        }
    }

    func continuation(of surface: Surface, at edge: Double, surfaces: [Surface]) -> Surface? {
        surfaces.first {
            $0.id != surface.id && $0.kind == surface.kind && $0.windowID == surface.windowID &&
                abs($0.y - surface.y) < 1 && $0.supports(edge + direction)
        }
    }

    /// A little jump off the end of a window, landing on whatever is below.
    mutating func hopOff(edge: Double) {
        fallFrom = support?.windowID
        support = nil; position.x = edge + direction * 2; velocity = Point(direction * 70, 150)
        change(.fall, .fall)
    }

    /// Returns true when an edge or window in front stops the pet short of `target`.
    @discardableResult
    mutating func run(toward target: Double, on surface: Surface, surfaces: [Surface], windows: [DesktopWindow], dt: Double) -> Bool {
        let toward = target >= position.x ? 1.0 : -1.0
        direction = toward; running = true; change(.walk, .walk)
        if agile { trickPose = .run }
        position.x += toward * min(abs(target - position.x), 100 * dt)
        let edge = toward > 0 ? surface.right : surface.left
        let wall = Surfaces.wall(beyond: edge, facing: toward, on: surface, windows: windows)
        if wall == nil, let continuation = continuation(of: surface, at: edge, surfaces: surfaces) {
            if !surface.supports(position.x) { support = continuation }
            return false
        }
        let limit = edge - toward * (wall == nil ? 12 : bodyHalfWidth)
        if (position.x - limit) * toward >= 0 { position.x = limit; return (target - limit) * toward > 0.5 }
        return false
    }

    // MARK: Tricks

    mutating func tendTrick(dt: Double, surfaces: [Surface], windows: [DesktopWindow]) -> Bool {
        guard let trick, let surface = support else { return false }
        switch trick {
        case .chew(let until):
            guard let window = surface.windowID else { endTrick(); return false }
            if clock < until { trickPose = .chew; change(.react, .feed); return true }
            events.append(.bite(window: window, offset: position.x + direction * muzzleReach - surface.origin.x))
            nextChew = clock + 40 + pick() * 40
            endTrick(); change(.react, .shake); actionRemaining = 0.8
            return true
        case .push(_, let until):
            guard clock < until else { endTrick(); change(.react, .shake); actionRemaining = 0.6; return true }
            trickPose = .push; change(.react, .ride)
            // Follow the window as it slides away.
            let edge = direction > 0 ? surface.right : surface.left
            let wall = Surfaces.wall(beyond: edge, facing: direction, on: surface, windows: windows)
            let limit = edge - direction * (wall == nil ? 12 : bodyHalfWidth)
            if (limit - position.x) * direction > 0 { position.x += direction * min(abs(limit - position.x), 40 * dt) }
            return true
        case .chase(let bats, let goal, let until, let pounceUntil):
            guard var ball, clock < until, bats < goal else { endTrick(); change(.sit, .sit); return true }
            if pounceUntil > 0 {
                if clock < pounceUntil { trickPose = .pounce; change(.react, .play); return true }
                let away: Double = ball.position.x >= position.x ? 1 : -1
                ball.velocity = Point(away * (150 + pick() * 120), 110 + pick() * 80)
                ball.support = nil; ball.position.y += 1
                self.ball = ball
                self.trick = .chase(bats: bats + 1, goal: goal, until: until, pounceUntil: 0)
                change(.idle, .idle)
                return true
            }
            let toward: Double = ball.position.x >= position.x ? 1 : -1
            let sameSurface = ball.support.map { other in
                (surface.windowID != nil ? other.windowID == surface.windowID : other.id == surface.id) &&
                    surface.supports(ball.position.x)
            } ?? false
            if ball.support == nil || abs(ball.velocity.x) > 40 || sameSurface {
                let target = ball.position.x - toward * muzzleReach
                if sameSurface && ball.velocity.x == 0 && abs(target - position.x) <= 4 {
                    direction = toward
                    self.trick = .chase(bats: bats, goal: goal, until: until, pounceUntil: clock + 0.5)
                    trickPose = .pounce; change(.react, .play)
                    return true
                }
                let blocked = run(toward: target, on: surface, surfaces: surfaces, windows: windows, dt: dt)
                if blocked && sameSurface && ball.velocity.x == 0 {
                    // Ball tucked against a window or edge: bat it if it's within a paw's reach, else give up.
                    if abs(ball.position.x - position.x) <= muzzleReach + 24 {
                        direction = toward
                        self.trick = .chase(bats: bats, goal: goal, until: until, pounceUntil: clock + 0.5)
                        trickPose = .pounce; change(.react, .play)
                    } else { endTrick(); change(.sit, .sit) }
                }
                return true
            }
            if ball.position.y < position.y - 4 {
                guard surface.kind.isLedge else { endTrick(); return false }
                // Jump down on the ball's side, or go around the other end if a window is in the way.
                let open = [toward, -toward].first { side in
                    Surfaces.wall(beyond: side > 0 ? surface.right : surface.left, facing: side, on: surface, windows: windows) == nil
                }
                guard let side = open else { endTrick(); return false }
                let edge = side > 0 ? surface.right : surface.left
                if abs(edge - position.x) < 14 { direction = side; hopOff(edge: edge) }
                else { run(toward: edge, on: surface, surfaces: surfaces, windows: windows, dt: dt) }
                return true
            }
            if let ledge = ball.support, ledge.kind == .window, ledge.y - position.y <= 360 {
                beginClimb(to: ledge)
                return true
            }
            endTrick()
            return false
        }
    }

    // MARK: Ball physics

    mutating func tickBall(dt: Double, surfaces: [Surface], screens: [Rect], windows: [DesktopWindow]) {
        guard var b = ball else { return }
        if trick == nil && clock > ballExpiry && !b.moving { ball = nil; return }
        if clock > ballDeadline {
            ball = nil
            if case .chase = trick { endTrick() }
            return
        }
        if let previous = b.support {
            let current = surfaces.first { s in
                if let id = previous.windowID { return s.windowID == id && s.supports(b.position.x + s.origin.x - previous.origin.x) }
                return s.id == previous.id
            }
            if let current {
                b.position.x += current.origin.x - previous.origin.x
                b.position.y = current.y; b.support = current
                b.position.x += b.velocity.x * dt
                b.velocity.x *= pow(0.3, dt)
                if abs(b.velocity.x) < 6 { b.velocity.x = 0 }
                if !current.supports(b.position.x) {
                    let facing: Double = b.velocity.x >= 0 ? 1 : -1, edge = facing > 0 ? current.right : current.left
                    if let next = surfaces.first(where: {
                        $0.id != current.id && $0.kind == current.kind && $0.windowID == current.windowID &&
                            abs($0.y - current.y) < 1 && $0.supports(b.position.x)
                    }) {
                        b.support = next
                    } else if Surfaces.wall(beyond: edge, facing: facing, on: current, windows: windows) != nil {
                        b.position.x = edge - facing * 9; b.velocity.x = -b.velocity.x * 0.5
                    } else {
                        b.support = nil; b.velocity.y = 0
                    }
                }
            } else {
                b.support = nil
            }
        }
        if b.support == nil {
            let oldY = b.position.y
            b.velocity.y = max(-900, b.velocity.y - 1150 * dt)
            b.position.x += b.velocity.x * dt; b.position.y += b.velocity.y * dt
            let landing = surfaces.filter {
                $0.kind != .menu && $0.supports(b.position.x) && $0.y <= oldY + 0.5 && $0.y >= b.position.y
            }.max { $0.y < $1.y }
            if let landing {
                b.position.y = landing.y
                if b.velocity.y < -240 { b.velocity.y = -b.velocity.y * 0.35; b.velocity.x *= 0.8 }
                else { b.velocity.y = 0; b.support = landing }
            }
        }
        if let screen = screens.first(where: { $0.contains(b.position) }) ?? screens.min(by: {
            abs(($0.minX + $0.maxX) / 2 - b.position.x) < abs(($1.minX + $1.maxX) / 2 - b.position.x)
        }) {
            let leftOpen = screens.contains { $0 != screen && $0.contains(Point(screen.minX - 1, b.position.y)) }
            let rightOpen = screens.contains { $0 != screen && $0.contains(Point(screen.maxX + 1, b.position.y)) }
            // Keep the ball within this display's floor, so a fast roll can't drop it into the Dock strip.
            let floor = surfaces.first { $0.kind == .floor && $0.left >= screen.minX - 1 && $0.right <= screen.maxX + 1 }
            let lo = (floor?.left ?? screen.minX) + 8, hi = (floor?.right ?? screen.maxX) - 8
            if !leftOpen && b.position.x < lo { b.position.x = lo; b.velocity.x = abs(b.velocity.x) * 0.5 }
            if !rightOpen && b.position.x > hi { b.position.x = hi; b.velocity.x = -abs(b.velocity.x) * 0.5 }
            if let floor, b.position.y < floor.y {
                b.position.y = floor.y; b.velocity.y = 0; b.support = floor
            } else if b.position.y < screen.minY { b.position.y = screen.minY; b.velocity = Point(0, 0) }
        }
        ball = b
    }
}
