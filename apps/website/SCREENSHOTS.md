# Product screenshots

The supplied screenshots are the visual source of truth for the site. They are
used as real product assets through static imports, so the original files are
not renamed, copied or modified.

| File | Intrinsic size (approx.) | Where it is used |
|---|---|---|
| `desktop_shot.png` | 1600 × 1000 | Home hero on screens ≥ 768 px, and the Open Graph image |
| `mobile_shot.png` | 410 × 901 | Home hero on screens < 768 px |
| `tablet_shot.png` | 1408 × 949 | Held in reserve; not loaded on the current pages to keep page weight down |

## Usage rules

- Import the files from `assets/images/product_screenshots/` with `next/image`.
  Static imports provide the intrinsic width and height, preventing layout
  shift.
- Never stretch a screenshot or change its aspect ratio. The desktop and mobile
  shots are shown in separate responsive wrappers.
- The frames round the outer edge only. No `object-fit: cover` crop is applied,
  so the app UI stays intact.
- The desktop screenshot is the social/OG image. Its dimensions are read from
  the import in `lib/metadata.ts`.
- Alt text lives in `content/en.ts` and `content/sw.ts`.
- Do not draw a replacement dashboard over these screenshots.
