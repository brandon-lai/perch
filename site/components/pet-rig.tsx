import type { CSSProperties } from "react"
import type { PetTraits, Pose } from "@/lib/pack"
import { IMAGE_TOKENS } from "@/lib/design"

type RigColors = {
  coat: string
  ear: string
  marking: string
  ink: string
  heart: string
  bowl: string
  line: string
}

// Geometry mirrors native/Sources/Perch/Rig.swift, including its bottom-up paw anchor.
export function RigDrawing({
  traits,
  pose,
  colors,
}: {
  traits: PetTraits
  pose: Pose
  colors: RigColors
}) {
  const sleeping = pose === "sleep"
  const sitting = ["sit", "highFive", "peek", "feed"].includes(pose)
  const stretching = pose === "stretch"
  const bracing = pose === "ride"
  const bodyY = sleeping
    ? 13
    : sitting
      ? 12
      : stretching
        ? 19
        : bracing
          ? 23
          : 27
  const headY = sleeping ? 35 : stretching ? 43 : 73
  const headX = sleeping ? 108 : pose === "sniff" ? 113 : 104
  const scale =
    traits.size === "small" ? 0.78 : traits.size === "large" ? 1.18 : 1
  const oval = (
    x: number,
    y: number,
    width: number,
    height: number,
    color: string
  ) => (
    <ellipse
      cx={x + width / 2}
      cy={y + height / 2}
      rx={width / 2}
      ry={height / 2}
      fill={color}
    />
  )
  const rounded = (
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number,
    color: string
  ) => (
    <rect x={x} y={y} width={width} height={height} rx={radius} fill={color} />
  )
  return (
    <g
      transform={`translate(${80 * (1 - scale)} 144) scale(${scale} ${-scale})`}
    >
      <path
        className="pet-tail"
        d={`M44 ${bodyY + 17} C16 ${bodyY + 12} 14 ${bodyY + 41} 21 ${bodyY + (sleeping ? 12 : 42)}`}
        fill="none"
        stroke={colors.ear}
        strokeWidth={traits.species === "cat" ? 8 : 12}
        strokeLinecap="round"
        style={{ transformOrigin: `44px ${bodyY + 17}px` }}
      />
      {oval(
        sitting ? 41 : 36,
        bodyY,
        sleeping ? 79 : stretching ? 88 : sitting ? 65 : 76,
        sleeping ? 36 : sitting ? 61 : stretching ? 37 : 45,
        colors.coat
      )}
      {sleeping
        ? oval(86, 2, 30, 13, colors.coat)
        : [48, 67, 91, 110].map((x, index) => {
            const socks =
              traits.marking === "socks" || traits.marking === "tuxedo"
            if (sitting && index < 2)
              return (
                <g key={x}>
                  {oval(x - 7, 0, 28, 16, colors.coat)}
                  {socks && oval(x - 7, 0, 28, 8, colors.marking)}
                </g>
              )
            if (pose === "highFive" && index === 3)
              return <g key={x}>{rounded(x, 55, 12, 30, 6, colors.coat)}</g>
            const heldLift = pose === "held" ? 10 : 0
            return (
              <g key={x}>
                {rounded(
                  x - 6 + (bracing ? (index < 2 ? -5 : 5) : 0),
                  heldLift,
                  13,
                  Math.max(14, bodyY + (sitting ? 40 : 12) - heldLift),
                  6,
                  colors.coat
                )}
                {socks && rounded(x - 6, heldLift, 13, 10, 5, colors.marking)}
              </g>
            )
          })}
      {(traits.marking === "chest" || traits.marking === "tuxedo") &&
        oval(
          sleeping ? 84 : 94,
          bodyY + 3,
          19,
          sleeping ? 19 : 36,
          colors.marking
        )}
      {oval(headX - 25, headY - 17, 48, 43, colors.coat)}
      {traits.ears === "pointed" ? (
        <g fill={colors.ear}>
          <path
            d={`M${headX - 22} ${headY + 10} L${headX - 21} ${headY + 43} L${headX - 3} ${headY + 20}Z`}
          />
          <path
            d={`M${headX + 3} ${headY + 19} L${headX + 19} ${headY + 40} L${headX + 22} ${headY + 9}Z`}
          />
        </g>
      ) : (
        <g>
          {oval(
            headX - 29,
            headY - 7 + (pose === "look" ? 3 : 0),
            19,
            34,
            colors.ear
          )}
          {oval(headX + 12, headY - 2, 15, 29, colors.ear)}
        </g>
      )}
      {oval(
        headX - 7,
        headY - 13,
        traits.species === "dog" ? 32 : 24,
        22,
        colors.marking
      )}
      {sleeping || pose === "yawn" ? (
        <path
          d={`M${headX + 1} ${headY + 9} L${headX + 8} ${headY + 8}`}
          stroke={colors.ink}
          strokeWidth={2.5}
          strokeLinecap="round"
        />
      ) : (
        oval(headX + (pose === "look" ? 5 : 2), headY + 6, 5, 6, colors.ink)
      )}
      {oval(headX + 16, headY - 1, 7, 5, colors.ink)}
      {pose === "yawn" && oval(headX + 7, headY - 10, 7, 10, colors.ink)}
      {traits.species === "cat" && (
        <path
          d={`M${headX + 12} ${headY - 3} L${headX + 34} ${headY - 1} M${headX + 12} ${headY + 2} L${headX + 34} ${headY + 4}`}
          stroke={colors.ink}
          strokeWidth={1}
        />
      )}
      {pose === "fall" && (
        <path
          d="M52 117 L52 130 M70 123 L70 139"
          stroke={colors.line}
          strokeWidth={2}
        />
      )}
      {["pet", "react"].includes(pose) && (
        <g>
          {oval(74, 110, 8, 8, colors.heart)}
          {oval(80, 110, 8, 8, colors.heart)}
          <path d="M74 113 L88 113 L81 104Z" fill={colors.heart} />
        </g>
      )}
      {pose === "feed" && rounded(114, 0, 37, 14, 6, colors.bowl)}
      {pose === "play" && oval(129, 3, 18, 18, colors.bowl)}
      {sleeping && (
        <g transform="translate(128 76) scale(1 -1)">
          <text fill={colors.ink} fontSize={14}>
            z
          </text>
        </g>
      )}
    </g>
  )
}

export function PetRig({
  traits,
  pose = "idle",
  still = false,
}: {
  traits: PetTraits
  pose?: Pose
  still?: boolean
}) {
  const colors = {
    "--coat": traits.coat,
    "--ear": traits.earColor,
    "--marking": traits.markingColor,
  } as CSSProperties
  return (
    <svg
      className={`pet-rig pose-${pose} ${still ? "pet-still" : ""}`}
      style={colors}
      viewBox="0 0 160 144"
      role="img"
      aria-label={`${traits.name}, ${traits.species}, ${pose}`}
    >
      <RigDrawing
        traits={traits}
        pose={pose}
        colors={{
          coat: "var(--coat)",
          ear: "var(--ear)",
          marking: "var(--marking)",
          ink: "var(--pet-ink)",
          heart: "var(--pet-heart)",
          bowl: "var(--pet-bowl)",
          line: "var(--ledge)",
        }}
      />
    </svg>
  )
}

export const SOCIAL_RIG_COLORS: RigColors = {
  coat: IMAGE_TOKENS.coat,
  ear: IMAGE_TOKENS.ear,
  marking: IMAGE_TOKENS.marking,
  ink: IMAGE_TOKENS.ink,
  heart: IMAGE_TOKENS.heart,
  bowl: IMAGE_TOKENS.bowl,
  line: IMAGE_TOKENS.ledge,
}
