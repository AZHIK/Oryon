# Oryon website

The public marketing and download site for Oryon. It is a standalone Next.js
app and does not import the Flutter client or any backend service.

- **Framework:** Next.js 16 (App Router), static export
- **Language:** TypeScript 7
- **Styling:** Tailwind CSS 4 with CSS-first design tokens
- **Type:** Inter, matching the product UI
- **Motion:** `motion` for the mobile menu only; no scroll-linked effects
- **Hosting:** any static host, including the existing VPS behind Nginx

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

The build writes a fully static site to `out/`. `npm run preview` serves that
directory on port 3000.

## Pages

| Route | Purpose |
|---|---|
| `/` | Product story, features, offline workflow, team, platforms, FAQ and CTA |
| `/download/` | Windows, Google Play and App Store download options and install guide |
| `/support/` | Contact channels and common questions |
| `/privacy/` | Privacy policy draft |
| `/terms/` | Terms of use draft |

## Product screenshots

The real app screenshots live in
`assets/images/product_screenshots/` and are imported directly with
`next/image`. They are never redrawn or replaced with fabricated dashboards.
See [`SCREENSHOTS.md`](./SCREENSHOTS.md) for usage.

## Design system

The palette and surfaces are derived from the app theme and screenshots:

- Deep teal `#0B6B57` for primary actions, links and active states
- Mint `#A0F0D8` and pale mint `#EAF5F1` for highlights and soft surfaces
- App background `#EFF4F2`; white cards and panels
- Ink `#202927`; secondary text `#56615E`; border `#D9E3DF`
- Blue `#2859E8`, orange `#E85A27` and purple `#7938E8` as restrained feature
  accents only

The app's 16px card radius, 14px button radius and Inter type scale are used
throughout. Tokens are defined once in `app/globals.css` and exposed to
Tailwind through `@theme inline`.

## Configuration

Everything the owner may need to change lives in `site.config.ts`:

- product name, tagline and domain (single source of truth)
- WhatsApp number and support email
- Google Play and App Store URLs
- Windows download metadata and code-signing state
- `FEATURES_STATUS`, which gates every capability claim

Empty URLs render as polished “Coming soon” states. Never replace them with
placeholder links. Outstanding values are recorded in
[`CONTENT_TODO.md`](./CONTENT_TODO.md).

All visible copy is in `content/`, typed for English (`en`) and Swahili (`sw`).
Swahili is a draft and must be reviewed by a native speaker before it is shown.

## Brand rules

- Deep teal is the only primary action color.
- Mint is a supporting surface and highlight, not a body-text color.
- Blue, orange and purple appear only as small feature accents.
- Official Google Play and App Store badges in `public/badges/` are used
  unmodified. Do not redraw, recolor, crop or stretch them.
- Screenshot frames may round the outer container; do not crop the app UI.
- No invented testimonials, customer counts, ratings, logos or pricing.

## Accessibility and performance

The site targets WCAG 2.2 AA. It uses semantic landmarks, a skip link, visible
focus rings, keyboard-operable navigation and native `<details>` FAQs. Motion is
limited to the mobile menu and respects `prefers-reduced-motion`. Dark mode
follows `prefers-color-scheme`. No trackers load by default; optional Plausible
analytics is enabled only with `NEXT_PUBLIC_PLAUSIBLE_DOMAIN`.

## Structure

```text
app/                    Routes, metadata, sitemap, robots, global styles
assets/images/          Supplied product screenshots
components/brand/       Logo and store badges
components/device/      Real-screenshot desktop and phone frames
components/home/        Home sections
components/layout/      Header and footer
components/legal/       Shared legal-page layout
components/seo/         SoftwareApplication JSON-LD
components/ui/          Section headings, badges, FAQ, links
content/                English and Swahili copy
lib/                    Metadata and link helpers
public/badges/          Official store badge artwork
site.config.ts          Product, contact, store and download configuration
```
