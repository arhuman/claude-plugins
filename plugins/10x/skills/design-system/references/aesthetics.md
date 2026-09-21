# Aesthetic Direction

## Design thinking, before coding

Define purpose, audience/state of mind, constraints and one memorable feature. Commit to one product-specific tone. Match effort to it: maximalism needs deliberate motion/layering; minimalism needs precise spacing/type.

## Where identity lives in this system

Typography, palette, radii, motion and signature details belong in tokens/theme deltas. Compose layout through primitive parameters, never ad-hoc CSS or extra breakpoints. New visual value means new token.

## Typography

Pair a characterful display face with refined body type; avoid generic or overused identity fonts. Use self-hosted woff2, `unicode-range`, `font-display: swap`, font tokens and fluid `clamp()` scale. Express identity through face/weight/spacing/case, not one-off sizes.

## Color

Choose a cohesive dominant palette with sharp accents; avoid evenly weighted or context-free cliche schemes (purple gradients on white). Semantic tokens only; derived shades use `color-mix()`. Apply measured WCAG 2.1 AA in light and dark per `accessibility-i18n.md`.

## Motion

CSS-only: one or two high-impact moments, optionally staggered reveals, rather than constant movement. Follow `components.md` for all four interactive states, token durations/easing, `backwards` fill and global reduced-motion handling.

## Backgrounds and visual details

Use deliberate depth (textures, gradients, patterns, transparency, shadows, borders) when it supports the direction. Self-contained inline SVG/CSS/data URIs only; no external assets or authenticated-page third-party calls. Validate in every shipped theme.

## Anti-generic checklist

Reject generic identity fonts, palettes without a dominant, cliche gradients, unconsidered hero/cards/footer assembly, or decoration competing with the dominant zone. Quality gate remains ≥ 4/4/4.
