# Content and release TODO

Everything here is intentionally rendered as a polished “Coming soon” or
disabled state. Do not replace these gaps with dead links or invented details.

## Contact

- [ ] Set `siteConfig.contact.whatsapp` to the real support number in
      international format, digits only (for example `255712345678`).
- [ ] Set `siteConfig.contact.email` to the real support address.
- [ ] When both are set, the footer and `/support` render live links
      automatically.

## Downloads

- [ ] Set `DOWNLOADS.windows.url` to the published installer URL.
- [ ] Fill `DOWNLOADS.windows.version`, `sizeMb` and `sha256` when the release
      is final.
- [ ] Set `signed: true` only after the installer is code-signed. The
      SmartScreen note is shown only while `signed` is `false`.
- [ ] Add `DOWNLOADS.macos` only if a macOS build is published.
- [ ] Add `DOWNLOADS.androidApk` only if a direct APK is published.
- [ ] Set `siteConfig.stores.googlePlay` and `siteConfig.stores.appStore` when
      the listings go live. Empty values render disabled store badges.

## Copy and legal

- [ ] `content/sw.ts` is a machine-assisted Swahili draft. A native speaker must
      review every string before the locale is enabled.
- [ ] `/privacy/` and `/terms/` are clearly marked drafts. Legal review is
      pending before store submission or launch.
- [ ] Review the privacy wording against the final data-processing and
      retention policy.
- [ ] Review the terms against the final commercial and support policy.

## Optional

- [ ] Set `NEXT_PUBLIC_PLAUSIBLE_DOMAIN` only if privacy-friendly analytics is
      wanted. Empty means no analytics script is loaded.
- [ ] Use `tablet_shot.png` in a future section if it adds value; it is
      deliberately not loaded today to keep the initial page lighter.
