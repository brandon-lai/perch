import XCTest
@testable import PerchCore

final class ClimbingTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)
    let window = DesktopWindow(id: 9, bounds: Rect(300, 0, 700, 600), pid: 77)
    var top: Surface { Surfaces.build(windows: [window], screens: [screen], visible: [screen]).first { $0.windowID == 9 }! }

    func testRedPandaKeepsToAWindowsEdgesAndComesBackOverTheTop() {
        var panda = PetEngine(position: Point(600, top.y))
        panda.agile = true
        panda.perch(on: top, x: 600)
        var sides = Set<ClingSide>(), mounted = 0, wasClinging = false
        for _ in 0..<(30 * 60 * 6) {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            if let grip = panda.cling {
                sides.insert(grip.side)
                XCTAssertEqual(grip.window, 9)
                XCTAssertTrue(panda.position.x == window.bounds.minX || panda.position.x == window.bounds.maxX,
                              "only ever on a side edge, never the window's face")
                XCTAssertEqual(panda.state, .climb)
                XCTAssertNotNil(panda.trickPose)
                wasClinging = true
            } else if wasClinging, let support = panda.support {
                if support.windowID == 9 { mounted += 1 }
                wasClinging = false
            }
        }
        XCTAssertTrue(sides.contains(.left) || sides.contains(.right), "climbs a window side")
        XCTAssertFalse(sides.contains(.under), "a window on the floor leaves no room to hang under it")
        XCTAssertGreaterThan(mounted, 0, "pulls itself back up over the top edge")
    }

    let tall = DesktopWindow(id: 4, bounds: Rect(500, 0, 400, 700), pid: 7)
    var tallTop: Surface { Surfaces.build(windows: [tall], screens: [screen], visible: [screen]).first { $0.windowID == 4 }! }
    func smallPanda(at x: Double, on surface: Surface) -> PetEngine {
        var panda = PetEngine(position: Point(x, surface.y))
        panda.agile = true; panda.bodyHalfWidth = 24; panda.muzzleReach = 21; panda.hangDepth = 25
        panda.perch(on: surface, x: x)
        return panda
    }

    func testItGripsAWindowSideSideOnClimbsItInStridesAndPullsItselfOverTheTopCorner() {
        var panda = smallPanda(at: 300, on: floor)
        panda.errand = Errand(target: Point(490.4, 0), until: 40, edge: EdgeGrip(window: 4, facing: 1, stand: 490.4))
        var frames: [Int] = [], steps: [Double] = [], last: Point?, mounted = false
        for _ in 0..<(30 * 40) where !mounted {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, tallTop], screens: [screen], rhythm: day, windows: [tall])
            if let grip = panda.cling {
                XCTAssertEqual(grip.side, .left); XCTAssertEqual(panda.trickPose, .scale)
                XCTAssertEqual(panda.position.x, 500, accuracy: 0.01, "paws on the edge, body outside the window")
                XCTAssertEqual(panda.direction, 1, "facing the window")
                if let last, panda.position.y > last.y + 0.01 { steps.append(panda.position.y - last.y); frames.append(panda.strideFrame) }
                last = panda.position
            }
            mounted = panda.support?.windowID == 4
        }
        XCTAssertTrue(mounted, "climbs to the top corner and over")
        XCTAssertGreaterThan(steps.count, 100)
        XCTAssertEqual(Set(frames), [0, 1, 2, 3], "every stride frame")
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $1 == $0 || $1 == ($0 + 1) % 4 }, "in order, never skipping")
        XCTAssertGreaterThan((steps.max() ?? 0) / max(steps.min() ?? 1, 0.001), 3, "surges with each pull")
        XCTAssertLessThan(panda.position.x - 500, 24, "over the corner it climbed to")
    }

    func testAtTheEndOfAWindowTopItBacksDownTheSideTailFirstAndStepsOffOntoTheFloor() {
        var panda = smallPanda(at: 890, on: tallTop)
        XCTAssertTrue(panda.startEdgeDescent(from: tall, toward: 1, surfaces: [floor, tallTop], windows: [tall]))
        var frames: [Int] = []
        for _ in 0..<(30 * 40) where panda.support?.kind != .floor {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, tallTop], screens: [screen], rhythm: day, windows: [tall])
            if let grip = panda.cling {
                XCTAssertEqual(grip.side, .right); XCTAssertEqual(panda.trickPose, .scaleDown, "backing down, head up")
                XCTAssertEqual(panda.direction, -1, "facing the window")
                if frames.last != panda.strideFrame { frames.append(panda.strideFrame) }
            }
        }
        XCTAssertGreaterThan(frames.count, 8)
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $1 == ($0 + 3) % 4 || $0 == PixelSprites.stillFrame || $1 == PixelSprites.stillFrame },
                      "its paws step backwards down the edge: \(frames)")
        XCTAssertEqual(panda.support?.kind, .floor, "steps off at the bottom rather than falling")
        XCTAssertGreaterThan(panda.position.x, 900, "on the outside of the window")
    }

    func testItClimbsUpBesideATallWindowRatherThanFloatingUpToItsTop() {
        var panda = smallPanda(at: 430, on: floor)
        panda.errand = Errand(target: Point(700, tallTop.y), until: 60)
        var start: Double?, sides = Set<ClingSide>(), arrived = false
        for _ in 0..<(30 * 60) where !arrived {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, tallTop], screens: [screen], rhythm: day, windows: [tall])
            if let target = panda.climbTarget {
                if start == nil { start = panda.position.y }
                XCTAssertLessThanOrEqual(target.y - (start ?? 0), 24 * 4 + 30, "no long float up through the air")
            } else { start = nil }
            if let grip = panda.cling { sides.insert(grip.side) }
            arrived = panda.support?.windowID == 4
        }
        XCTAssertTrue(arrived)
        XCTAssertTrue(sides.contains(.left), "up the side nearest it")
    }

    func testAnEdgeErrandFollowsAWindowDraggedAwayInsteadOfJumpingToIt() {
        var panda = smallPanda(at: 200, on: floor)
        panda.errand = Errand(target: Point(490.4, 0), until: 40, edge: EdgeGrip(window: 4, facing: 1, stand: 490.4))
        var moved = tall
        for _ in 0..<20 { panda.tick(dt: 1.0 / 30, surfaces: [floor, tallTop], screens: [screen], rhythm: day, windows: [tall]) }
        moved.bounds.x = 900
        let movedTop = Surfaces.build(windows: [moved], screens: [screen], visible: [screen]).first { $0.windowID == 4 }!
        var last = panda.position, gripped = false
        for _ in 0..<(30 * 20) where !gripped {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, movedTop], screens: [screen], rhythm: day, windows: [moved])
            XCTAssertLessThan(abs(panda.position.x - last.x), 24, "no jump across the screen")
            last = panda.position
            gripped = panda.cling != nil
        }
        XCTAssertTrue(gripped); XCTAssertEqual(panda.position.x, 900, accuracy: 0.01, "at the window's new side")
    }

    func testItOnlyComesDownASideFromTheWindowsRealCorner() {
        // A window hanging off the right of the display: its top edge stops at the display's edge.
        let screen = Rect(0, 0, 1440, 900), floor = Surface(id: "floor", left: 0, right: 1440, y: 0, kind: .floor)
        let wide = DesktopWindow(id: 5, bounds: Rect(1200, 200, 600, 500), pid: 7)
        let top = Surfaces.build(windows: [wide], screens: [screen], visible: [screen]).first { $0.windowID == 5 }!
        XCTAssertLessThan(top.right, 1441)
        var panda = smallPanda(at: 1300, on: top)
        panda.errand = Errand(target: Point(1400, 0), until: 20)
        for _ in 0..<(30 * 12) {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [wide])
            XCTAssertLessThan(panda.position.x, 1460, "never sent to the window's off-screen corner")
        }
    }

    func testTimeToRestOnAFloatingWindowWithItsTopCoveredItGetsOffRatherThanFreezing() {
        let floating = DesktopWindow(id: 6, bounds: Rect(400, 300, 500, 300), pid: 7)
        let cover = DesktopWindow(id: 8, bounds: Rect(820, 520, 300, 200), pid: 7)
        let surfaces = [floor] + Surfaces.build(windows: [cover, floating], screens: [screen], visible: [screen]).filter { $0.kind == .window }
        var panda = smallPanda(at: 950, on: floor)
        panda.perch(on: floor, x: 950)
        panda.cling = Cling(window: 6, offset: Point(500, 150), side: .right, heading: Point(0, 1), target: Point(500, 150), until: 100)
        let tired = Rhythm(hour: 15, idleSeconds: 400, quietEnabled: false)
        var ticks = 0
        while panda.cling != nil && ticks < 30 * 20 {
            panda.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: tired, windows: [cover, floating])
            if panda.cling != nil { XCTAssertNotNil(panda.trickPose, "always drawn in a climbing pose while it holds on") }
            ticks += 1
        }
        XCTAssertNil(panda.cling, "gets off the window to go and rest")
        XCTAssertLessThan(ticks, 30 * 15)
    }

    func testAnErrandToATopWhoseNearCornerIsCoveredLeapsUpOntoIt() {
        let window = DesktopWindow(id: 6, bounds: Rect(400, 0, 500, 500), pid: 7)
        let cover = DesktopWindow(id: 8, bounds: Rect(860, 470, 200, 200), pid: 7)
        let tops = Surfaces.build(windows: [cover, window], screens: [screen], visible: [screen]).filter { $0.kind == .window }
        let surfaces = [floor] + tops
        var panda = smallPanda(at: 940, on: floor)
        panda.errand = Errand(target: Point(800, 500), until: 30)
        var arrived = false
        for _ in 0..<(30 * 30) where !arrived {
            panda.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [cover, window])
            arrived = panda.support?.windowID == 6
        }
        XCTAssertTrue(arrived, "up the side and a leap onto the top beside the covered corner")
    }

    func testClimbingPosesAreSideOnAndFollowTheWayItIsGoing() {
        func pose(_ side: ClingSide, _ x: Double, _ y: Double) -> SpecialPose {
            PetEngine.pose(for: Cling(window: 1, offset: Point(0, 0), side: side, heading: Point(x, y), target: Point(0, 0), until: 0))
        }
        XCTAssertEqual(pose(.left, 0, 1), .scale)
        XCTAssertEqual(pose(.right, 0, -1), .scaleDown, "backs down, head up")
        XCTAssertEqual(pose(.under, 1, 0), .shimmy)
        XCTAssertEqual(pose(.under, -1, 0), .shimmy)
    }

    func testFromAFloatingWindowItSwingsUnderAndGoesHandOverHandAlongItsBottomEdgeAndRoundTheCorners() {
        let floating = DesktopWindow(id: 6, bounds: Rect(400, 300, 500, 300), pid: 7)
        let floatTop = Surfaces.build(windows: [floating], screens: [screen], visible: [screen]).first { $0.windowID == 6 }!
        var panda = smallPanda(at: 896, on: floatTop)
        XCTAssertTrue(panda.startEdgeDescent(from: floating, toward: 1, surfaces: [floor, floatTop], windows: [floating]))
        var order: [ClingSide] = [], shimmied = 0
        for _ in 0..<(30 * 90) where panda.cling != nil || order.isEmpty {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, floatTop], screens: [screen], rhythm: day, windows: [floating])
            guard let grip = panda.cling else { continue }
            if order.last != grip.side { order.append(grip.side) }
            if panda.turning { continue }
            switch grip.side {
            case .left: XCTAssertEqual(panda.position.x, 400, accuracy: 0.01)
            case .right: XCTAssertEqual(panda.position.x, 900, accuracy: 0.01)
            case .under:
                XCTAssertEqual(panda.trickPose, .shimmy)
                XCTAssertEqual(panda.position.y, 300 - PixelSprites.hangEdgeDrop * 1.5, accuracy: 0.01, "hangs below the bottom edge")
                XCTAssertTrue((400...900).contains(panda.position.x))
                if !panda.climbHolding { shimmied += 1 }
            }
        }
        XCTAssertEqual(order.first, .right)
        XCTAssertTrue(order.contains(.under), "swings round the corner to hang under it: \(order)")
        XCTAssertGreaterThan(shimmied, 30, "and goes along hand over hand")

        // From the floor below a window hanging lower, it leaps up and hangs from the bottom edge.
        let low = DesktopWindow(id: 7, bounds: Rect(400, 120, 500, 300), pid: 7)
        let lowTop = Surfaces.build(windows: [low], screens: [screen], visible: [screen]).first { $0.windowID == 7 }!
        var leaper = smallPanda(at: 650, on: floor)
        var hung = false
        for _ in 0..<(30 * 3) where !hung {
            if leaper.cling == nil && leaper.support != nil { _ = leaper.startEdgeClimb(surfaces: [floor, lowTop], windows: [low]) }
            leaper.tick(dt: 1.0 / 30, surfaces: [floor, lowTop], screens: [screen], rhythm: day, windows: [low])
            hung = leaper.cling?.side == .under
        }
        XCTAssertTrue(hung, "leaps up and grabs the bottom edge")
    }

    func testOnlyAgilePetsLeaveTheEdges() {
        var dog = PetEngine(position: Point(600, top.y))
        dog.perch(on: top, x: 600)
        XCTAssertFalse(dog.startEdgeClimb(surfaces: [floor, top], windows: [window]))
        for _ in 0..<(30 * 60 * 3) {
            dog.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            XCTAssertNil(dog.cling)
        }
    }

    func testAPandaOnAWindowSideMovesWithItAndFallsWhenItIsFlung() {
        var panda = PetEngine(position: Point(996, top.y))
        panda.agile = true
        panda.perch(on: top, x: 996)
        XCTAssertTrue(panda.startEdgeClimb(surfaces: [floor, top], windows: [window]))
        for _ in 0..<30 { panda.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window]) }
        let before = panda.position
        var moved = window; moved.bounds.x += 3
        let movedTop = Surfaces.build(windows: [moved], screens: [screen], visible: [screen]).first { $0.windowID == 9 }!
        panda.tick(dt: 0.001, surfaces: [floor, movedTop], screens: [screen], rhythm: day, surfaceDT: 0.1, windows: [moved])
        XCTAssertEqual(panda.position.x - before.x, 3, accuracy: 0.2, "a slow window move carries the panda along")
        var flung = moved; flung.bounds.x += 200
        panda.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, surfaceDT: 0.1, windows: [flung])
        XCTAssertNil(panda.cling); XCTAssertEqual(panda.state, .fall)
    }

    func testPandaClimbsTheSideOfAWindowBesideItAndLetsGoWhenPickedUpOrWhenItsWindowCloses() {
        let low = DesktopWindow(id: 4, bounds: Rect(100, 20, 500, 400))
        let lowTop = Surfaces.build(windows: [low], screens: [screen], visible: [screen]).first { $0.windowID == 4 }!
        let stand = 100 - 48 * 0.4
        var panda = PetEngine(position: Point(stand, 0))
        panda.agile = true
        panda.perch(on: floor, x: stand)
        XCTAssertTrue(panda.startEdgeClimb(surfaces: [floor, lowTop], windows: [low]))
        XCTAssertEqual(panda.cling?.window, 4); XCTAssertEqual(panda.cling?.side, .left)
        panda.hold(at: Point(300, 300))
        XCTAssertNil(panda.cling)
        panda.release()
        for _ in 0..<60 { panda.tick(dt: 1.0 / 30, surfaces: [floor, lowTop], screens: [screen], rhythm: day, windows: [low]) }
        panda.perch(on: floor, x: stand)
        XCTAssertTrue(panda.startEdgeClimb(surfaces: [floor, lowTop], windows: [low]))
        panda.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, windows: [])
        XCTAssertNil(panda.cling, "its window closed")
        XCTAssertEqual(panda.state, .fall)
    }

    func testRedPandasInTheFirstDefaultColorsMoveToTheNewOnesButEditedColorsStay() {
        let first = PetPack(name: "Maple", species: .redPanda, coat: "#c2532b", earColor: "#3B2522", markingColor: "#F4EEE4")
        let moved = first.withCurrentRedPandaColors()
        XCTAssertEqual([moved.coat, moved.earColor, moved.markingColor],
                       [Species.redPandaColors.coat, Species.redPandaColors.ear, Species.redPandaColors.marking])
        XCTAssertEqual(moved.name, "Maple")
        var edited = first; edited.coat = "#B84A22"
        XCTAssertEqual(edited.withCurrentRedPandaColors(), edited)
        var dog = first; dog.species = .dog
        XCTAssertEqual(dog.withCurrentRedPandaColors(), dog)
        XCTAssertEqual(PetPack.redPanda().coat, Species.redPandaColors.coat)
    }

    func testRedPandaPacksRoundTripAndReduceMotionKeepsItOffWindowFaces() throws {
        let pack = PetPack(name: "Maple", species: .redPanda, coat: "#C2532B", earColor: "#3B2522")
        XCTAssertEqual(try PetPack.decode(pack.encoded()).species, .redPanda)
        XCTAssertEqual(Species.redPanda.displayName, "Red panda")
        var panda = PetEngine(position: Point(600, top.y))
        panda.agile = true
        panda.perch(on: top, x: 600)
        for _ in 0..<(30 * 60 * 2) {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, reduceMotion: true, windows: [window])
            XCTAssertNil(panda.cling)
        }
    }
}
