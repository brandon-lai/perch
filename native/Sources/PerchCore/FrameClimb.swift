import Foundation

/// The display itself as something to climb: side on up the inside of the screen's left and right edges, and
/// hanging hand over hand from the top of the screen, just under the menu bar.
extension PetEngine {
    /// The climbable frame of display `index`: from the floor (above the Dock) to just under the menu bar.
    func frameRect(_ index: Int, surfaces: [Surface]) -> Rect? {
        guard let floor = surfaces.first(where: { $0.id == "floor-\(index)" }),
              let menu = surfaces.first(where: { $0.id == "menu-\(index)" }), menu.y > floor.y else { return nil }
        return Rect(floor.left, floor.y, floor.right - floor.left, menu.y - floor.y)
    }

    func frameIndex(for surface: Surface) -> Int? {
        guard surface.kind == .floor, surface.id.hasPrefix("floor-") else { return nil }
        return Int(surface.id.dropFirst("floor-".count))
    }

    /// Where it is on screen for a grip on display frame `f`: on a side at torso height, or under the top.
    func framePoint(_ grip: Cling, frame f: Rect) -> Point {
        switch grip.side {
        case .left: return Point(f.minX, f.minY + grip.offset.y)
        case .right: return Point(f.maxX, f.minY + grip.offset.y)
        case .top, .under: return Point(f.minX + grip.offset.x, f.maxY - underDrop)
        }
    }

    /// Torso height on a screen side at its top corner, where it swings onto the top or back.
    private var frameCorner: Double { bodyHalfWidth * 0.9 }

    /// Up the screen's left or right edge from the floor beside it, side on with its body on the screen.
    @discardableResult
    mutating func startFrameClimb(_ side: ClingSide, surfaces: [Surface], toTop: Bool) -> Bool {
        guard agile, side == .left || side == .right, let surface = support, let index = frameIndex(for: surface),
              let f = frameRect(index, surfaces: surfaces), f.height > bodyHalfWidth * 5 else { return false }
        let bw = bodyHalfWidth
        endTrick()
        support = nil; velocity = Point(0, 0); climbTarget = nil
        let x = side == .left ? 0 : f.width
        var grip = Cling(window: 0, offset: Point(x, clingLift), side: side, heading: Point(0, 1),
                         target: Point(x, bw * 2 + pick() * max(0, f.height - bw * 4)), until: clock + 20 + pick() * 15, frame: index)
        if toTop {
            grip.targetSide = .top; grip.target = Point(bw * 2 + pick() * max(0, f.width - bw * 4), f.height)
            grip.until = clock + (f.height + f.width / 2) / 30 + 10
        }
        cling = grip; climbHolding = false; lastClingOrigin = nil; turnFrom = nil
        position = framePoint(grip, frame: f)
        direction = side == .left ? -1 : 1
        change(.climb, .climb); trickPose = Self.pose(for: grip)
        return true
    }

    /// Climbing the display's frame. Like a window's edges, but from the inside, with the top to hang from.
    mutating func tendFrame(dt: Double, surfaces: [Surface], restless: Bool) {
        guard var grip = cling, let index = grip.frame, let f = frameRect(index, surfaces: surfaces) else { letGo(); return }
        let bw = bodyHalfWidth, topY = f.height - frameCorner
        switch grip.side {
        case .left: grip.offset = Point(0, min(max(grip.offset.y, clingLift), topY))
        case .right: grip.offset = Point(f.width, min(max(grip.offset.y, clingLift), topY))
        case .top, .under: grip.side = .top; grip.offset = Point(min(max(grip.offset.x, 0), f.width), f.height)
        }
        if (restless || clock > grip.until) && grip.then != .dismount {
            // Time to get down: down the nearer side to the floor.
            let side: ClingSide = grip.side == .top ? (grip.offset.x < f.width / 2 ? .left : .right) : grip.side
            grip.targetSide = side; grip.target = Point(side == .left ? 0 : f.width, clingLift); grip.then = .dismount
            grip.until = clock + 60
        }
        var stop = grip.target, turn: (ClingSide, Point)?
        if grip.targetSide != grip.side {
            switch grip.side {
            case .left, .right:
                stop = Point(grip.offset.x, topY); turn = (.top, Point(grip.side == .left ? 0 : f.width, f.height))
            case .top, .under:
                let to: ClingSide = grip.targetSide == .right ? .right : .left
                stop = Point(to == .left ? 0 : f.width, f.height); turn = (to, Point(to == .left ? 0 : f.width, topY))
            }
        }
        let dx = stop.x - grip.offset.x, dy = stop.y - grip.offset.y, distance = hypot(dx, dy)
        if distance > 0.5 {
            let pace = (grip.side == .top ? 30.0 : 36.0) * grip.pace
            grip.heading = Point(dx / distance, dy / distance)
            let step = climbStep(distance, pace: pace, dt: dt, backward: PixelSprites.backsDown(Self.pose(for: grip)))
            grip.offset.x += dx / distance * step; grip.offset.y += dy / distance * step
        } else if let (side, offset) = turn {
            turnFrom = (framePoint(grip, frame: f), clock)
            grip.side = side; grip.offset = offset
            grip.heading = side == .top ? Point(offset.x <= 0.5 ? 1 : -1, 0) : Point(0, -1)
        } else if let then = grip.then {
            position = framePoint(grip, frame: f)
            cling = grip
            switch then {
            case .leap(let p, let head):
                standFromGrip()
                leap(to: head ? Point(p.x, p.y - bw * 1.7) : p, catching: nil)
            case .drop: letGo()
            case .dismount:
                // Step off onto the floor beside the edge, facing back out across the screen.
                guard let floor = surfaces.first(where: { $0.id == "floor-\(index)" }) else { letGo(); return }
                let x = grip.side == .left ? f.minX + bw * 0.4 : f.maxX - bw * 0.4
                cling = nil; climbHolding = false; turnFrom = nil
                perch(on: floor, x: x); direction = grip.side == .left ? 1 : -1
                change(.walk, .walk); nextChoice = 1.5 + pick() * 2; elapsed = 0
            }
            return
        } else if cursorPlay != nil {
            climbHolding = true
        } else {
            climbHolding = true
            wanderFrame(&grip, frame: f)
        }
        switch grip.side {
        case .left: direction = -1
        case .right: direction = 1
        case .top, .under: if abs(grip.heading.x) > 0.1 { direction = grip.heading.x > 0 ? 1 : -1 }
        }
        cling = grip
        position = framePoint(grip, frame: f)
        if let turn = turnFrom {
            let t = min(1, (clock - turn.at) / 0.3)
            if t >= 1 { turnFrom = nil } else {
                let e = t * t * (3 - 2 * t)
                position = Point(turn.from.x + (position.x - turn.from.x) * e, turn.from.y + (position.y - turn.from.y) * e)
            }
        }
        change(.climb, .climb)
        trickPose = Self.pose(for: grip)
    }

    /// Somewhere new on the screen's frame: along a side, across the top, or down and off.
    private mutating func wanderFrame(_ grip: inout Cling, frame f: Rect) {
        let bw = bodyHalfWidth, roll = pick()
        grip.then = nil
        switch grip.side {
        case .left, .right:
            if roll < 0.4 {
                var y = bw * 2 + pick() * max(0, f.height - bw * 4)
                if abs(y - grip.offset.y) < bw * 2 { y = grip.offset.y > f.height / 2 ? bw * 2 : max(bw * 2, f.height - bw * 2) }
                grip.target = Point(grip.offset.x, y)
                grip.until = max(grip.until, clock + abs(y - grip.offset.y) / 36 + 3)
            } else if roll < 0.75 {
                // Up to the top and along under the menu bar.
                grip.targetSide = .top; grip.target = Point(bw * 2 + pick() * max(0, f.width - bw * 4), f.height)
                grip.until = max(grip.until, clock + (f.height - grip.offset.y + f.width / 2) / 30 + 6)
            } else {
                grip.target = Point(grip.offset.x, clingLift); grip.then = .dismount
                grip.until = max(grip.until, clock + grip.offset.y / 36 + 6)
            }
        case .top, .under:
            if roll < 0.5 {
                var x = bw * 2 + pick() * max(0, f.width - bw * 4)
                if abs(x - grip.offset.x) < bw * 3 { x = grip.offset.x > f.width / 2 ? bw * 2 : max(bw * 2, f.width - bw * 2) }
                grip.target = Point(x, f.height)
                grip.until = max(grip.until, clock + abs(x - grip.offset.x) / 30 + 3)
            } else {
                // Over to a side and down it, now or after a look round.
                let side: ClingSide = grip.offset.x < f.width / 2 ? .left : .right
                grip.targetSide = side
                grip.target = Point(side == .left ? 0 : f.width, roll < 0.8 ? bw * 2 + pick() * max(0, f.height / 2) : clingLift)
                if roll >= 0.8 { grip.then = .dismount }
                grip.until = max(grip.until, clock + (f.width / 2 + f.height) / 30 + 6)
            }
        }
    }

    /// On the screen's frame, after the pointer: level with it on a side, or along the top above it, then a leap
    /// for it when it's within reach.
    mutating func aimFrame(at p: Point, surfaces: [Surface], pace: Double, head aimHead: Bool) {
        guard var grip = cling, let index = grip.frame, let f = frameRect(index, surfaces: surfaces) else { return }
        let bw = bodyHalfWidth, reach = bw * 8
        let head = aimHead ? Point(reachPoint.x - position.x, reachPoint.y - position.y) : Point(0, -bw * 0.9)
        grip.then = nil; grip.pace = pace
        let nearTop = f.maxY - p.y < bw * 6
        let side: ClingSide = abs(p.x - f.minX) < abs(p.x - f.maxX) ? .left : .right
        let edge = side == .left ? f.minX : f.maxX
        if abs(p.x - edge) <= reach && !(grip.side == .top && nearTop) {
            // Level with it on the nearer side (round by the top if need be), then a leap across for it.
            grip.targetSide = side
            grip.target = Point(side == .left ? 0 : f.width, min(max(p.y - head.y - f.minY, clingLift), f.height - frameCorner))
            if abs(p.x - edge) > bw * 1.2 { grip.then = .leap(p, head: aimHead) }
        } else if nearTop {
            // Along the top to above it, then drop down at it.
            grip.targetSide = .top; grip.target = Point(min(max(p.x - f.minX, 0), f.width), f.height)
            grip.then = .leap(p, head: aimHead)
        } else {
            // Out of reach from the frame: hold on, and give it up soon.
            if let until = cursorPlay?.until, until > clock + 2 { cursorPlay?.until = clock + 2 }
        }
        grip.until = max(grip.until, clock + 4)
        cling = grip
    }
}
