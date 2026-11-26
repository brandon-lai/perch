"use client"

import {
  useEffect,
  useCallback,
  useRef,
  useState,
  type CSSProperties,
  type PointerEvent,
} from "react"
import { Bone, Hand, Moon, Pause, Play, Move } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { PetRig } from "@/components/pet-rig"
import { SAMPLE_PET, type PetTraits, type Pose } from "@/lib/pack"

export function Playground({
  compact = false,
  traits = SAMPLE_PET,
}: {
  compact?: boolean
  traits?: PetTraits
}) {
  const [pose, setPose] = useState<Pose>("idle")
  const [paused, setPaused] = useState(false)
  const [position, setPosition] = useState({ x: 0, y: 0 })
  const [petOffset, setPetOffset] = useState({ x: 0, y: 0 })
  const [grounded, setGrounded] = useState(false)
  const [landing, setLanding] = useState({ x: 0, y: 0 })
  const displayedOffset = grounded
    ? { x: landing.x - position.x, y: landing.y - position.y }
    : petOffset
  const [falling, setFalling] = useState(false)
  const [onScreen, setOnScreen] = useState(true)
  const rootRef = useRef<HTMLDivElement>(null)
  const spaceRef = useRef<HTMLDivElement>(null)
  const shapeKey = useRef(`${traits.size}/${traits.species}/${traits.ears}`)
  const didMove = useRef(false)
  const surfaceRef = useRef<HTMLButtonElement>(null)
  const petRef = useRef<HTMLButtonElement>(null)
  const groundRef = useRef<HTMLDivElement>(null)
  const detached = useRef(false)
  const drag = useRef<{
    x: number
    y: number
    px: number
    py: number
    lastX: number
    lastY: number
    time: number
    kind: "surface" | "pet"
    wasGrounded: boolean
  } | null>(null)
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [dragging, setDragging] = useState(false)

  function clearAction() {
    if (timeout.current) clearTimeout(timeout.current)
  }
  function action(next: Pose) {
    clearAction()
    setFalling(false)
    setPetOffset({ x: 0, y: 0 })
    setPose(next)
    if (next !== "sleep")
      timeout.current = setTimeout(() => setPose("idle"), 2400)
  }
  useEffect(
    () => () => {
      if (timeout.current) clearTimeout(timeout.current)
    },
    []
  )
  useEffect(() => {
    const root = rootRef.current
    if (!root) return
    const observer = new IntersectionObserver(([entry]) =>
      setOnScreen(entry.isIntersecting)
    )
    observer.observe(root)
    return () => observer.disconnect()
  }, [])

  const resetPosition = useCallback((wake = true) => {
    if (timeout.current) clearTimeout(timeout.current)
    drag.current = null
    setDragging(false)
    setPosition({ x: 0, y: 0 })
    setPetOffset({ x: 0, y: 0 })
    setFalling(false)
    setGrounded(false)
    setPose((previous) => (!wake && previous === "sleep" ? "sleep" : "idle"))
  }, [])

  useEffect(() => {
    const space = spaceRef.current
    if (!space) return
    const nextShape = `${traits.size}/${traits.species}/${traits.ears}`
    const changedShape = nextShape !== shapeKey.current
    shapeKey.current = nextShape
    let first = true
    const observer = new ResizeObserver(() => {
      if (first && !changedShape) {
        first = false
        return
      }
      first = false
      resetPosition(false)
    })
    observer.observe(space)
    return () => observer.disconnect()
  }, [resetPosition, traits.size, traits.species, traits.ears])

  function cancel() {
    resetPosition()
  }

  function constrain(
    next: { x: number; y: number },
    target: "surface" | "pet"
  ) {
    const space = spaceRef.current?.getBoundingClientRect()
    const shape = petRef.current
      ?.querySelector("svg > g")
      ?.getBoundingClientRect()
    const surface = surfaceRef.current?.getBoundingClientRect()
    const pet = petRef.current?.getBoundingClientRect()
    const floor = groundRef.current?.getBoundingClientRect()
    if (!space || !shape || !surface || !pet || !floor)
      throw new Error("The pet preview surface is unavailable.")
    const viewport = space
    const current = target === "pet" ? displayedOffset : position
    function bounds(rect: DOMRect, padding: number) {
      return {
        minX: current.x + viewport.left + padding - rect.left,
        maxX: current.x + viewport.right - padding - rect.right,
        minY: current.y + viewport.top + padding - rect.top,
        maxY: current.y + viewport.bottom - padding - rect.bottom,
      }
    }
    const range = bounds(
      target === "pet" ? shape : surface,
      target === "pet" ? 16 : 8
    )
    if (target === "surface" && !grounded) {
      const petRange = bounds(shape, 16)
      range.minX = Math.max(range.minX, petRange.minX)
      range.maxX = Math.min(range.maxX, petRange.maxX)
      range.minY = Math.max(range.minY, petRange.minY)
      range.maxY = Math.min(range.maxY, petRange.maxY)
    }
    if (target === "pet")
      range.maxY = Math.min(range.maxY, current.y + floor.top - pet.bottom)
    return {
      x: Math.max(range.minX, Math.min(range.maxX, next.x)),
      y: Math.max(range.minY, Math.min(range.maxY, next.y)),
    }
  }
  function start(
    event: PointerEvent<HTMLButtonElement>,
    kind: "surface" | "pet"
  ) {
    if (event.button !== 0 || paused) return
    clearAction()
    didMove.current = false
    detached.current = false
    event.currentTarget.setPointerCapture(event.pointerId)
    drag.current = {
      x: event.clientX,
      y: event.clientY,
      px: kind === "pet" ? displayedOffset.x : position.x,
      py: kind === "pet" ? displayedOffset.y : position.y,
      lastX: event.clientX,
      lastY: event.clientY,
      time: event.timeStamp,
      kind,
      wasGrounded: grounded,
    }
    if (kind === "pet") {
      setPetOffset(displayedOffset)
      setGrounded(false)
    }
    setDragging(true)
    setFalling(false)
    setPose(kind === "pet" ? "held" : grounded ? "idle" : "ride")
  }
  function move(event: PointerEvent<HTMLButtonElement>) {
    const current = drag.current
    if (!current) return
    const dx = event.clientX - current.x
    const dy = event.clientY - current.y
    if (Math.abs(dx) + Math.abs(dy) > 4) didMove.current = true
    const next = constrain(
      { x: current.px + dx, y: current.py + dy },
      current.kind
    )
    if (current.kind === "pet") setPetOffset(next)
    else setPosition(next)
    const speed =
      Math.hypot(event.clientX - current.lastX, event.clientY - current.lastY) /
      Math.max(1, event.timeStamp - current.time)
    if (current.kind === "surface" && !grounded && speed > 1.1)
      detached.current = true
    current.lastX = event.clientX
    current.lastY = event.clientY
    current.time = event.timeStamp
  }
  function end(event: PointerEvent<HTMLButtonElement>) {
    const current = drag.current
    if (!current) return
    if (event.currentTarget.hasPointerCapture(event.pointerId))
      event.currentTarget.releasePointerCapture(event.pointerId)
    drag.current = null
    setDragging(false)
    if (current.kind === "pet" && !didMove.current) {
      setGrounded(current.wasGrounded)
      action("pet")
      return
    }
    if (current.kind === "pet" || detached.current) drop()
    else setPose("idle")
  }
  function drop() {
    const floor = groundRef.current?.getBoundingClientRect()
    const pet = petRef.current?.getBoundingClientRect()
    if (!floor || !pet)
      throw new Error("The pet preview surface is unavailable.")
    setLanding({
      x: position.x + displayedOffset.x,
      y: position.y + displayedOffset.y + floor.top - pet.bottom,
    })
    setPetOffset(displayedOffset)
    setGrounded(false)
    clearAction()
    setFalling(true)
    setPose("fall")
    timeout.current = setTimeout(() => {
      setFalling(false)
      setGrounded(true)
      setPetOffset({ x: 0, y: 0 })
      setPose("shake")
      timeout.current = setTimeout(() => setPose("idle"), 650)
    }, 500)
  }
  function nudge(
    dx: number,
    dy: number,
    target: "surface" | "pet" = "surface"
  ) {
    if (target === "surface") {
      const next = constrain(
        { x: position.x + dx, y: position.y + dy },
        "surface"
      )
      clearAction()
      setFalling(false)
      setPose(grounded ? "idle" : pose === "held" ? "held" : "ride")
      setPosition(next)
    } else {
      clearAction()
      setFalling(false)
      setPose("held")
      setGrounded(false)
      setPetOffset(
        constrain(
          { x: displayedOffset.x + dx, y: displayedOffset.y + dy },
          "pet"
        )
      )
    }
  }

  return (
    <div
      ref={rootRef}
      className={`playground ${compact ? "compact" : ""} ${paused ? "paused" : ""}`}
      data-pose={pose}
      data-dragging={dragging}
      data-grounded={grounded}
    >
      <div className="play-space" ref={spaceRef}>
        <div
          className={`moving-perch ${dragging ? "is-dragging" : ""}`}
          style={{ transform: `translate(${position.x}px, ${position.y}px)` }}
        >
          <button
            type="button"
            ref={petRef}
            className={`pet-hit ${falling ? "is-falling" : ""}`}
            style={
              {
                "--pet-x": `${displayedOffset.x}px`,
                "--pet-y": `${displayedOffset.y}px`,
                "--drop-y": `${landing.y - position.y}px`,
              } as CSSProperties
            }
            aria-label={`${traits.name}: pet or drag ${traits.species === "cat" ? "them" : "your dog"}`}
            onPointerDown={(event) => start(event, "pet")}
            onPointerMove={move}
            onPointerUp={end}
            onPointerCancel={cancel}
            onClick={(event) => {
              if (event.detail === 0) action("pet")
            }}
            onKeyDown={(event) => {
              if (event.key === "Escape") cancel()
            }}
            disabled={paused}
          >
            <PetRig
              traits={traits}
              pose={pose}
              still={paused || !onScreen || traits.temperament === "calm"}
            />
          </button>
          <button
            type="button"
            ref={surfaceRef}
            className="perch-surface"
            aria-label="Move the perch: drag, or use arrow keys"
            onPointerDown={(event) => start(event, "surface")}
            onPointerMove={move}
            onPointerUp={end}
            onPointerCancel={cancel}
            onKeyDown={(event) => {
              if (event.key === "Escape") {
                cancel()
                return
              }
              if (
                !["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(
                  event.key
                )
              )
                return
              event.preventDefault()
              nudge(
                event.key === "ArrowLeft"
                  ? -12
                  : event.key === "ArrowRight"
                    ? 12
                    : 0,
                event.key === "ArrowUp"
                  ? -12
                  : event.key === "ArrowDown"
                    ? 12
                    : 0
              )
            }}
            disabled={paused}
          >
            <span />
            <span />
          </button>
        </div>
        <div className="ground-line" ref={groundRef} />
      </div>
      <div className="play-controls" aria-label="Pet actions">
        <Button
          type="button"
          variant="ghost"
          onClick={() => action("pet")}
          disabled={paused}
        >
          <Hand aria-hidden="true" />
          <span>Pet</span>
        </Button>
        <Button
          type="button"
          variant="ghost"
          onClick={() => action("feed")}
          disabled={paused}
        >
          <Bone aria-hidden="true" />
          <span>Snack</span>
        </Button>
        <Button
          type="button"
          variant="ghost"
          onClick={() => {
            clearAction()
            setPose(pose === "sleep" ? "idle" : "sleep")
          }}
          disabled={paused}
        >
          <Moon aria-hidden="true" />
          <span>{pose === "sleep" ? "Wake" : "Nap"}</span>
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          aria-label={paused ? "Resume animation" : "Pause animation"}
          aria-pressed={paused}
          onClick={() => {
            clearAction()
            drag.current = null
            setDragging(false)
            setFalling(false)
            setPetOffset({ x: 0, y: 0 })
            if (pose !== "sleep") setPose("idle")
            setPaused(!paused)
          }}
        >
          {paused ? <Play aria-hidden="true" /> : <Pause aria-hidden="true" />}
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger
            render={
              <Button
                type="button"
                variant="ghost"
                size="icon"
                aria-label="Move the pet or perch"
                disabled={paused}
              />
            }
          >
            <Move aria-hidden="true" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuGroup>
              <DropdownMenuItem onClick={() => nudge(-12, 0)}>
                Move perch left
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => nudge(12, 0)}>
                Move perch right
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => nudge(0, -12)}>
                Raise perch
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => nudge(0, 12)}>
                Lower perch
              </DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
              <DropdownMenuItem onClick={() => nudge(-12, 0, "pet")}>
                Move pet left
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => nudge(12, 0, "pet")}>
                Move pet right
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => nudge(0, -24, "pet")}>
                Lift pet
              </DropdownMenuItem>
              <DropdownMenuItem onClick={drop}>Drop pet</DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={cancel}>Reset perch</DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
      <p className="play-state" role="status">
        {paused
          ? "Paused"
          : pose === "sleep"
            ? `${traits.name} is taking a little nap.`
            : pose === "held"
              ? `Holding ${traits.name}. Choose Drop pet in the Move menu.`
              : pose === "ride"
                ? "Right here with you."
                : pose === "fall"
                  ? "Finding those feet again."
                  : pose === "pet"
                    ? "That’s the spot."
                    : pose === "feed"
                      ? "A little snack, a happy pet."
                      : `${traits.name} is keeping you company.`}
      </p>
    </div>
  )
}
