import AppKit
import PerchCore

@MainActor
extension AppController {
    /// The tree on our own overlay: painted pixels take clicks and drags, the panda climbs it, rests and naps on
    /// the branch, and backs down the trunk. Only Perch's own layers are drawn; nothing is captured from the desktop.
    func verifyTree(folder: URL) async throws {
        preferences = Preferences()
        rig = PetRig(pack: .redPanda())
        rebuildOverlays()
        defer {
            timer?.invalidate(); timer = nil
            for (panel, _) in overlays { panel.close() }
            overlays.removeAll()
        }
        for (_, view) in overlays { view.petScene.rig = rig }
        guard let (index, tree) = treeLocation else { throw EvidenceError.fixture("no visible display for the tree") }
        let (panel, view) = overlays[index]
        guard let canvas = panel.contentView else { throw EvidenceError.noBitmap }
        let scale = rig.pixelScale
        engine = PetEngine(position: Point(tree.floor.right - 120, tree.floor.y))
        engine.agile = true; engine.bodyHalfWidth = 16 * scale; engine.muzzleReach = 14 * scale
        engine.hangDepth = Double(PixelSprites.side - PixelSprites.climbLedgeRow - 1) * scale
        engine.perch(on: tree.floor, x: tree.floor.right - 120)
        render()
        var cases: [String: Bool] = [:]
        // A point on the trunk takes the click; open sky beside the trunk, under the crown, doesn't.
        let trunk = NSPoint(x: tree.trunkX, y: tree.origin.y + 12 * scale)
        let beside = NSPoint(x: tree.origin.x + 4 * scale, y: tree.origin.y + 20 * scale)
        refreshPointerRouting(at: trunk)
        cases["treeTakesClicks"] = !panel.ignoresMouseEvents && view.tree.treeHit(canvas.convert(panel.convertPoint(fromScreen: trunk), from: nil), from: canvas)
        refreshPointerRouting(at: beside)
        cases["clicksBesideTheTreePassThrough"] = panel.ignoresMouseEvents
        // Drag it 200 points right.
        beginTreeDrag(at: trunk); dragTree(to: NSPoint(x: trunk.x + 200, y: trunk.y)); endTreeDrag()
        // Only this fixture's ticks move the panda.
        timer?.invalidate(); timer = nil
        guard let moved = treeLocation?.tree else { throw EvidenceError.fixture("tree vanished when dragged") }
        cases["draggingMovesIt"] = abs(moved.trunkX - tree.trunkX - 200) < 1 &&
            abs(view.tree.frame.minX - (moved.origin.x - panel.frame.minX)) < 1
        // Bedtime (or a long idle): over to the tree, up the trunk, and asleep draped over the branch.
        let day = Rhythm(hour: 12, quietEnabled: false), screens = tracker.screens
        let sleepy = Rhythm(hour: 12, idleSeconds: 400, quietEnabled: false)
        func step(_ rhythm: Rhythm) { engine.tick(dt: 1.0 / 30, surfaces: [moved.floor], screens: screens, rhythm: rhythm, tree: moved) }
        var crawled = false, climbShot = false
        for _ in 0..<(30 * 60) where !(engine.support?.id == moved.branch.id && engine.state == .sleep) {
            step(sleepy)
            if engine.trickPose == .crawl && abs(engine.position.x - moved.trunkX) < 0.5 {
                crawled = true
                if !climbShot && engine.position.y > moved.floor.y + 20 * scale {
                    render(); try await waitForRender()
                    try captureTree(view, to: folder.appendingPathComponent("native-tree-climb.png")); climbShot = true
                }
            }
        }
        cases["crawlsUpTheTrunk"] = crawled && climbShot
        cases["settlesOnTheBranch"] = engine.support?.id == moved.branch.id && engine.treeActivity == .inTree
        render(); try await waitForRender()
        let drapeBottom = moved.branch.y - Double(PixelSprites.side - 1 - PixelSprites.drapeLedgeRow) * scale - panel.frame.minY
        cases["napsDrapedOverTheBranch"] = engine.state == .sleep && view.petScene.special == .drape &&
            abs(Double(view.petScene.sprite.frame.minY) - drapeBottom) <= 1 && !view.petScene.sprite.isHidden
        try captureTree(view, to: folder.appendingPathComponent("native-tree-nap.png"))
        // Awake again: back down the trunk, tail first.
        var descended = false
        for _ in 0..<(30 * 60) where engine.support?.kind != .floor {
            step(day)
            if engine.trickPose == .descend { descended = true }
        }
        cases["backsDownTheTrunk"] = descended && engine.support?.id == moved.floor.id
        // The menu's Go to its tree sends it back up for a visit.
        goToTree(); timer?.invalidate(); timer = nil
        for _ in 0..<(30 * 40) where engine.support?.id != moved.branch.id { step(day) }
        cases["goToItsTreeSendsItUp"] = engine.support?.id == moved.branch.id
        bed()
        cases["tuckAwayHidesTheTree"] = view.tree.isHidden
        guard cases.values.allSatisfy({ $0 }) else {
            throw EvidenceError.fixture("tree: " + cases.filter { !$0.value }.keys.sorted().joined(separator: ", "))
        }
        try writeReport(["cases": cases, "passedChecks": cases.count, "otherAppsWindowsTouched": false],
                        to: folder.appendingPathComponent("tree-evidence.json"))
        print("Tree verified: \(cases.count) checks (clicks, drag, trunk climb, branch nap, backing down, tuck-away).")
    }

    // Composite just our own two rendering layers. No window-server or desktop capture.
    private func captureTree(_ overlay: OverlayView, to url: URL) throws {
        let art = overlay.tree, sprite = overlay.petScene.sprite
        guard let decor = art.bitmapImageRepForCachingDisplay(in: art.bounds),
              let frame = sprite.texture?.cgImage() else { throw EvidenceError.noBitmap }
        art.cacheDisplay(in: art.bounds, to: decor)
        let union = art.frame.union(sprite.frame)
        let inset = NSPoint(x: 12 - (union.minX - art.frame.minX), y: 10)
        let image = NSImage(size: NSSize(width: union.width + 24, height: union.maxY - art.frame.minY + 20), flipped: false) { bounds in
            NSColor(hex: "#9FB0C9").setFill(); bounds.fill()
            NSGraphicsContext.current!.imageInterpolation = .none
            decor.draw(in: NSRect(origin: inset, size: art.bounds.size), from: .zero,
                       operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
            let position = sprite.frame.offsetBy(dx: inset.x - art.frame.minX, dy: inset.y - art.frame.minY)
            NSGraphicsContext.current!.cgContext.interpolationQuality = .none
            NSGraphicsContext.current!.cgContext.draw(frame, in: position)
            return true
        }
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { throw EvidenceError.noBitmap }
        try png.write(to: url, options: .atomic)
    }
}

@MainActor
extension AppController {
    /// Every action's distinct frames in two red panda color sets, drawn offscreen at 3×. No windows are captured.
    func captureSprites(folder: URL) throws {
        var cinnamon = PetPack.redPanda(name: "Cinnamon"); cinnamon.coat = "#B9532A"; cinnamon.earColor = "#3A2220"
        var maple = PetPack.redPanda(name: "Maple")
        maple.size = .medium
        let packs = [maple, cinnamon]
        let unit = 3, cell = PixelSprites.climbSide * unit + 8, labelWidth = 88
        let rows: [(PetPack, String, PixelSprites.Animation)] = packs.flatMap { pack in
            Action.allCases.map { (pack, $0.rawValue, PixelSprites.animation($0)) } +
                SpecialPose.allCases.map { (pack, $0.rawValue, PixelSprites.special($0)) }
        }
        let maxFrames = 4
        let width = labelWidth + maxFrames * cell + 8, height = rows.count * cell + 8
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw EvidenceError.noBitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.interpolationQuality = .none
        NSColor(hex: "#9FB0C9").setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium),
                                                    .foregroundColor: NSColor(hex: "#1D2533")]
        for (row, (pack, name, animation)) in rows.enumerated() {
            let y = height - (row + 1) * cell
            ("\(pack.name) \(name)" as NSString).draw(at: NSPoint(x: 6, y: y + cell / 2 - 6), withAttributes: attrs)
            let palette = PixelPalette(pack: pack)
            for (index, art) in animation.frames.prefix(maxFrames).enumerated() {
                let image = pixelImage(palette.rgba(art), width: art.width, height: art.height)
                context.cgContext.draw(image, in: CGRect(x: labelWidth + index * cell, y: y + 4, width: art.width * unit, height: art.height * unit))
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: folder.appendingPathComponent("native-sprites.png"), options: .atomic)
        print("Sprite sheet: \(rows.count) action rows for \(packs.count) trait combinations.")
    }
}

@MainActor
extension AppController {
    /// The climbing poses' stride frames and still frame, large, with the frame's middle marked (the torso, or a
    /// window's edge when gripping a side). Drawn offscreen; no windows are captured.
    func captureClimbPoses(folder: URL) throws {
        let poses: [SpecialPose] = [.crawl, .descend, .scale, .scaleDown, .slopeUp, .slopeDown, .traverse]
        let unit = 6, side = PixelSprites.climbSide, cell = side * unit + 12, labelWidth = 84
        let width = labelWidth + 5 * cell, height = poses.count * cell + 8
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw EvidenceError.noBitmap }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.interpolationQuality = .none
        NSColor(hex: "#9FB0C9").setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium),
                                                    .foregroundColor: NSColor(hex: "#1D2533")]
        let palette = PixelPalette(pack: .redPanda())
        for (row, pose) in poses.enumerated() {
            let y = height - (row + 1) * cell
            (pose.rawValue as NSString).draw(at: NSPoint(x: 8, y: y + cell / 2 - 7), withAttributes: attrs)
            for (index, art) in PixelSprites.special(pose).frames.enumerated() {
                let x = labelWidth + index * cell
                // Odd frames on a dark desktop, where dark legs and outlines are hardest to read.
                NSColor(hex: index % 2 == 0 ? "#B4C2D6" : "#1C1C1E").setFill()
                NSRect(x: x, y: y + 6, width: side * unit, height: side * unit).fill()
                if [SpecialPose.scale, .scaleDown].contains(pose) {
                    // The window, to the right of the edge it grips.
                    NSColor(hex: "#E8EDF4").setFill()
                    NSRect(x: x + side / 2 * unit, y: y + 6, width: side / 2 * unit, height: side * unit).fill()
                }
                let image = pixelImage(palette.rgba(art), width: art.width, height: art.height)
                context.cgContext.draw(image, in: CGRect(x: x, y: y + 6, width: side * unit, height: side * unit))
                NSColor(hex: "#D03050").setFill()
                NSRect(x: x + side / 2 * unit - 3, y: y + 6 + side / 2 * unit - 1, width: 6, height: 2).fill()
                NSRect(x: x + side / 2 * unit - 1, y: y + 6 + side / 2 * unit - 3, width: 2, height: 6).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
        try png.write(to: folder.appendingPathComponent("native-climb-poses.png"), options: .atomic)
        print("Climbing poses: \(poses.count) poses, four stride frames and a still frame each.")
    }

    /// The red panda's frames as character grids for the companion site, which recolors them with the same palette
    /// rules, plus a few PNGs (Maple's default colors) for its social image and icon. Drawn offscreen.
    func exportSiteArt(folder: URL) throws {
        func grid(_ art: PixelArt) -> [String] {
            (0..<art.height).map { y in String((0..<art.width).map { art[$0, y] }) }
        }
        func entry(_ animation: PixelSprites.Animation) -> [String: Any] {
            ["frames": animation.frames.map(grid), "slots": animation.slots]
        }
        let hex = { (c: RGB) in String(format: "#%02X%02X%02X", c.r, c.g, c.b) }
        var poses: [String: Any] = [:]
        for action in Action.allCases { poses[action.rawValue] = entry(PixelSprites.animation(action)) }
        for pose in SpecialPose.allCases { poses[pose.rawValue] = entry(PixelSprites.special(pose)) }
        let tree = PixelTree.art(), bamboo = Bamboo.art(length: Bamboo.fullLength)
        let maple = PixelPalette(pack: .redPanda())
        let report: [String: Any] = [
            "side": PixelSprites.side, "poses": poses,
            // The Mac app's own palette for Maple's colors, so the site's port can be checked against it.
            "maplePalette": ["colors": maple.colors.reduce(into: [String: String]()) { $0[String($1.key)] = hex($1.value) },
                             "outline": hex(maple.outline), "softOutline": hex(maple.softOutline)],
            "tree": ["grid": grid(tree), "colors": PixelTree.palette.colors.reduce(into: [String: String]()) { $0[String($1.key)] = hex($1.value) },
                     "outline": hex(PixelTree.palette.outline)],
            "bamboo": ["grid": grid(bamboo), "colors": Bamboo.palette.colors.reduce(into: [String: String]()) { $0[String($1.key)] = hex($1.value) },
                       "outline": hex(Bamboo.palette.outline)],
        ]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]).write(to: folder.appendingPathComponent("panda-art.json"), options: .atomic)
        let palette = PixelPalette(pack: .redPanda())
        func png(_ art: PixelArt, _ palette: PixelPalette, scale: Int, name: String) throws {
            let image = pixelImage(palette.rgba(art), width: art.width, height: art.height)
            guard let context = CGContext(data: nil, width: art.width * scale, height: art.height * scale, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw EvidenceError.noBitmap }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: art.width * scale, height: art.height * scale))
            guard let out = context.makeImage(),
                  let data = NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:]) else { throw EvidenceError.noBitmap }
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
        try png(PixelSprites.animation(.sit).frames[0], palette, scale: 8, name: "panda-sit.png")
        try png(PixelSprites.animation(.walk).frames[0], palette, scale: 8, name: "panda-walk.png")
        try png(PixelSprites.special(.drape).frames[0], palette, scale: 8, name: "panda-drape.png")
        try png(tree, PixelTree.palette, scale: 4, name: "panda-tree.png")
        print("Site art: \(poses.count) poses as character grids, tree, bamboo and four PNGs.")
    }
}
