import { Button as ButtonPrimitive } from "@base-ui/react/button"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "cn"

// Perch: pill buttons that press to 0.96 (never when disabled, and only without reduced motion), with named,
// 150ms transitions and 2px less padding on a leading icon's side.
const buttonVariants = cva(
  "perch-button group/button inline-flex shrink-0 items-center justify-center rounded-full border border-transparent bg-clip-padding text-base font-semibold whitespace-nowrap no-underline select-none transition-[background-color,color,box-shadow,scale] duration-150 ease-out motion-safe:not-disabled:not-data-disabled:not-aria-[haspopup]:active:scale-[0.96] disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-[1.125em]",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground shadow-[var(--shadow-button)] hover:bg-primary-hover",
        outline:
          "bg-card text-foreground shadow-border hover:bg-secondary aria-expanded:bg-secondary",
        secondary:
          "bg-secondary text-secondary-foreground hover:bg-secondary-hover aria-expanded:bg-secondary-hover",
        ghost:
          "text-foreground hover:bg-secondary aria-expanded:bg-secondary",
        destructive:
          "bg-destructive/10 text-destructive hover:bg-destructive/20 focus-visible:border-destructive/40",
        // Sits flush with the text around it, as a link would.
        link: "px-0! text-link underline-offset-4 hover:underline",
      },
      size: {
        default: "min-h-11 gap-2 px-5 has-[>svg:first-child]:ps-4.5",
        xs: "h-7 gap-1 px-2.5 text-xs [&_svg:not([class*='size-'])]:size-3",
        sm: "min-h-10 gap-1.5 px-4 text-sm has-[>svg:first-child]:ps-3.5",
        lg: "min-h-13 gap-2.5 px-7 text-[1.0625rem] has-[>svg:first-child]:ps-6.5",
        icon: "size-11",
        "icon-xs": "size-7 [&_svg:not([class*='size-'])]:size-3",
        "icon-sm": "size-10",
        "icon-lg": "size-12",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  ...props
}: ButtonPrimitive.Props & VariantProps<typeof buttonVariants>) {
  return (
    <ButtonPrimitive
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
