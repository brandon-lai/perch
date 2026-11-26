"use client"

import { useEffect, useRef, useState, type FormEvent } from "react"
import Image from "next/image"
import Link from "next/link"
import { ArrowDownToLine, Check, ImagePlus, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Checkbox } from "@/components/ui/checkbox"
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
  SAMPLE_PET,
  validatePhotos,
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
  const [stage, setStage] = useState<"photos" | "traits" | "ready">("photos")
  const [photos, setPhotos] = useState<{ url: string; name: string }[]>([])
  const [error, setError] = useState("")
  const [busy, setBusy] = useState(false)
  const [downloaded, setDownloaded] = useState(false)
  const urls = useRef<string[]>([])
  const input = useRef<HTMLInputElement>(null)
  const nameInput = useRef<HTMLInputElement>(null)
  const heading = useRef<HTMLHeadingElement>(null)
  const loadGeneration = useRef(0)
  function change<T extends keyof PetTraits>(key: T, value: PetTraits[T]) {
    setTraits((previous) => ({ ...previous, [key]: value }))
    setError("")
  }
  useEffect(
    () => () => {
      loadGeneration.current++
      urls.current.forEach((url) => URL.revokeObjectURL(url))
    },
    []
  )
  useEffect(() => {
    if (stage !== "photos") heading.current?.focus()
  }, [stage])

  function clearPhotos() {
    loadGeneration.current++
    urls.current.forEach((url) => URL.revokeObjectURL(url))
    urls.current = []
    setPhotos([])
    setBusy(false)
    if (input.current) input.current.value = ""
  }
  async function choosePhotos(files: FileList | null) {
    if (!files) return
    const chosen = [...files]
    setError("")
    clearPhotos()
    const generation = ++loadGeneration.current
    setBusy(true)
    try {
      validatePhotos(chosen)
      for (const file of chosen) {
        const decoded = await createImageBitmap(file)
        decoded.close()
      }
      if (generation !== loadGeneration.current) return
      const next = chosen.map((file) => ({
        url: URL.createObjectURL(file),
        name: file.name,
      }))
      urls.current = next.map((photo) => photo.url)
      setPhotos(next)
    } catch (cause) {
      if (generation !== loadGeneration.current) return
      setError(
        cause instanceof DOMException
          ? "A photo could not be opened. Try a different JPG or PNG file."
          : cause instanceof Error
            ? cause.message
            : "These photos could not be opened. Try JPG or PNG files."
      )
      input.current?.focus()
    } finally {
      if (generation === loadGeneration.current) setBusy(false)
    }
  }
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
          : "The pet pack could not be created. Check the traits and try again."
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
  const previewTraits = { ...traits, name: traits.name.trim() || "Your pet" }
  return (
    <>
      <div className="builder-heading">
        <h1 tabIndex={-1} ref={heading}>
          {stage === "ready"
            ? `${traits.name.trim()}, meet Perch.`
            : "Make your little companion."}
        </h1>
        <p>
          {stage === "ready"
            ? "A consistent pet pack, ready for the Mac app."
            : "Their colors. Their ears. That familiar little face."}
        </p>
      </div>
      <div className="builder-grid">
        <aside className="builder-preview" aria-label="Live pet preview">
          <Playground traits={previewTraits} compact />
          <p className="preview-note">
            Live template preview.
            <br />
            Same markings, in every pose.
          </p>
          {photos.length > 0 && (
            <div
              className="photo-strip"
              aria-label="Your local reference photos"
            >
              {photos.map((photo, index) => (
                <Image
                  key={photo.url}
                  src={photo.url}
                  alt={`Reference photo ${index + 1}`}
                  width={72}
                  height={72}
                  unoptimized
                />
              ))}
            </div>
          )}
        </aside>
        <section className="builder-form">
          <p
            id="builder-error"
            className={error ? "error-message" : "sr-only"}
            role="alert"
          >
            {error}
          </p>
          {stage === "photos" && (
            <>
              <h2>Start with a few photos.</h2>
              <p>
                A side view, a front view, and one of their face. Choose 3 to 10
                photos.
              </p>
              <label className="photo-picker" htmlFor="photos">
                <ImagePlus aria-hidden="true" />
                <span role="status">
                  {busy
                    ? "Opening your photos…"
                    : photos.length
                      ? `${photos.length} photos chosen`
                      : "Choose your pet’s photos"}
                </span>
                <span className="fine-print">
                  JPG, PNG or WebP, under 15 MB each
                </span>
              </label>
              <input
                ref={input}
                id="photos"
                name="photos"
                type="file"
                multiple
                accept="image/jpeg,image/png,image/webp"
                className="file-input"
                aria-describedby="photo-privacy builder-error"
                aria-invalid={!!error}
                onChange={(event) => void choosePhotos(event.target.files)}
                disabled={busy}
              />
              <p id="photo-privacy" className="fine-print">
                Nothing is uploaded. Photos are a local reference for the traits
                you choose next.
              </p>
              <div className="form-actions">
                <Button
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    if (photos.length < 3) {
                      setError(
                        "Choose 3 to 10 photos before continuing, or try a sample pet."
                      )
                      input.current?.focus()
                      return
                    }
                    setStage("traits")
                  }}
                >
                  {busy ? "Opening photos…" : "Choose their traits"}
                </Button>
                {photos.length > 0 && (
                  <Button type="button" variant="ghost" onClick={clearPhotos}>
                    <Trash2 aria-hidden="true" />
                    Remove photos
                  </Button>
                )}
              </div>
              <Button
                type="button"
                variant="link"
                className="sample-action"
                onClick={() => {
                  clearPhotos()
                  setTraits(SAMPLE_PET)
                  setStage("traits")
                  setError("")
                }}
              >
                Try a sample pet without photos
              </Button>
            </>
          )}
          {stage === "traits" && (
            <form onSubmit={confirm} noValidate>
              <h2>Those little details matter.</h2>
              <p>
                Match their coat and markings. The preview updates as you
                choose.
              </p>
              <div className="form-field">
                <label htmlFor="pet-name">Their name</label>
                <Input
                  ref={nameInput}
                  id="pet-name"
                  name="pet-name"
                  autoComplete="off"
                  placeholder="Your pet’s name"
                  maxLength={40}
                  value={traits.name}
                  aria-invalid={!!error}
                  aria-describedby="builder-error"
                  onChange={(event) => change("name", event.target.value)}
                />
              </div>
              <div className="field-pair">
                <Choice
                  id="species"
                  label="Species"
                  value={traits.species}
                  options={[
                    { value: "dog", label: "Dog" },
                    { value: "cat", label: "Cat" },
                  ]}
                  onChange={(value) => {
                    change("species", value)
                    change("ears", value === "cat" ? "pointed" : "floppy")
                  }}
                />
                <Choice
                  id="size"
                  label="Body size"
                  value={traits.size}
                  options={[
                    { value: "small", label: "Small" },
                    { value: "medium", label: "Medium" },
                    { value: "large", label: "Large" },
                  ]}
                  onChange={(value) => change("size", value)}
                />
              </div>
              <fieldset className="color-fields">
                <legend>Coat colors</legend>
                {(
                  [
                    { key: "coat", label: "Coat" },
                    { key: "earColor", label: "Ears" },
                    { key: "markingColor", label: "Marking" },
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
              <div className="field-pair">
                <Choice
                  id="ears"
                  label="Ear shape"
                  value={traits.ears}
                  options={[
                    { value: "floppy", label: "Floppy" },
                    { value: "pointed", label: "Pointed" },
                  ]}
                  onChange={(value) => change("ears", value)}
                />
                <Choice
                  id="marking"
                  label="Markings"
                  value={traits.marking}
                  options={[
                    { value: "none", label: "Solid coat" },
                    { value: "chest", label: "Chest spot" },
                    { value: "socks", label: "Little socks" },
                    { value: "tuxedo", label: "Tuxedo chest" },
                  ]}
                  onChange={(value) => change("marking", value)}
                />
              </div>
              <Choice
                id="temperament"
                label="Their rhythm"
                value={traits.temperament}
                options={[
                  { value: "curious", label: "Curious and playful" },
                  { value: "calm", label: "Calm and unhurried" },
                ]}
                onChange={(value) => change("temperament", value)}
              />
              <label className="checkbox-row" htmlFor="remembrance">
                <Checkbox
                  id="remembrance"
                  checked={traits.remembrance}
                  onCheckedChange={(value) => change("remembrance", value)}
                />
                <span>
                  A companion to remember
                  <br />
                  <span className="fine-print">
                    Optional, quieter wording. No reminders.
                  </span>
                </span>
              </label>
              <div className="form-actions">
                <Button type="submit">Keep this little pet</Button>
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() => {
                    setStage("photos")
                    setError("")
                  }}
                >
                  Back to photos
                </Button>
              </div>
            </form>
          )}
          {stage === "ready" && (
            <div className="ready-content">
              <Check className="ready-check" aria-hidden="true" />
              <h2>
                {traits.remembrance
                  ? "A familiar kind of company."
                  : "Ready to find a window sill."}
              </h2>
              <p>
                Save the pack, then open it in Perch for Mac. You can change
                their traits whenever you like.
              </p>
              <Button type="button" onClick={download}>
                <ArrowDownToLine aria-hidden="true" />
                Save {traits.name.trim()}’s pet pack
              </Button>
              <p
                role="status"
                className={downloaded ? "success-message" : "sr-only"}
              >
                {downloaded
                  ? "Pack download started. Open Perch, then choose Import pet pack in Settings."
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
                Tweak their traits
              </Button>
              {photos.length > 0 && (
                <Button type="button" variant="ghost" onClick={clearPhotos}>
                  <Trash2 aria-hidden="true" />
                  Remove local photos
                </Button>
              )}
              <p className="fine-print">
                Only traits are in the pack. No photos, account, or payment. To
                give a pet, share the pack file.
              </p>
            </div>
          )}
        </section>
      </div>
    </>
  )
}
