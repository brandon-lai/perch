import XCTest
@testable import PerchCore

final class MischiefTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)

    /// Window A's top edge runs from 100 to 500, where window B (in front) cuts it off.
    let front = DesktopWindow(id: 2, bounds: Rect(500, 150, 400, 300), pid: 42)
    let back = DesktopWindow(id: 1, bounds: Rect(100, 50, 700, 250), pid: 41)
    var ledge: Surface { Surfaces.build(windows: [front, back], screens: [screen], visible: [screen]).first { $0.windowID == 1 }! }

    func testPetSpendsMostOfItsTimeWalkingAndHopsOffWindows() {
        let surfaces = [floor, ledge]
        var pet = PetEngine(position: Point(300, ledge.y))
        pet.perch(on: ledge, x: 300)
        var walking = 0, reachedFloor = false
        let ticks = 30 * 60 * 10
        for _ in 0..<ticks {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [front, back])
            if pet.state == .walk { walking += 1 }
            if pet.support?.kind == .floor { reachedFloor = true }
        }
        XCTAssertGreaterThan(Double(walking) / Double(ticks), 0.6)
        XCTAssertTrue(reachedFloor, "a pet on a window eventually hops down")
    }

    func testWithMischiefOnItStillMostlyWalksBetweenPlayingAndChewing() {
        let surfaces = [floor, ledge]
        var pet = PetEngine(position: Point(300, ledge.y))
        pet.perch(on: ledge, x: 300)
        pet.mischief = Mischief(play: true, chew: true)
        var walking = 0, played = false, bites = 0
        let ticks = 30 * 60 * 15
        for _ in 0..<ticks {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [front, back])
            if pet.state == .walk { walking += 1 }
            if pet.ball != nil { played = true }
            bites += pet.takeEvents().filter { if case .bite = $0 { return true }; return false }.count
        }
        XCTAssertGreaterThan(Double(walking) / Double(ticks), 0.5)
        XCTAssertTrue(played, "plays with its ball unprompted")
        XCTAssertGreaterThan(bites, 0, "chews a window edge unprompted")
    }

    func testWalkingStopsWithItsNoseAtAWindowInFrontAndAsksToPushOnlyWhenAllowed() {
        for allowed in [false, true] {
            var pet = PetEngine(position: Point(440, ledge.y))
            pet.perch(on: ledge, x: 440)
            pet.mischief = Mischief(push: allowed)
            pet.nextPush = 0; pet.direction = 1; pet.change(.walk, .walk)
            var pushes: [PetEvent] = []
            for _ in 0..<(30 * 30) {
                pet.tick(dt: 1.0 / 30, surfaces: [floor, ledge], screens: [screen], rhythm: day, windows: [front, back])
                pushes += pet.takeEvents()
                if pet.support?.windowID == 1 {
                    XCTAssertLessThanOrEqual(pet.position.x + pet.bodyHalfWidth, front.bounds.minX + 0.001,
                                             "the pet never walks into the window in front, where it would vanish")
                }
            }
            if allowed {
                XCTAssertEqual(pushes.first, .push(window: 2, dx: 40))
            } else {
                XCTAssertTrue(pushes.isEmpty)
            }
        }
    }

    func testChewingLeavesOneBiteOnTheWindowUnderfootOnly() {
        var pet = PetEngine(position: Point(10, 0))
        pet.perch(on: floor, x: 300)
        XCTAssertFalse(pet.startChew(), "nothing to chew on the floor")
        pet.perch(on: ledge, x: 300)
        XCTAssertTrue(pet.startChew())
        XCTAssertEqual(pet.trickPose, .chew)
        var bites: [PetEvent] = []
        for _ in 0..<(30 * 4) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, ledge], screens: [screen], rhythm: day, windows: [front, back])
            bites += pet.takeEvents()
        }
        XCTAssertEqual(bites.count, 1)
        guard case .bite(let window, let edge, let offset) = bites.first else { return XCTFail("no bite") }
        XCTAssertEqual(window, 1); XCTAssertEqual(edge, .top)
        XCTAssertGreaterThan(offset, 0); XCTAssertLessThan(offset, back.bounds.width)
        XCTAssertEqual(offset, 300 + pet.direction * pet.muzzleReach - back.bounds.x, accuracy: 0.001)
    }

    func testBallRollsOffTheWindowAndThePetFollowsItDownToKeepBatting() {
        let surfaces = [floor, ledge]
        var pet = PetEngine(position: Point(420, ledge.y))
        pet.perch(on: ledge, x: 420)
        pet.startPlay()
        var bats = 0, ballOnFloor = false, petOnFloor = false
        var lastSpeed = 0.0
        for _ in 0..<(30 * 40) {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [front, back])
            guard let ball = pet.ball else { break }
            XCTAssertTrue(screen.contains(ball.position) || ball.position.y >= 0)
            let speed = abs(ball.velocity.x)
            if speed > 100 && lastSpeed < 20 { bats += 1 }
            lastSpeed = speed
            if ball.support?.kind == .floor { ballOnFloor = true }
            if pet.support?.kind == .floor { petOnFloor = true }
        }
        XCTAssertGreaterThanOrEqual(bats, 2)
        XCTAssertTrue(ballOnFloor && petOnFloor, "the chase can lead down to the floor")
        for _ in 0..<(30 * 60) {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [front, back])
        }
        XCTAssertNil(pet.ball, "the ball is put away a while after play ends")
    }

    func testFastBallNearTheFloorsEndLandsOnTheFloorInsteadOfFallingIntoTheDock() {
        let display = Rect(0, 0, 1440, 900)
        let dockedFloor = Surface(id: "floor-0", left: 0, right: 1440, y: 70, kind: .floor)
        for (x, speed, dt) in [(1430.0, 260.0, 1.0 / 30), (1431.5, 200.0, 0.045), (1420.0, 240.0, 0.1)] {
            var pet = PetEngine(position: Point(x - 200, 70))
            pet.perch(on: dockedFloor, x: x - 200)
            pet.ball = Ball(position: Point(x, 70), velocity: Point(speed, 0), support: dockedFloor)
            for _ in 0..<Int(20 / dt) { pet.tickBall(dt: dt, surfaces: [dockedFloor], screens: [display], windows: []) }
            let ball = pet.ball!
            XCTAssertEqual(ball.position.y, 70, accuracy: 0.001)
            XCTAssertEqual(ball.support?.kind, .floor)
            XCTAssertFalse(ball.moving, "a resting ball lets the app slow its timer and eventually expire it")
        }
    }

    func testNarrowLedgeDoesNotMakeThePetFlickerBackAndForth() {
        let left = DesktopWindow(id: 3, bounds: Rect(100, 300, 200, 200)), right = DesktopWindow(id: 4, bounds: Rect(360, 300, 200, 200))
        let low = DesktopWindow(id: 5, bounds: Rect(100, 100, 460, 300))
        let surfaces = Surfaces.build(windows: [left, right, low], screens: [screen], visible: [screen]) + [floor]
        let gap = surfaces.first { $0.windowID == 5 && $0.left == 300 }!
        var pet = PetEngine(position: Point(330, gap.y))
        pet.perch(on: gap, x: 330)
        pet.startWalking(facing: 1)
        var flips = 0, last = pet.direction
        for _ in 0..<90 {
            pet.tick(dt: 1.0 / 30, surfaces: surfaces, screens: [screen], rhythm: day, windows: [left, right, low])
            if pet.direction != last { flips += 1; last = pet.direction }
        }
        XCTAssertLessThanOrEqual(flips, 1)
    }

    func testBallTuckedAgainstAWindowStillGetsBattedInsteadOfAnEndlessRunInPlace() {
        var pet = PetEngine(position: Point(200, ledge.y))
        pet.perch(on: ledge, x: 200)
        pet.startPlay()
        pet.ball = Ball(position: Point(ledge.right - 9, ledge.y), velocity: Point(0, 0), support: ledge)
        var kicked = false
        for _ in 0..<(30 * 8) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, ledge], screens: [screen], rhythm: day, windows: [front, back])
            if let ball = pet.ball, abs(ball.velocity.x) > 100 { kicked = true; break }
        }
        XCTAssertTrue(kicked)
    }

    func testCalmPetsStillWanderWhileReduceMotionKeepsThePetStill() {
        let calm = Rhythm(hour: 15, calm: true, quietEnabled: false)
        var gentle = PetEngine(position: Point(700, 0)); gentle.perch(on: floor, x: 700)
        var still = PetEngine(position: Point(700, 0)); still.perch(on: floor, x: 700)
        var walking = 0, xs = Set<Int>()
        for _ in 0..<(30 * 120) {
            gentle.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: calm)
            still.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, reduceMotion: true)
            if gentle.state == .walk { walking += 1 }
            xs.insert(Int(gentle.position.x / 20))
            XCTAssertEqual(still.position.x, 700)
        }
        XCTAssertGreaterThan(Double(walking) / Double(30 * 120), 0.25, "calm mode means gentler, not frozen")
        XCTAssertGreaterThan(xs.count, 5)
    }

    func testBedOrPickupEndsAnyTrickAndCalmPetsDontMisbehave() {
        var pet = PetEngine(position: Point(300, ledge.y))
        pet.perch(on: ledge, x: 300)
        pet.startChew(); pet.setBed(true)
        XCTAssertNil(pet.trickPose)
        pet.setBed(false); pet.startPlay(); pet.hold(at: Point(300, 400))
        pet.tick(dt: 0.1, surfaces: [floor, ledge], screens: [screen], rhythm: day)
        XCTAssertNil(pet.trickPose); XCTAssertFalse(pet.running)

        var calm = PetEngine(position: Point(300, ledge.y))
        calm.perch(on: ledge, x: 300)
        calm.mischief = Mischief(play: true, chew: true, push: true)
        for _ in 0..<(30 * 120) {
            calm.tick(dt: 1.0 / 30, surfaces: [floor, ledge], screens: [screen], rhythm: Rhythm(hour: 15, calm: true, quietEnabled: false),
                      windows: [front, back])
            XCTAssertTrue(calm.takeEvents().isEmpty)
            XCTAssertNil(calm.ball)
        }
    }
}
