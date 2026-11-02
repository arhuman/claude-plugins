// Rendered mobile checks the static auditor cannot make. Run in a page sized
// 375x812 (Playwright browser_resize, then browser_evaluate with this
// function). Thresholds follow Lighthouse: text >= 12px, tap targets >= 48px
// with 8px spacing, no horizontal scroll.
() => {
  const visible = (e) => e.offsetParent !== null && getComputedStyle(e).visibility !== "hidden";
  const textEls = [...document.querySelectorAll("body *")].filter(
    (e) => visible(e) && [...e.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim().length > 2)
  );
  let total = 0, small = 0;
  const smallSamples = [];
  for (const e of textEls) {
    const size = parseFloat(getComputedStyle(e).fontSize);
    const len = e.textContent.trim().length;
    total += len;
    if (size < 12) {
      small += len;
      if (smallSamples.length < 8) smallSamples.push(`${size}px ${e.tagName.toLowerCase()}.${e.className}`);
    }
  }
  const taps = [...document.querySelectorAll("a[href],button,input,select,textarea,[role=button]")]
    .filter(visible)
    .map((e) => ({ e, r: e.getBoundingClientRect() }))
    .filter((t) => t.r.width > 0 && t.r.height > 0);
  const crowded = [];
  for (let i = 0; i < taps.length; i++) {
    const a = taps[i].r;
    if (a.width >= 48 && a.height >= 48) continue;
    for (let j = 0; j < taps.length; j++) {
      if (i === j) continue;
      const b = taps[j].r;
      if (a.left - 8 < b.right && a.right + 8 > b.left && a.top - 8 < b.bottom && a.bottom + 8 > b.top) {
        crowded.push(`${taps[i].e.textContent.trim().slice(0, 30) || taps[i].e.tagName} (${Math.round(a.width)}x${Math.round(a.height)})`);
        break;
      }
    }
  }
  return {
    smallTextPercent: total ? +(100 * small / total).toFixed(1) : 0,
    smallTextSamples: smallSamples,
    bodyFontSize: getComputedStyle(document.body).fontSize,
    crowdedTapTargets: crowded.length,
    crowdedSamples: crowded.slice(0, 10),
    horizontalOverflow: document.documentElement.scrollWidth > window.innerWidth,
    pass: {
      legibleFonts: total === 0 || small / total < 0.4,
      tapTargets: crowded.length === 0,
      noOverflow: document.documentElement.scrollWidth <= window.innerWidth,
    },
  };
}
