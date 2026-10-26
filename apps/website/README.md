# Website

The public marketing and download site for the restaurant platform. It is a
standalone Next.js app: it does not import the Flutter client or any backend
service.

- **Framework:** Next.js 16 (App Router) with `output: "export"`
- **Language:** TypeScript 7
- **Styling:** Tailwind CSS 4, CSS custom properties for brand tokens
- **Motion:** `motion` (Framer Motion) — transform/opacity only
- **Hosting:** any static host, or the Docker/Nginx image described in
  `DEPLOYMENT.md` on the existing VPS

## Local development

Requires Node.js 20.9 or newer.

```bash
npm install
npm run dev
```

Open <http://localhost:3000>.

## Production build

```bash
npm run build
npm run preview
```

`npm run build` writes a fully static site to `out/`. `npm run preview` serves
that directory on port 3000.

## Configuration

Everything the owner may need to change lives in `site.config.ts`:

- product name, tagline and domain (single source of truth)
- WhatsApp number and support email
- Google Play / App Store URLs
- Windows download metadata and code-signing state
- `FEATURES_STATUS`, which gates every capability claim

Empty URLs are rendered as polished "Coming soon" states. Never replace them
with placeholder links. Outstanding values are recorded in `CONTENT_TODO.md`.

All visible copy is in `content/`, typed for English (`en`) and Swahili (`sw`).
Swahili is a draft and must be reviewed by a native speaker before it is shown.

## Brand rules

- Terracotta `#D2601A` for graphics, large display accents and icons.
- Terracotta Deep `#B8530F` for button fills and small colored text on white.
- Sage `#4C6B4F` for secondary accents and success states.
- Gold `#C99A2E` is decorative only — never text on white.
- Predominantly white, with warm cream `#FBF7F2` alternates and warm charcoal
  `#17130F` dark bands.
- The Google Play and App Store badge artwork in `public/badges/` is used
  unmodified. Do not redraw, recolor, crop or stretch it.

## Structure

```text
app/                 App Router pages, metadata, global styles
components/          Brand, layout, home and device mockup components
content/             All English and Swahili copy
lib/                 Metadata, link and class helpers
public/badges/       Official store badge artwork
public/screens/      Real app screenshots (see SCREENSHOTS.md)
site.config.ts       Product, contact, store and download configuration
```

## Accessibility and performance

The site targets WCAG 2.2 AA and Lighthouse mobile 95+ across all categories.
Motion is skipped when `prefers-reduced-motion` is set, and dark mode follows
`prefers-color-scheme`. No trackers or cookies load by default; optional
Plausible analytics is enabled only with `NEXT_PUBLIC_PLAUSIBLE_DOMAIN`.
