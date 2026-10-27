# Oryon website

The public marketing and download site for Oryon. It is a standalone Next.js
app and does not import the Flutter client or any backend service.

- **Framework:** Next.js 16 (App Router), static export
- **Language:** TypeScript 7
- **Styling:** Tailwind CSS 4 with CSS-first design tokens
- **Type:** Inter, matching the product UI
- **Motion:** `motion` for the mobile menu only; no scroll-linked effects
- **Hosting:** any static host, or the Docker/Nginx image in this directory
  behind the existing VPS Traefik edge

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

## Docker deployment

The production image is a multi-stage build: Node builds the static export,
then a non-root Nginx image serves `out/` on port 8080 with no Node runtime in
the final image.

```bash
docker compose build
docker compose up -d
```

The container joins the existing external `oryon_edge` network and is routed by
the VPS Traefik instance at `https://oryonfoods.com`; it publishes no host
ports. See [`DEPLOYMENT.md`](./DEPLOYMENT.md) for DNS, TLS, verification,
rollback and the database-integration path.

### Local Docker preview

The production compose file expects the VPS edge network, so use the local
compose file on a laptop:

```bash
sudo systemctl start docker   # if the daemon is not running
sudo docker compose -f docker-compose.local.yml up --build -d
```

Open <http://localhost:3000>. Stop it with:

```bash
sudo docker compose -f docker-compose.local.yml down
```

This uses the same Dockerfile and static image, but publishes port 3000 and
does not require Traefik or `oryon_edge`.

## Pages

| Route | Purpose |
|---|---|
| `/` | Product story, features, offline workflow, team, platforms, FAQ and CTA |
| `/download/` | Windows, Google Play and App Store download options and install guide |
| `/support/` | Contact channels and common questions |
| `/privacy/` | Privacy policy draft |
| `/terms/` | Terms of use draft |

## Windows installer downloads

Installers are not part of the static export or the Docker image. In production
the compose file mounts `$WEBSITE_DOWNLOADS_DIR` (default
`/srv/oryon/downloads`) read-only at `/downloads/`. The download page probes
`/downloads/latest.json` and the stable alias
`/downloads/Oryon-windows-x64-setup.exe` in the browser, so publishing a build
flips “Coming soon” to “Download for Windows” with no rebuild.

Publish with [`scripts/publish-release.sh`](./scripts/publish-release.sh):

```bash
bash scripts/publish-release.sh /path/to/Oryon-1.0.0-windows-x64-setup.exe
```

See [`DEPLOYMENT.md`](./DEPLOYMENT.md#6-publishing-the-windows-installer) for
host setup, verification and rollback. For a local check, put the same files in
`/tmp/oryon-downloads` and start the local compose preview, or place them in
`public/downloads/` while running `npm run dev`.

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

The Windows installer is the exception: leave `DOWNLOADS.windows.url` empty and
the download page discovers whatever is published under `/downloads/` at
runtime. A non-empty URL is an explicit override for a mirror.

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
components/download/    Runtime download detection and installer card
components/device/      Real-screenshot desktop and phone frames
components/home/        Home sections
components/layout/      Header and footer
components/legal/       Shared legal-page layout
components/seo/         SoftwareApplication JSON-LD
components/ui/          Section headings, badges, FAQ, links
content/                English and Swahili copy
lib/                    Metadata, link and feature helpers
public/badges/          Official store badge artwork
scripts/                publish-release.sh (installer manifest and alias)
site.config.ts          Product, contact, store and download configuration
Dockerfile              Multi-stage static-export + Nginx image
nginx.conf              Non-root Nginx server configuration
docker-compose.yml      Single-VPS deployment on the oryon_edge network
docker-compose.local.yml Local-only preview on port 3000
DEPLOYMENT.md           VPS deployment and database-extension notes
```
