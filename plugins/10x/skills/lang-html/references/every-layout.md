# Every Layout Reference

Every Layout primitives solve layout problems intrinsically — without media queries where possible.

Source: https://every-layout.dev

---

## Stack

Vertical spacing between siblings. The most-used primitive.

```css
.stack {
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
}

.stack > * + * {
  margin-block-start: var(--stack-space, var(--space-s));
}
```

```html
<div class="stack">
  <h2>Title</h2>
  <p>Body text</p>
  <a href="#">Read more</a>
</div>
```

Customize space per instance: `style="--stack-space: var(--space-l)"` or via `data-space`.

---

## Box

A contained region with padding and optional border.

```css
.box {
  padding: var(--box-padding, var(--space-s));
  border: var(--box-border-width, 0) solid var(--box-border-color, currentColor);
  color: var(--box-color, inherit);
  background: var(--box-background, transparent);
}

.box * {
  color: inherit;
}
```

---

## Center

Horizontally centered container with max-width.

```css
.center {
  box-sizing: content-box;
  max-inline-size: var(--center-measure, 60ch);
  margin-inline: auto;
  padding-inline: var(--center-padding, var(--space-s));
}
```

---

## Cluster

Wrapping flex group for items that belong together (tags, buttons, breadcrumbs).

```css
.cluster {
  display: flex;
  flex-wrap: wrap;
  gap: var(--cluster-space, var(--space-s));
  justify-content: var(--cluster-justify, flex-start);
  align-items: var(--cluster-align, center);
}
```

---

## Sidebar

Two-column layout where one side has a fixed/content-based width, the other fills remaining space.

```css
.sidebar {
  display: flex;
  flex-wrap: wrap;
  gap: var(--sidebar-gap, var(--space-s));
}

/* The non-sidebar element grows */
.sidebar > :last-child {
  flex-basis: 0;
  flex-grow: 999;
  min-inline-size: var(--sidebar-content-min, 50%);
}

/* The sidebar element */
.sidebar > :first-child {
  flex-grow: 1;
  flex-basis: var(--sidebar-width, 20rem);
}
```

```html
<div class="sidebar">
  <aside><!-- fixed width side --></aside>
  <main><!-- grows to fill --></main>
</div>
```

---

## Grid

Auto-responsive grid without media queries.

```css
.grid {
  display: grid;
  grid-template-columns: repeat(
    auto-fill,
    minmax(var(--grid-min, 250px), 1fr)
  );
  gap: var(--grid-gap, var(--space-s));
}
```

---

## Frame

Fixed aspect-ratio container for media (images, videos, maps).

```css
.frame {
  aspect-ratio: var(--frame-ratio, 16 / 9);
  overflow: hidden;
  display: flex;
  justify-content: center;
  align-items: center;
}

.frame > img,
.frame > video {
  inline-size: 100%;
  block-size: 100%;
  object-fit: cover;
}
```

---

## Reel

Horizontal scrolling list with optional scrollbar styling.

```css
.reel {
  display: flex;
  overflow-x: auto;
  overflow-y: hidden;
  gap: var(--reel-space, var(--space-s));
  padding-block-end: var(--reel-padding, var(--space-s));
  scrollbar-color: var(--reel-thumb, var(--color-accent)) var(--reel-track, transparent);
  scrollbar-width: thin;
}

.reel > * {
  flex-shrink: 0;
  flex-basis: var(--reel-item-width, auto);
}
```

---

## Icon

Inline SVG icon sized to the current font.

```css
.icon {
  width: var(--icon-size, 0.75em);
  height: var(--icon-size, 0.75em);
  flex-shrink: 0;
}

/* Icon with adjacent text */
.with-icon {
  display: inline-flex;
  align-items: baseline;
  gap: var(--icon-gap, 0.5em);
}
```

---

## Composition Decisions

| Problem | Primitive to use |
|---------|-----------------|
| Vertical spacing between any elements | Stack |
| Centered page content | Center |
| Card or panel with padding | Box |
| Tags, buttons, nav items on one line | Cluster |
| Content + sidebar / nav | Sidebar |
| Card grid that reflows | Grid |
| Image or video with fixed ratio | Frame |
| Horizontal scroll carousel | Reel |
| Text label with icon | Icon |

Do **not** combine primitives by nesting their CSS — compose them in HTML.

```html
<!-- Correct: compose in HTML -->
<div class="sidebar">
  <nav class="stack">...</nav>
  <main class="stack">
    <div class="grid">...</div>
  </main>
</div>
```
