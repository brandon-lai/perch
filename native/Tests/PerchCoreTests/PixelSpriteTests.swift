import XCTest
@testable import PerchCore

final class PixelSpriteTests: XCTestCase {
    private func solid(_ art: PixelArt, _ x: Int, _ y: Int) -> Bool { art[x, y] != "." && art[x, y] != "x" }

    func testEveryPoseFitsItsOutlineAndKeepsPawsOnItsSurface() {
        let grounded: Set<Action> = [.idle, .walk, .sit, .ride, .react, .pet, .feed, .play, .sniff, .stretch,
                                     .yawn, .shake, .look, .highFive]
        func fits(_ art: PixelArt, _ label: String) {
            for x in 0..<art.width {
                XCTAssertFalse(solid(art, x, 0) || solid(art, x, art.height - 1), "\(label) touches the edge, leaving no room for its outline")
            }
            for y in 0..<art.height {
                XCTAssertFalse(solid(art, 0, y) || solid(art, art.width - 1, y), "\(label) touches the edge, leaving no room for its outline")
            }
        }
        for pose in SpecialPose.allCases {
            let special = PixelSprites.special(pose)
            XCTAssertEqual(special.slots.count, 12)
            XCTAssertTrue(special.slots.allSatisfy(special.frames.indices.contains), "\(pose)")
            for art in special.frames { fits(art, "\(pose)") }
        }
        for action in Action.allCases {
            let animation = PixelSprites.animation(action)
            let label = "\(action)"
            XCTAssertEqual(animation.slots.count, 12, label)
            XCTAssertTrue(animation.slots.allSatisfy(animation.frames.indices.contains), label)
            for art in animation.frames {
                fits(art, label)
                if grounded.contains(action) { XCTAssertTrue((0..<32).contains { solid(art, $0, 30) }, "\(label) floats above its surface") }
                if action == .climb { XCTAssertTrue((0..<32).contains { solid(art, $0, PixelSprites.climbLedgeRow - 1) }, label) }
                if action == .peek { XCTAssertTrue((0..<32).contains { solid(art, $0, 1) }, label) }
            }
        }
    }

    func testClimbingIsAllSideOnRightWayUpAndStridesThroughFourFrames() {
        let climbing: [SpecialPose] = [.scale, .scaleDown, .shimmy]
        XCTAssertEqual(Set(climbing + [.gnaw]), Set(SpecialPose.allCases.filter { PixelSprites.climbHead($0) != nil }))
        XCTAssertEqual(PixelSprites.special(.gnaw).frames.count, 2, "gnawing an edge: chomp, chomp")
        let body: Set<Character> = ["c", "h", "s"]
        for pose in climbing {
            let frames = PixelSprites.special(pose).frames
            XCTAssertEqual(frames.count, 5, "\(pose): four strides and a still frame")
            XCTAssertTrue(frames.allSatisfy { $0.width == PixelSprites.climbSide && $0.height == PixelSprites.climbSide })
            for i in 0..<4 { for j in (i + 1)..<4 { XCTAssertNotEqual(frames[i], frames[j], "\(pose): the paws move through the stride") } }
            XCTAssertGreaterThan(PixelSprites.climbHead(pose)!.y, 0, "\(pose) is right way up")
            for (i, art) in frames.enumerated() {
                func pixels(_ chars: Set<Character>) -> [(Int, Int)] {
                    (0..<art.width).flatMap { x in (0..<art.height).filter { chars.contains(art[x, $0]) }.map { (x, $0) } }
                }
                let claws = pixels(["V"]), rings = pixels(["T"]), fur = pixels(body)
                XCTAssertGreaterThanOrEqual(claws.count, 2, "\(pose) \(i): claws out on its gripping paws")
                XCTAssertGreaterThan(rings.count, 20, "\(pose) \(i): the long ringed tail")
                XCTAssertGreaterThan(Double(rings.map(\.1).reduce(0, +)) / Double(rings.count), 30, "\(pose) \(i): its tail hangs low")
                if pose == .shimmy {
                    // Hanging from the edge on row 6: paws up at it, nothing above it.
                    let edge = Int(PixelSprites.hangEdgeRow)
                    XCTAssertTrue(pixels(["1", "F", "Z", "2", "z"]).contains { $0.1 <= edge + 1 }, "\(pose) \(i): paws at the edge")
                    XCTAssertFalse(fur.contains { $0.1 < edge }, "\(pose) \(i): nothing climbs above it")
                } else {
                    // Side on to a window's edge (column 24): body outside it, claws over it.
                    let headRow = 24 - PixelSprites.climbHead(pose)!.y
                    let bodyFur = fur.filter { abs(Double($0.1) - headRow) > 8 }.map(\.0)
                    XCTAssertLessThan(bodyFur.max() ?? 99, 24, "\(pose) \(i): its body stays off the window")
                    XCTAssertTrue(claws.allSatisfy { $0.0 >= 22 }, "\(pose) \(i): every claw grips the edge")
                    XCTAssertTrue(claws.contains { $0.0 >= 24 }, "\(pose) \(i): and hooks over it")
                }
            }
            // The still frame's eyes sit where the engine puts its head.
            let still = frames[PixelSprites.stillFrame], head = PixelSprites.climbHead(pose)!
            let eyes = (0..<still.width).flatMap { x in (0..<still.height).filter { still[x, $0] == "j" }.map { (Double(x) + 0.5, Double($0) + 0.5) } }
            XCTAssertFalse(eyes.isEmpty, "\(pose)")
            let cx = eyes.map(\.0).reduce(0, +) / Double(eyes.count), cy = eyes.map(\.1).reduce(0, +) / Double(eyes.count)
            XCTAssertLessThan(abs(cx - (24 + head.x)), 4.5, "\(pose) head x")
            XCTAssertLessThan(abs(cy - (24 - head.y)), 4.5, "\(pose) head y")
        }
    }

    func testTheWalkingTailIsLongAndRingedAndTheRunIsAGallop() {
        let walk = PixelSprites.animation(.walk).frames[0]
        let tail = (0..<32).flatMap { x in (0..<32).filter { walk[x, $0] == "T" }.map { (x, $0) } }
        XCTAssertGreaterThan(tail.count, 30, "plenty of rings")
        XCTAssertLessThan(tail.map(\.1).min() ?? 32, 9, "sweeps up well above its back")
        let run = PixelSprites.special(.run)
        XCTAssertEqual(Set(run.slots).count, 4, "a four-beat gallop")
        XCTAssertGreaterThan(spread(run.frames[0]), spread(run.frames[2]) + 6, "reaches out, then gathers")
        var apart = 0
        for (i, frame) in run.frames.enumerated() {
            // Fore and hind paws apart on the ground (except when gathered under it).
            let row = (0..<32).map { solid(frame, $0, 29) }
            if zip(row, [false] + row).filter({ $0 && !$1 }).count >= 2 { apart += 1 }
            // Short, stubby legs: its coat comes down to within eight rows of the ground.
            let coat = (12..<26).flatMap { x in (0..<32).filter { "chs".contains(frame[x, $0]) } }.max() ?? 0
            XCTAssertGreaterThanOrEqual(coat, 22, "frame \(i): short legs")
        }
        XCTAssertGreaterThanOrEqual(apart, 3, "all four legs moving, not a two-legged bound")
    }

    private func spread(_ art: PixelArt) -> Int {
        let xs = (0..<32).filter { solid(art, $0, 30) }
        return (xs.max() ?? 0) - (xs.min() ?? 0)
    }

    func testRedPandaHangsByItsTeethAndDrapesWithItsBellyOnTheEdge() {
        let hang = PixelSprites.special(.hang)
        XCTAssertEqual(hang.frames[0][15, PixelSprites.hangGripRow], "m", "open mouth sits on the pointer's tip")
        let drape = PixelSprites.special(.drape).frames[0]
        let body: Set<Character> = ["c", "h", "s"]
        XCTAssertTrue((7...17).contains { body.contains(drape[$0, PixelSprites.drapeLedgeRow - 1]) }, "belly rests on the edge")
        XCTAssertFalse((7...17).contains { body.contains(drape[$0, PixelSprites.drapeLedgeRow]) }, "only legs hang below it")
        XCTAssertTrue((7...24).contains { solid(drape, $0, PixelSprites.drapeLedgeRow + 3) }, "legs dangle")
    }

    func testNappingItBreathesPeeksAndSnugglesAndItsZsRiseUprightWhicheverWayItFaces() {
        func top(_ art: PixelArt, column x: Int) -> Int? { (0..<32).first { art[x, $0] != "." } }
        for pose in [SpecialPose.drape, .sprawl] {
            let breath = PixelSprites.special(pose).frames
            XCTAssertEqual(breath.count, 2)
            XCTAssertTrue((6...16).contains { top(breath[1], column: $0)! < top(breath[0], column: $0)! }, "its back rises as it breathes")
            let peek = PixelSprites.special(PixelSprites.stirred(pose)!).frames[0]
            func eyeOpen(_ art: PixelArt) -> Bool { (0..<32).contains { art[26, $0] == "j" } }
            XCTAssertTrue(eyeOpen(peek) && !eyeOpen(breath[0]), "peeking, it opens an eye")
            XCTAssertTrue(PixelSprites.asleep(pose))
        }
        let drape = PixelSprites.special(.drape).frames[0]
        XCTAssertTrue((1...8).contains { solid(drape, $0, PixelSprites.drapeLedgeRow + 10) }, "its long tail hangs well down")
        let zs = (0..<4).map { PixelSprites.bubble(.zs, frame: $0) }
        let counts = zs.map { art in (0..<art.height).filter { y in (0..<art.width).contains { art[$0, y] != "." } }.count }
        XCTAssertLessThan(counts[0], counts[1]); XCTAssertLessThan(counts[1], counts[2]); XCTAssertLessThan(counts[3], counts[2])
        // The big z's diagonal starts at its top row's right end either way: z's aren't mirrored, only placed.
        for rightward in [true, false] {
            let art = PixelSprites.bubble(.zs, frame: 2, rightward: rightward)
            let top = (0..<art.height).first { y in (0..<art.width).contains { art[$0, y] == "Y" } }!
            let xs = (0..<art.width).filter { art[$0, top] == "Y" }
            XCTAssertEqual(art[xs.max()! - 1, top + 1], "Y")
            XCTAssertEqual(xs.min()! < art.width / 2, !rightward, "drifting over its nose")
        }
    }

    func testPackColorsDressThePandaAndItsFaceMaskKeepsASoftEdge() {
        let pack = PetPack.redPanda()
        let palette = PixelPalette(pack: pack)
        XCTAssertEqual(palette.colors["c"], RGB(hex: pack.coat))
        XCTAssertEqual(palette.colors["1"], RGB(hex: pack.earColor), "legs")
        XCTAssertEqual(palette.colors["u"], RGB(hex: pack.markingColor), "face mask")
        XCTAssertEqual(palette.colors["f"], RGB(hex: pack.markingColor), "ear rims")
        XCTAssertTrue(palette.softChars.contains("u")); XCTAssertFalse(palette.softChars.contains("c"))
        var art = PixelArt(width: 5, height: 3)
        art[1, 1] = "u"; art[3, 1] = "c"; art[4, 0] = "x"
        let rgba = palette.rgba(art)
        func pixel(_ x: Int, _ y: Int) -> RGB? {
            let i = (y * 5 + x) * 4
            return rgba[i + 3] == 0 ? nil : RGB(rgba[i], rgba[i + 1], rgba[i + 2])
        }
        XCTAssertEqual(pixel(0, 1), palette.softOutline, "the white mask keeps a soft edge")
        XCTAssertEqual(pixel(2, 1), palette.outline, "edges shared with fur stay dark")
        XCTAssertEqual(pixel(4, 0), palette.colors["x"], "whiskers draw over the outline")
        XCTAssertNil(pixel(0, 0), "corners stay transparent")
    }

    func testTheTreeFitsItsOutlineWithASolidBranchAndTrunk() {
        let tree = PixelTree.art()
        for x in 0..<tree.width { XCTAssertEqual(tree[x, 0], "."); XCTAssertEqual(tree[x, tree.height - 1], ".") }
        for y in 0..<tree.height { XCTAssertEqual(tree[0, y], "."); XCTAssertEqual(tree[tree.width - 1, y], ".") }
        for x in PixelTree.branchFrom...PixelTree.branchTo { XCTAssertNotEqual(tree[x, PixelTree.branchTop], ".", "branch at \(x)") }
        XCTAssertEqual(tree[PixelTree.branchFrom + 4, PixelTree.branchTop - 1], ".", "room to stand on the branch")
        XCTAssertNotEqual(tree[Int(PixelTree.trunkCenter), tree.height - 2], ".", "trunk reaches the floor")
    }
}
