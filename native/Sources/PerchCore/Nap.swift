import Foundation

/// A nap. Red pandas doze on and off through the day, stretched out along a branch or curled up; this one
/// picks the top edge of a window (its branch), its tree, or wherever it is. It wakes by itself, when woken, or
/// when the bamboo is held under its nose.
struct Nap: Equatable, Sendable {
    enum Stage: Equatable, Sendable { case looking, settling(until: Double), asleep, waking(since: Double) }
    enum Place: Equatable, Sendable { case here, tree, top(Point) }
    var stage: Stage = .looking
    /// When it wakes by itself; a nap asked for from the menu lasts until it's woken.
    var until: Double
    var since: Double
    var place: Place?
    /// Tries at getting somewhere better before it settles for where it is, and whether it's on its way.
    var tries = 0
    var sent = false
    /// You woke it: it stays up a while and comes to play.
    var woken = false
    /// Since when the bamboo has been held under its nose, and when it last smelled it there.
    var sniffSince: Double?
    var sniffedAt = -10.0
}

extension PetEngine {
    /// Napping, or on its way to a nap.
    public var napping: Bool { nap != nil }
    /// Has just been carried along on its window while asleep, so the app should keep a close eye for a moment.
    public var recentlyCarried: Bool { clock - lastCarried < 1.5 }
    /// What floats over it while it sleeps: z's, or a heart when it's petted in its sleep.
    public var bubble: PixelSprites.Bubble? {
        if dozing && (state == .held || state == .fall) { return .zs }
        guard state == .sleep, !bed else { return nil }
        return clock < snuggleUntil ? .heart : .zs
    }

    /// From the menu: settle down for a nap now, and sleep until woken.
    public mutating func takeNap() {
        guard state != .held else { return }
        if bed { setBed(false) }
        if holdingCursor { dropFromCursor() }
        if cursorPlay != nil { endCursorPlay() }
        endTrick(); lounge = nil; errand = nil; ball = nil
        nap = Nap(until: .infinity, since: clock)
        if state == .sleep { nap?.stage = .asleep; nap?.place = .here }
    }

    /// Wakes it gently, with a stretch: from a nap, from its bedtime sleep (for five minutes), or from bed.
    public mutating func wakeUp() {
        if bed { setBed(false); return }
        overrideUntil = clock + 300; snuggleUntil = 0; stirUntil = 0
        if var job = nap {
            switch job.stage {
            case .waking: return
            case .looking: finishNap(woken: true)
            case .settling, .asleep: job.stage = .waking(since: clock); job.woken = true; nap = job; change(.idle, .stretch)
            }
        } else if state == .sleep { change(.idle, .stretch); actionRemaining = 1.5 }
    }

    /// Sleepy: off for a long rest, five to ten minutes.
    mutating func startNap() {
        lounge = nil; errand = nil
        nap = Nap(until: clock + 300 + pick() * 300, since: clock)
    }

    /// Up again. Woken by you, it stays up a few minutes and comes for the bamboo; waking by itself, it has a short
    /// wander, and now and then comes to see you too.
    mutating func finishNap(woken: Bool = false) {
        let woken = woken || nap?.woken == true
        nap = nil; snuggleUntil = 0; stirUntil = 0
        if woken {
            nextNap = clock + 150 + pick() * 90
            nextCursorPlay = clock + 1.5
        } else {
            nextNap = clock + 75 + pick() * 75
            nextCursorPlay = pick() < 0.35 ? clock + 4 : max(nextCursorPlay, clock + 20)
        }
        nextChoice = 0; elapsed = 0
        if state == .sleep || state == .idle { change(.idle, .idle) }
    }

    /// The nap is off (picked up, sent somewhere, bedtime): not sleepy again for a minute or two.
    mutating func dropNap() {
        guard nap != nil else { return }
        nap = nil; snuggleUntil = 0; stirUntil = 0
        nextNap = max(nextNap, clock + 60 + pick() * 60)
    }

    /// Jolted awake by a fall or a fling: it'll try again in a couple of minutes.
    mutating func startledFromNap() {
        guard let job = nap, job.stage != .looking else { return }
        nap = nil; snuggleUntil = 0; stirUntil = 0
        // It soon looks for somewhere else to rest.
        nextNap = clock + 20 + pick() * 20
    }

    /// The pose for sleeping where it is: draped over a ledge or sprawled on the floor, peeking when the pointer
    /// comes close, and snuggling in when it's petted.
    var sleepingPose: SpecialPose {
        let ledge = support?.kind == .window || support?.kind == .branch
        if clock < snuggleUntil { return ledge ? .drapeSnuggle : .sprawlSnuggle }
        if clock < stirUntil { return ledge ? .drapeStir : .sprawlStir }
        return ledge ? .drape : .sprawl
    }

    /// Roughly where its nose is while it sleeps.
    var sleepingNose: Point {
        let ledge = support?.kind == .window || support?.kind == .branch
        return Point(position.x + direction * bodyHalfWidth * 0.85, position.y + bodyHalfWidth * (ledge ? 0.35 : 0.45))
    }

    /// The pointer near its nose makes it peek; returns whether it's there.
    mutating func sniff(_ cursor: Point?) -> Bool {
        guard let cursor, state == .sleep else { return false }
        let nose = sleepingNose
        guard hypot(cursor.x - nose.x, cursor.y - nose.y) < bodyHalfWidth * 1.3 else { return false }
        stirUntil = clock + 0.5
        return true
    }

    /// With a nap in mind, out of its tree: find a spot, lie down and sleep. Returns true when it used this tick.
    mutating func tendNap(on surface: Surface, surfaces: [Surface], windows: [DesktopWindow], screens: [Rect],
                          tree: TreeHome?, cursor: Point?, dt: Double, still: Bool) -> Bool {
        guard var job = nap else { return false }
        // Petted or startled on the way: that plays out first.
        if state == .react && actionRemaining > 0 { return false }
        if job.stage == .looking {
            let roomy = surface.kind == .window && surface.right - surface.left >= bodyHalfWidth * 2.6
            if job.place == nil {
                // The top of a window is its favourite branch; its tree is the other.
                let top = job.tries < 2 ? napTop(surfaces: surfaces, screens: screens, windows: windows) : nil
                if roomy { job.place = .here }
                else if let top, tree == nil || pick() < 0.8 { job.place = .top(top) }
                else if tree != nil { job.place = .tree }
                else { job.place = .here }
                job.tries += 1
            }
            switch job.place {
            case .tree:
                guard tree != nil else { job.place = nil; nap = job; return false }
                // The visit lasts as long as the nap does: however the nap ends, it climbs back down.
                nap = job
                visitTree(for: 0)
                return true
            case .top(let target):
                if roomy && abs(surface.y - target.y) < 1 { job.place = .here; break }
                if errand == nil {
                    if job.sent {
                        // It got somewhere else, or gave up on the way: think again, or settle for here.
                        job.sent = false
                        job.place = clock - job.since > 45 || job.tries >= 2 ? .here : nil
                        if job.place == nil { nap = job; return false }
                        break
                    }
                    errand = Errand(target: target, until: clock + 30); job.sent = true
                }
                nap = job
                _ = tendErrand(on: surface, surfaces: surfaces, windows: windows, dt: dt)
                return true
            case .here, nil:
                break
            }
            // Out along its ledge, clear of the corners, then a yawn and down it goes.
            let inset = min(bodyHalfWidth * 1.2, (surface.right - surface.left) / 2)
            let spot = min(max(position.x, surface.left + inset), surface.right - inset)
            if abs(position.x - spot) > 1 && !still {
                direction = spot > position.x ? 1 : -1; change(.walk, .walk)
                position.x += direction * min(abs(spot - position.x), 34 * dt)
                nap = job; return true
            }
            job.stage = .settling(until: clock + (still ? 0 : 1.6))
            lounge = nil; change(.idle, .yawn)
        }
        nap = job
        return tendNapHere(cursor: cursor, dt: dt, still: still)
    }

    /// Settling, asleep or waking up where it is (a window's top, the floor, or its branch). Returns false once
    /// the nap is over.
    mutating func tendNapHere(cursor: Point?, dt: Double, still: Bool) -> Bool {
        guard var job = nap else { return false }
        switch job.stage {
        case .looking:
            job.stage = .settling(until: clock + (still ? 0 : 1.6)); change(.idle, .yawn)
        case .settling(let until):
            if clock >= until { job.stage = .asleep; change(.sleep, .sleep) } else { change(.idle, .yawn) }
        case .asleep:
            change(.sleep, .sleep)
            if clock >= job.until { job.stage = .waking(since: clock); change(.idle, .stretch); break }
            // The bamboo held under its nose: a sniff, a twitch, and it's up for a snack. A bare pointer just
            // makes it peek.
            let snack = bambooPointer && mischief.cursor && bamboo >= 0.6 && !still
            if sniff(cursor) && snack {
                job.sniffSince = job.sniffSince ?? clock; job.sniffedAt = clock
            } else if clock - job.sniffedAt > 0.75 { job.sniffSince = nil }
            if let since = job.sniffSince, clock - since >= 2, clock - job.sniffedAt < 0.01, let cursor {
                finishNap(woken: true)
                treeActivity = .exploring; treeVisitUntil = 0
                cursorPlay = CursorPlay(phase: .notice(until: clock + 0.4), until: clock + 25)
                direction = cursor.x >= position.x ? 1 : -1
                change(.idle, .look)
                return true
            }
        case .waking(let since):
            // A long stretch, a yawn, a quick wash, and off it goes.
            let t = clock - since
            if still || t >= 5.4 { finishNap(); return false }
            if t < 1.4 { change(.idle, .stretch) } else if t < 2.6 { change(.idle, .yawn) } else { change(.idle, .sit); trickPose = .groom }
        }
        nap = job
        return true
    }

    /// A window top on its display with room to stretch out along, that it has a way up to.
    func napTop(surfaces: [Surface], screens: [Rect], windows: [DesktopWindow]) -> Point? {
        guard let here = screen(of: position, in: screens) else { return nil }
        let inset = bodyHalfWidth * 1.2
        let tops = surfaces.filter {
            $0.kind == .window && $0.right - $0.left >= bodyHalfWidth * 2.6 &&
                here.contains(Point(($0.left + $0.right) / 2, $0.y)) && $0.y + bodyHalfWidth * 2 <= here.maxY &&
                canClimb(onto: $0, surfaces: surfaces, windows: windows)
        }
        func spot(_ top: Surface) -> Point { Point(min(max(position.x, top.left + inset), top.right - inset), top.y) }
        return tops.map(spot).min { hypot($0.x - position.x, $0.y - position.y) < hypot($1.x - position.x, $1.y - position.y) }
    }
}
