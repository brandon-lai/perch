import XCTest
@testable import PerchCore

final class CursorPlayTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)
    let window = DesktopWindow(id: 9, bounds: Rect(300, 0, 700, 600), pid: 77)
    var top: Surface { Surfaces.build(windows: [window], screens: [screen], visible: [screen]).first { $0.windowID == 9 }! }

    private func panda(at x: Double = 600) -> PetEngine {
        var pet = PetEngine(position: Point(x, 0))
        pet.agile = true
        pet.mischief = Mischief(play: false, chew: false, cursor: true)
        pet.perch(on: floor, x: x)
        return pet
    }

    /// Ticks with the pointer resting at `cursor` until the panda is hanging from it.
    private func hangOn(_ pet: inout PetEngine, cursor: Point) -> Bool {
        for _ in 0..<(30 * 40) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            if pet.holdingCursor { return true }
        }
        return false
    }

    func testRedPandaStalksALingeringPointerGrabsItRidesAlongAndAShakeDropsIt() {
        var pet = panda()
        var cursor = Point(780, 115)
        var stalked = false, swiped = false
        for _ in 0..<(30 * 40) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            if pet.running { stalked = true }
            if pet.trickPose == .grab { swiped = true }
        }
        XCTAssertTrue(stalked, "runs over to the pointer")
        XCTAssertTrue(swiped, "rears up and swipes before it grabs")
        XCTAssertTrue(pet.holdingCursor, "grabs a pointer that lingers nearby")
        XCTAssertEqual(pet.trickPose, .hang)
        for _ in 0..<10 { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor) }
        XCTAssertEqual(pet.position, cursor, "leaps up and gets its teeth on the pointer's tip")

        // Sticky: a brisk straight move (1,500 pt/s) carries it along rather than shaking it off.
        for _ in 0..<12 {
            cursor.x += 50; cursor.y += 6
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
            XCTAssertTrue(pet.holdingCursor, "holds on through an ordinary move")
            XCTAssertEqual(pet.position, cursor, "rides exactly on the pointer's tip")
        }
        XCTAssertLessThan(pet.hangSwing, 0, "swings out behind a pointer moving right")

        // A real shake (quick back-and-forth) drops it, and it falls back to the floor.
        for i in 0..<15 where pet.holdingCursor {
            cursor.x += i % 2 == 0 ? 60 : -60
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertFalse(pet.holdingCursor, "shaken loose")
        XCTAssertEqual(pet.state, .fall)
        for _ in 0..<90 { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: cursor) }
        XCTAssertEqual(pet.support?.kind, .floor)
    }

    func testItLetsGoOnItsOwnAndPickingItUpOrBedtimeEndsThePlay() {
        var pet = panda()
        XCTAssertTrue(hangOn(&pet, cursor: Point(760, 115)))
        var held = 0
        while pet.holdingCursor && held < 30 * 30 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            held += 1
        }
        XCTAssertGreaterThan(held, 30 * 5, "hangs on for a while")
        XCTAssertLessThan(held, 30 * 17, "gets bored and drops off by itself")

        var picked = panda()
        XCTAssertTrue(hangOn(&picked, cursor: Point(760, 115)))
        picked.hold(at: Point(500, 300))
        XCTAssertFalse(picked.holdingCursor); XCTAssertEqual(picked.state, .held)

        var sleepy = panda()
        XCTAssertTrue(hangOn(&sleepy, cursor: Point(760, 115)))
        sleepy.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 15, idleSeconds: 400, quietEnabled: false),
                    cursor: Point(760, 115))
        XCTAssertFalse(sleepy.holdingCursor, "lets go when it's time to rest")
    }

    func testALowPointerGetsBattedRatherThanRidden() {
        var pet = panda()
        var batted = false
        for _ in 0..<(30 * 30) {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 30))
            if pet.trickPose == .grab { batted = true }
            XCTAssertFalse(pet.holdingCursor, "never dangles below the floor it stands on")
        }
        XCTAssertTrue(batted)
    }

    func testLettingGoDownByTheDockLandsOnTheFloorInsteadOfFallingForever() {
        // The floor sits above a Dock strip, as on most Macs.
        let raised = Surface(id: "floor", left: 0, right: 1400, y: 70, kind: .floor)
        var pet = PetEngine(position: Point(600, 70))
        pet.agile = true
        pet.mischief = Mischief(cursor: true)
        pet.perch(on: raised, x: 600)
        var cursor = Point(760, 190)
        for _ in 0..<(30 * 40) where !pet.holdingCursor {
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertTrue(pet.holdingCursor)
        // Carried right down over the Dock, then shaken off there.
        for _ in 0..<20 {
            cursor.y = max(80, cursor.y - 8)
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        for i in 0..<15 where pet.holdingCursor {
            cursor.x += i % 2 == 0 ? 60 : -60
            pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: cursor)
        }
        XCTAssertFalse(pet.holdingCursor)
        for _ in 0..<60 { pet.tick(dt: 1.0 / 30, surfaces: [raised], screens: [screen], rhythm: day, cursor: nil) }
        XCTAssertEqual(pet.support?.id, "floor")
        XCTAssertEqual(pet.position.y, 70)
    }

    func testOnlyALivelyRedPandaWithCursorPlayOnChasesThePointer() {
        var dog = PetEngine(position: Point(600, 0))
        dog.mischief = Mischief(cursor: true)
        dog.perch(on: floor, x: 600)
        var off = panda(); off.mischief = Mischief()
        var calm = panda(), still = panda()
        for _ in 0..<(30 * 40) {
            dog.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            off.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: Point(760, 115))
            calm.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 15, calm: true, quietEnabled: false),
                      cursor: Point(760, 115))
            still.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, reduceMotion: true, cursor: Point(760, 115))
            for pet in [dog, off, calm, still] { XCTAssertNil(pet.cursorPlay) }
        }
    }

    func testAPointerWhizzingPastMakesItRearUpWithArmsHigh() {
        var pet = panda()
        for _ in 0..<(30 * 5) { pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, cursor: nil) }
        XCTAssertNil(pet.cursorPlay)
        var startled = false
        for i in 0..<20 where !startled {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day,
                     cursor: Point(pet.position.x - 400 + Double(i) * 60, 50))
            startled = pet.trickPose == .grab
        }
        XCTAssertTrue(startled)
    }

    func testRedPandasHoldOnThroughABriskWindowDragThatThrowsADogOff() {
        func ride(_ agile: Bool) -> PetState {
            var pet = PetEngine(position: Point(600, top.y))
            pet.agile = agile
            pet.perch(on: top, x: 600)
            var moved = window; moved.bounds.x += 30
            let movedTop = Surfaces.build(windows: [moved], screens: [screen], visible: [screen]).first { $0.windowID == 9 }!
            pet.tick(dt: 1.0 / 30, surfaces: [floor, movedTop], screens: [screen], rhythm: day, surfaceDT: 1.0 / 30, windows: [moved])
            return pet.state
        }
        XCTAssertEqual(ride(false), .fall, "900 pt/s slides a dog off")
        XCTAssertNotEqual(ride(true), .fall, "a red panda grips on")
    }

    func testAFallingRedPandaCatchesHoldOfAWindowFaceButADogDoesNot() {
        var caught: UInt32?
        var pet = panda()
        for _ in 0..<8 where caught == nil {
            pet.hold(at: Point(600, 520)); pet.release()
            for _ in 0..<60 where caught == nil {
                pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, windows: [window])
                caught = pet.cling?.window
            }
        }
        XCTAssertEqual(caught, 9, "sticky paws catch the window it falls past")
        XCTAssertGreaterThan(pet.position.y, 300, "catches on partway down rather than at the bottom")

        var dog = PetEngine(position: Point(600, 0))
        for _ in 0..<8 {
            dog.hold(at: Point(600, 520)); dog.release()
            for _ in 0..<60 {
                dog.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day, windows: [window])
                XCTAssertNil(dog.cling)
            }
        }
    }

    func testRedPandaComesDownHeadFirstAndWashesSnacksAndDrapesLikeTheRealThing() {
        var pet = PetEngine(position: Point(600, top.y))
        pet.agile = true
        pet.perch(on: top, x: 600)
        var poses = Set<SpecialPose>(), walking = 0
        let ticks = 30 * 60 * 10
        for _ in 0..<ticks {
            pet.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            if let pose = pet.trickPose { poses.insert(pose) }
            if pet.state == .walk || pet.cling != nil || pet.state == .climb { walking += 1 }
            if let grip = pet.cling, grip.side == .front {
                XCTAssertEqual(pet.trickPose, grip.heading.y < -0.3 ? .descend : .crawl)
            }
        }
        XCTAssertTrue(poses.isSuperset(of: [.crawl, .descend, .groom, .nibble]), "\(poses)")
        XCTAssertGreaterThan(Double(walking) / Double(ticks), 0.5, "still on the move most of the time")

        var sleeper = PetEngine(position: Point(600, top.y))
        sleeper.agile = true
        sleeper.perch(on: top, x: 600)
        let night = Rhythm(hour: 23, quietStart: 22, quietEnd: 7)
        sleeper.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: night, windows: [window])
        XCTAssertEqual(sleeper.state, .sleep); XCTAssertEqual(sleeper.trickPose, .drape, "sprawls over a window edge to sleep")
        sleeper.perch(on: floor, x: 100)
        sleeper.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: night, windows: [window])
        XCTAssertEqual(sleeper.state, .sleep); XCTAssertNil(sleeper.trickPose, "curls up on the floor")
    }
}
