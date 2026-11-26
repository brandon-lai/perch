import XCTest
@testable import PerchCore

final class GeometryTests: XCTestCase {
    func testOcclusionSplitsOnlyFrontWindowsAtEdge() {
        let windows = [
            DesktopWindow(id: 1, bounds: Rect(140, 200, 80, 250)),
            DesktopWindow(id: 2, bounds: Rect(80, 50, 240, 250)),
            DesktopWindow(id: 3, bounds: Rect(100, 20, 100, 20))
        ]
        let surfaces = Surfaces.build(windows: windows, screens: [Rect(0, 0, 600, 500)], visible: [Rect(0, 40, 600, 440)])
        let parts = surfaces.filter { $0.windowID == 2 }
        XCTAssertEqual(parts.map(\.left), [80, 220])
        XCTAssertEqual(parts.map(\.right), [140, 320])
        XCTAssertTrue(Surfaces.occluded(pet: Rect(130, 300, 60, 50), target: 2, windows: windows))
        XCTAssertFalse(Surfaces.occluded(pet: Rect(240, 300, 60, 50), target: 2, windows: windows))
    }
    func testSubtractionOverlappingBlockersAndFullCover() {
        XCTAssertEqual(Surfaces.subtract(0...300, blockers: [40...100, 80...190]), [0...40, 190...300])
        XCTAssertEqual(Surfaces.subtract(0...100, blockers: [-20...120]), [])
        XCTAssertEqual(Surfaces.subtract(0...100, blockers: [200...250]), [0...100])
    }
    func testNegativeAndVerticallyStackedDisplayConversion() {
        XCTAssertEqual(Rect.fromCG(Rect(-1440, 300, 400, 200), primaryTop: 900), Rect(-1440, 400, 400, 200))
        XCTAssertEqual(Rect.fromCG(Rect(0, -1000, 400, 200), primaryTop: 900), Rect(0, 1700, 400, 200))
        let screens = [Rect(0, 0, 1200, 900), Rect(-1440, -200, 1440, 1000)]
        let windows = [DesktopWindow(id: 4, bounds: Rect(-200, 100, 500, 300))]
        let result = Surfaces.build(windows: windows, screens: screens, visible: screens)
        XCTAssertEqual(result.filter { $0.windowID == 4 }.map(\.left), [0, -200])
        XCTAssertEqual(result.filter { $0.windowID == 4 }.map(\.right), [300, 0])
        XCTAssertEqual(result.filter { $0.kind == .floor }.map(\.y), [0, -200])
    }
}
final class PhysicsBehaviorTests: XCTestCase {
    let screen = Rect(-500, -100, 1200, 900)
    let floor = Surface(id: "floor", left: -500, right: 700, y: -100, kind: .floor)
    let day = Rhythm(hour: 10, quietEnabled: false)
    func testGravitySnapsHighestCrossedSurface() {
        var pet = PetEngine(position: Point(100, 400))
        let ledge = Surface(id: "ledge", left: 20, right: 300, y: 220)
        for _ in 0..<40 { pet.tick(dt: 1.0 / 30, surfaces: [floor, ledge], screens: [screen], rhythm: day) }
        XCTAssertEqual(pet.position.y, 220, accuracy: 0.001)
        XCTAssertEqual(pet.support?.id, "ledge")
    }
    func testSlowRideAndFastFall() {
        let ledge = Surface(id: "ledge", windowID: 9, left: 20, right: 300, y: 220)
        var pet = PetEngine(position: Point(100, 220)); pet.perch(on: ledge, x: 100)
        let moved = Surface(id: "split-changed", windowID: 9, left: 30, right: 310, y: 225)
        pet.tick(dt: 0.1, surfaces: [floor, moved], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .ride); XCTAssertEqual(pet.position, Point(110, 225))
        let fast = Surface(id: "fast", windowID: 9, left: 150, right: 430, y: 225)
        pet.tick(dt: 0.1, surfaces: [floor, fast], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall); XCTAssertNil(pet.support)
    }
    func testVanishedAndOccludedSupportFalls() {
        let ledge = Surface(id: "ledge", windowID: 9, left: 20, right: 300, y: 220)
        var pet = PetEngine(position: Point(100, 220)); pet.perch(on: ledge, x: 100)
        let blocked = Surface(id: "split", windowID: 9, left: 150, right: 300, y: 220, origin: Point(20, 220))
        pet.tick(dt: 0.1, surfaces: [floor, blocked], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall)
        pet.perch(on: ledge, x: 100)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall)
    }
    func testFastMovingWideLedgeDoesNotImmediatelyReland() {
        let ledge = Surface(id: "ledge", windowID: 9, left: 0, right: 600, y: 220)
        var pet = PetEngine(position: Point(300, 220)); pet.perch(on: ledge, x: 300)
        let fast = Surface(id: "ledge", windowID: 9, left: 100, right: 700, y: 220)
        pet.tick(dt: 0.1, surfaces: [floor, fast], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall); XCTAssertNil(pet.support)
        XCTAssertLessThan(pet.position.y, 220)
    }
    func testTrackingCadenceDoesNotInflateSurfaceSpeed() {
        let ledge = Surface(id: "ledge", windowID: 9, left: 20, right: 500, y: 220)
        var pet = PetEngine(position: Point(100, 220)); pet.perch(on: ledge, x: 100)
        let moved = Surface(id: "ledge", windowID: 9, left: 50, right: 530, y: 220)
        pet.tick(dt: 1.0 / 30, surfaces: [floor, moved], screens: [screen], rhythm: day, surfaceDT: 0.1)
        XCTAssertEqual(pet.state, .ride)
        XCTAssertEqual(pet.position.x, 130)
    }
    func testHoldReleaseAndSafeDisconnectedDisplay() {
        var pet = PetEngine(position: Point(100, 300))
        pet.hold(at: Point(-900, 900)); pet.drag(to: Point(-950, 950))
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .held); XCTAssertEqual(pet.position, Point(-950, 950))
        pet.release()
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall)
        XCTAssertGreaterThanOrEqual(pet.position.x, screen.minX)
        XCTAssertLessThanOrEqual(pet.position.y, screen.maxY)
    }
    func testIdleSleepQuietRhythmWakeAndBed() {
        var pet = PetEngine(position: Point(100, -100)); pet.perch(on: floor, x: 100)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 12, idleSeconds: 301))
        XCTAssertEqual(pet.state, .sleep)
        pet.setBed(false)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 23))
        XCTAssertNotEqual(pet.state, .sleep)
        pet.setBed(true)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .sleep)
        XCTAssertTrue(Rhythm(hour: 23).quiet); XCTAssertTrue(Rhythm(hour: 3).quiet)
        XCTAssertFalse(Rhythm(hour: 12).quiet)
        XCTAssertTrue(Rhythm(hour: 14, quietStart: 12, quietEnd: 16).quiet)
    }
    func testCalmAndReactionReturnToHub() {
        var pet = PetEngine(position: Point(100, -100)); pet.perch(on: floor, x: 100)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: Rhythm(hour: 12, calm: true))
        XCTAssertEqual(pet.state, .sit)
        pet.react(.feed); XCTAssertEqual(pet.action, .feed)
        for _ in 0..<25 { pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day) }
        XCTAssertEqual(pet.state, .idle)
    }
    func testLongBehaviorRunStaysFiniteAndSupported() {
        var pet = PetEngine(position: Point(0, -100)); pet.perch(on: floor, x: 0)
        var visited = Set<PetState>()
        for _ in 0..<18000 {
            pet.tick(dt: 1.0 / 30, surfaces: [floor], screens: [screen], rhythm: day)
            visited.insert(pet.state)
            XCTAssertTrue(pet.position.x.isFinite && pet.position.y.isFinite)
            XCTAssertTrue(floor.supports(pet.position.x))
        }
        XCTAssertTrue(visited.contains(.walk)); XCTAssertTrue(visited.contains(.sit))
    }
    func testClimbInterpolatesAndVanishedTargetFalls() {
        let ledge = Surface(id: "ledge", windowID: 7, left: 40, right: 400, y: 140)
        var pet = PetEngine(position: Point(100, -100)); pet.perch(on: floor, x: 100)
        pet.climb(to: ledge)
        pet.tick(dt: 0.1, surfaces: [floor, ledge], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .climb)
        XCTAssertGreaterThan(pet.position.y, -100); XCTAssertLessThan(pet.position.y, 140)
        for _ in 0..<16 { pet.tick(dt: 0.1, surfaces: [floor, ledge], screens: [screen], rhythm: day) }
        XCTAssertEqual(pet.support?.windowID, 7); XCTAssertEqual(pet.position.y, 140)
        pet.climb(to: ledge)
        pet.tick(dt: 0.1, surfaces: [floor], screens: [screen], rhythm: day)
        XCTAssertEqual(pet.state, .fall)
    }
    func testWalkCanCrossAdjacentDisplays() {
        let screens = [Rect(-500, -100, 500, 900), Rect(0, -100, 700, 900)]
        let left = Surface(id: "left", left: -500, right: 0, y: -100, kind: .floor)
        let right = Surface(id: "right", left: 0, right: 700, y: -100, kind: .floor)
        var pet = PetEngine(position: Point(-15, -100)); pet.perch(on: left, x: -15)
        var crossed = false
        for _ in 0..<12000 {
            pet.tick(dt: 1.0 / 30, surfaces: [left, right], screens: screens, rhythm: day)
            if pet.position.x > 5 { crossed = true; break }
        }
        XCTAssertTrue(crossed)
        XCTAssertEqual(pet.support?.id, "right")
    }
}
final class PackTests: XCTestCase {
    func testBrowserManifestInteroperability() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "browser", withExtension: "perchpack", subdirectory: "Fixtures"))
        let browser = try PetPack.decode(Data(contentsOf: url))
        XCTAssertEqual(browser.name, "Browser Milo")
        XCTAssertEqual(browser.animations.first(where: { $0.name == .sleep })?.frameCount, 1)
        let exported = try browser.encoded()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["schemaVersion", "rigVersion", "name", "species", "coat", "earColor",
            "markingColor", "marking", "ears", "size", "temperament", "remembrance", "animations"]))
        XCTAssertEqual(try PetPack.decode(exported), browser)
    }
    func testRoundTripAndTrimmedName() throws {
        var pack = PetPack(name: "  Juniper  ", species: .cat, ears: .pointed, remembrance: true)
        pack.marking = .tuxedo
        let decoded = try PetPack.decode(pack.encoded())
        XCTAssertEqual(decoded.name, "Juniper"); XCTAssertEqual(decoded.species, .cat)
        XCTAssertTrue(decoded.remembrance); XCTAssertEqual(decoded.animations.count, 19)
    }
    func testSchemaRigNamesColorsAndSizeLimits() throws {
        var pack = PetPack(); pack.schemaVersion = 2
        XCTAssertThrowsError(try pack.validated()) { XCTAssertEqual($0 as? PackError, .schema) }
        pack = PetPack(); pack.rigVersion = "remote-1"
        XCTAssertThrowsError(try pack.validated()) { XCTAssertEqual($0 as? PackError, .rig) }
        for color in ["red", "#FFF", "#GGAAAA", "#12345678", "url(https://example.com)"] {
            pack = PetPack(); pack.coat = color
            XCTAssertThrowsError(try pack.validated())
        }
        pack = PetPack(name: "   "); XCTAssertThrowsError(try pack.validated())
        pack = PetPack(name: String(repeating: "a", count: 41)); XCTAssertThrowsError(try pack.validated())
        XCTAssertThrowsError(try PetPack.decode(Data(repeating: 32, count: 256 * 1024 + 1))) {
            XCTAssertEqual($0 as? PackError, .tooLarge)
        }
    }
    func testMissingDuplicateAndUnknownActionsRejected() throws {
        var pack = PetPack(); pack.animations.removeLast()
        XCTAssertThrowsError(try pack.validated()) { XCTAssertEqual($0 as? PackError, .manifest) }
        pack = PetPack(); pack.animations[1] = pack.animations[0]
        XCTAssertThrowsError(try pack.validated())
        let json = String(data: try PetPack().encoded(), encoding: .utf8)!.replacingOccurrences(of: "\"idle\"", with: "\"executeScript\"")
        XCTAssertThrowsError(try PetPack.decode(Data(json.utf8)))
    }
    func testFiniteBoundsAndTiming() {
        for value in [Double.nan, .infinity, -.infinity, -0.1, 1.1] {
            var pack = PetPack(); pack.animations[0].anchor.x = value
            XCTAssertThrowsError(try pack.validated())
            pack = PetPack(); pack.animations[0].anchor.y = value
            XCTAssertThrowsError(try pack.validated())
        }
        for value in [0.0, 31.0, .infinity] {
            var pack = PetPack(); pack.animations[0].fps = value
            XCTAssertThrowsError(try pack.validated())
        }
        for value in [0, 121] {
            var pack = PetPack(); pack.animations[0].frameCount = value
            XCTAssertThrowsError(try pack.validated())
        }
    }
}
