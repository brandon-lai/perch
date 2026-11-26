import XCTest
@testable import PerchCore

final class ClimbingTests: XCTestCase {
    let screen = Rect(0, 0, 1400, 900)
    let floor = Surface(id: "floor", left: 0, right: 1400, y: 0, kind: .floor)
    let day = Rhythm(hour: 15, quietEnabled: false)
    let window = DesktopWindow(id: 9, bounds: Rect(300, 0, 700, 600), pid: 77)
    var top: Surface { Surfaces.build(windows: [window], screens: [screen], visible: [screen]).first { $0.windowID == 9 }! }

    func testRedPandaClimbsTheFaceAndSidesAndComesBackOverTheTop() {
        var panda = PetEngine(position: Point(600, top.y))
        panda.agile = true
        panda.perch(on: top, x: 600)
        var sides = Set<ClingSide>(), mounted = 0, wasClinging = false
        for _ in 0..<(30 * 60 * 6) {
            panda.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            if let grip = panda.cling {
                sides.insert(grip.side)
                XCTAssertEqual(grip.window, 9)
                XCTAssertTrue(window.bounds.contains(panda.position) || abs(panda.position.y - window.bounds.maxY) < 5,
                              "a climbing panda stays on its window")
                XCTAssertEqual(panda.state, .climb)
                XCTAssertNotNil(panda.trickPose)
                wasClinging = true
            } else if wasClinging, let support = panda.support {
                if support.windowID == 9 { mounted += 1 }
                wasClinging = false
            }
        }
        XCTAssertTrue(sides.contains(.front), "crawls across the window face")
        XCTAssertTrue(sides.contains(.left) || sides.contains(.right), "climbs a window side")
        XCTAssertGreaterThan(mounted, 0, "pulls itself back up over the top edge")
    }

    func testOnlyAgilePetsLeaveTheEdges() {
        var dog = PetEngine(position: Point(600, top.y))
        dog.perch(on: top, x: 600)
        XCTAssertFalse(dog.startScramble(windows: [window]))
        for _ in 0..<(30 * 60 * 3) {
            dog.tick(dt: 1.0 / 30, surfaces: [floor, top], screens: [screen], rhythm: day, windows: [window])
            XCTAssertNil(dog.cling)
        }
    }

    func testAPandaOnAWindowFaceMovesWithItAndFallsWhenItIsFlung() {
        var panda = PetEngine(position: Point(600, top.y))
        panda.agile = true
        panda.perch(on: top, x: 600)
        XCTAssertTrue(panda.startScramble(windows: [window]))
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

    func testPandaClimbsAWindowBehindItFromTheFloorAndLetsGoWhenPickedUpOrWhenItsWindowCloses() {
        let low = DesktopWindow(id: 4, bounds: Rect(100, 20, 500, 400))
        let lowTop = Surfaces.build(windows: [low], screens: [screen], visible: [screen]).first { $0.windowID == 4 }!
        var panda = PetEngine(position: Point(300, 0))
        panda.agile = true
        panda.perch(on: floor, x: 300)
        XCTAssertTrue(panda.startScramble(windows: [low]))
        XCTAssertEqual(panda.cling?.window, 4)
        panda.hold(at: Point(300, 300))
        XCTAssertNil(panda.cling)
        panda.release()
        for _ in 0..<60 { panda.tick(dt: 1.0 / 30, surfaces: [floor, lowTop], screens: [screen], rhythm: day, windows: [low]) }
        panda.perch(on: floor, x: 300)
        XCTAssertTrue(panda.startScramble(windows: [low]))
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
