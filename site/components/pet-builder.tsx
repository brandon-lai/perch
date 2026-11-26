"use client"

import { useEffect, useRef, useState, type FormEvent } from "react"
import Link from "next/link"
import { ArrowDownToLine, Check, RotateCcw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Playground } from "@/components/playground"
import {
  createPack,
  packFilename,
  RED_PANDA_COLORS,
  SAMPLE_PET,
  type PetTraits,
} from "@/lib/pack"

function Choice<T extends string>({
  id,
  label,
  value,
  options,
  onChange,
}: {
  id: string
  label: string
  value: T
  options: { value: T; label: string }[]
  onChange: (value: T) => void
}) {
  return (
    <div className="form-field">
      <label id={`${id}-label`} htmlFor={id}>
        {label}
      </label>
      <Select
        value={value}
        items={options}
        onValueChange={(next) => {
          if (next !== null) onChange(next)
        }}
      >
        <SelectTrigger id={id} aria-labelledby={`${id}-label`}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

export function PetBuilder() {
  const [traits, setTraits] = useState<PetTraits>({ ...SAMPLE_PET, name: "" })
  const [stage, setStage] = useState<"traits" | "ready">("traits")
  const [error, setError] = useState("")
  const [downloaded, setDownloaded] = useState(false)
  const nameInput = useRef<HTMLInputElement>(null)
  const heading = useRef<HTMLHeadingElement>(null)
  const first = useRef(true)
  function change<T extends keyof PetTraits>(key: T, value: PetTraits[T]) {
    setTraits((previous) => ({ ...previous, [key]: value }))
    setError("")
  }
  useEffect(() => {
    if (first.current) { first.current = false; return }
    heading.current?.focus()
  }, [stage])
  function confirm(event: FormEvent) {
    event.preventDefault()
    try {
      createPack(traits)
      setError("")
      setStage("ready")
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "The pack could not be created. Check the details and try again."
      )
      nameInput.current?.focus()
    }
  }
  function download() {
    try {
      const pack = createPack(traits)
      const url = URL.createObjectURL(
        new Blob([JSON.stringify(pack, null, 2)], { type: "application/json" })
      )
      const anchor = document.createElement("a")
      anchor.href = url
      anchor.download = packFilename(traits.name)
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      setDownloaded(true)
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "The download failed. Try saving the pack again."
      )
    }
  }
  const previewTraits = { ...traits, name: traits.name.trim() || "Your red panda" }
  return (
    <>
      <div className="builder-heading">
        <h1 tabIndex={-1} ref={heading}>
          {stage === "ready"
            ? `${traits.name.trim()}, meet your desktop.`
            : "Make your red panda."}
        </h1>
        <p>
          {stage === "ready"
            ? "A little pack, ready for the Mac app."
            : "Name it. Pick its colors. Same little face in every pose."}
        </p>
      </div>
      <div className="builder-grid">
        <aside className="builder-preview" aria-label="Live red panda preview">
          <Playground traits={previewTraits} compact />
          <p className="preview-note">
            The same pixel art as the Mac app,
            <br />
            in your colors.
          </p>
        </aside>
        <section className="builder-form">
          <p
            id="builder-error"
            className={error ? "error-message" : "sr-only"}
            role="alert"
          >
            {error}
          </p>
          {stage === "traits" && (
            <form onSubmit={confirm} noValidate>
              <h2>A few little details.</h2>
              <p>The preview updates as you choose.</p>
              <div className="form-field">
                <label htmlFor="pet-name">Its name</label>
                <Input
                  ref={nameInput}
                  id="pet-name"
                  name="pet-name"
                  autoComplete="off"
                  placeholder="Maple, Mochi, Ember…"
                  maxLength={40}
                  value={traits.name}
                  aria-invalid={!!error}
                  aria-describedby="builder-error"
                  onChange={(event) => change("name", event.target.value)}
                />
              </div>
              <fieldset className="color-fields">
                <legend>Its colors</legend>
                {(
                  [
                    { key: "coat", label: "Coat" },
                    { key: "earColor", label: "Legs and ears" },
                    { key: "markingColor", label: "Face mask" },
                  ] as const
                ).map(({ key, label }) => (
                  <label key={key} htmlFor={key}>
                    <input
                      id={key}
                      name={key}
                      type="color"
                      value={traits[key]}
                      onChange={(event) => change(key, event.target.value)}
                    />
                    <span>{label}</span>
                  </label>
                ))}
              </fieldset>
              <Button
                type="button"
                variant="ghost"
                className="sample-action"
                onClick={() => setTraits((previous) => ({ ...previous, ...RED_PANDA_COLORS }))}
              >
                <RotateCcw aria-hidden="true" />
                Use red panda colors
              </Button>
              <div className="field-pair">
                <Choice
                  id="size"
                  label="Size"
                  value={traits.size}
                  options={[
                    { value: "small", label: "Small" },
                    { value: "medium", label: "Medium" },
                    { value: "large", label: "Large" },
                  ]}
                  onChange={(value) => change("size", value)}
                />
                <Choice
                  id="temperament"
                  label="Its rhythm"
                  value={traits.temperament}
                  options={[
                    { value: "curious", label: "Curious and playful" },
                    { value: "calm", label: "Calm and unhurried" },
                  ]}
                  onChange={(value) => change("temperament", value)}
                />
              </div>
              <div className="form-actions">
                <Button type="submit">Keep this red panda</Button>
              </div>
            </form>
          )}
          {stage === "ready" && (
            <div className="ready-content">
              <Check className="ready-check" aria-hidden="true" />
              <h2>Ready to explore your windows.</h2>
              <p>
                Save the pack, then open it in Perch for Mac. You can change its
                colors whenever you like.
              </p>
              <Button type="button" onClick={download}>
                <ArrowDownToLine aria-hidden="true" />
                Save {traits.name.trim()}’s pack
              </Button>
              <p
                role="status"
                className={downloaded ? "success-message" : "sr-only"}
              >
                {downloaded
                  ? "Pack download started. Open Perch, then choose Import pack in Settings."
                  : ""}
              </p>
              <Link className="quiet-link" href="/download">
                Get the Mac app
              </Link>
              <Button
                type="button"
                variant="ghost"
                onClick={() => {
                  setStage("traits")
                  setDownloaded(false)
                }}
              >
                Change its details
              </Button>
              <p className="fine-print">
                The pack holds a name and colors. No account or payment. To give
                a red panda, share the pack file.
              </p>
            </div>
          )}
        </section>
      </div>
    </>
  )
}
