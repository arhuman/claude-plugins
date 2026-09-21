# Aesthetic Direction

How to make an interface distinctive without breaking the architecture. The design system constrains **where** visual identity lives (tokens, theme scopes, composition primitives); this file guides **what** to put there so the result does not read as generic AI output.

## Design thinking, before coding

Understand the context and commit to one clear aesthetic direction:

- **Purpose**: what problem does this interface solve? Who uses it, in what state of mind?
- **Tone**: pick a direction and hold it: brutally minimal, editorial/magazine, luxury/refined, playful, industrial/utilitarian, organic/natural, retro-futuristic, art deco/geometric, soft/pastel... The list is inspiration, not a menu: design one true to the product.
- **Constraints**: framework, performance, accessibility, and this design system's contracts are inputs to the direction, not obstacles.
- **Differentiation**: name the one thing someone will remember about this screen.

**Intentionality, not intensity.** Bold maximalism and refined minimalism both work; what fails is the timid middle. Match implementation effort to the vision: maximalist directions need elaborate motion and layering; minimal directions need restraint, precision, and obsessive spacing/typography care. Elegance comes from executing the chosen vision well.

## Where identity lives in this system

Distinctiveness is expressed **through the token layer and theme scopes**, never against the architecture:

- Typography, palette, radius, motion speed, and signature gestures (an accent dot, a brass underline, a hairline rule) are token and theme-delta decisions.
- Layout stays on composition primitives. Asymmetry, overlap, and controlled density are achieved with primitive parameters (`--stack-space`, cluster justification, grid sizing), not ad-hoc CSS or extra breakpoints.
- Never hardcode a value to get a look: if the look needs a new value, it needs a new token.

## Typography

- Pair a characterful display font with a refined body font. Avoid defaulting to the generic stack (Arial, system-ui) for identity surfaces: it reads as unstyled, not as minimal.
- Fonts are self-hosted woff2 (CSP `font-src 'self'`), subset with `unicode-range`, `font-display: swap`, and referenced only via tokens (`--font-display`, `--font-sans`).
- The type scale is fluid (`clamp()`); identity comes from the faces, weights, letter-spacing, and casing conventions (for example a mono uppercase eyebrow style), not from one-off sizes.

## Color

- Commit to a cohesive palette with a dominant color and sharp accents; timid, evenly-distributed palettes read as generic. All of it lives in `tokens.css` as semantic tokens.
- Avoid cliché schemes (notably purple gradients on white) and cookie-cutter combinations that ignore the product's context.
- Every pair must pass WCAG 2.1 AA in **both** themes; a beautiful pair that fails contrast is not a design, it is a bug.
- Derived shades (dim, glow) come from `color-mix()` on the base tokens, so the whole mood shifts when a theme retunes the base.

## Motion

- CSS-only. Prioritize one or two high-impact moments over scattered micro-interactions: a well-orchestrated page load with staggered reveals (`animation-delay`) creates more delight than motion everywhere.
- Hover and focus states that reward attention; keep them within the interactive-state contract (all four states present).
- Durations and easings come from tokens (`--ease`, `--transition-speed`), which are theme decisions: an instant snappy skin and a slow contemplative one must both work without touching component CSS.
- `animation-fill-mode: backwards` (never `both`), and everything respects the global `prefers-reduced-motion` handling.

## Backgrounds and visual details

- Create atmosphere and depth rather than defaulting to flat solid surfaces: gradient meshes, noise or grain textures, geometric patterns, layered transparencies, deliberate shadows, decorative borders.
- All of it self-contained (inline SVG, CSS gradients, embedded data URIs): the CSP allows no external assets, and authenticated pages make no third-party calls.
- Details must survive every theme the project ships; validate the atmospheric layer wherever the snapshot harness runs.

## Anti-generic checklist

Before shipping, verify the screen does not exhibit:

- Default font stack on an identity surface, or the same overused display face as every other generation
- An evenly-weighted palette with no dominant, or a cliché gradient
- A predictable hero-cards-footer assembly with no compositional intent
- Decoration that fights lisibilité: atmosphere must support the dominant zone, never compete with it (the quality grid still gates: ≥ 4/4/4)
