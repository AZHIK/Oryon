import Link from "next/link";

import { StoreBadges } from "@/components/brand/store-badges";
import { DesktopWindow } from "@/components/device/desktop-window";
import { PhonePreview } from "@/components/device/phone-preview";
import { HeroStage } from "@/components/home/hero-stage";
import { CheckIcon, DownloadIcon } from "@/components/icons";
import { TextLink } from "@/components/ui/text-link";
import { copy } from "@/content";
import { isDownloadAvailable, siteConfig } from "@/site.config";

export function Hero() {
  const windows = siteConfig.downloads.windows;
  const windowsAvailable = isDownloadAvailable(windows);

  const commaIndex = copy.hero.title.indexOf(",");
  const titleLead =
    commaIndex === -1 ? copy.hero.title : copy.hero.title.slice(0, commaIndex);
  const titleAccent =
    commaIndex === -1 ? "" : copy.hero.title.slice(commaIndex + 1).trim();

  const windowsDetail = [
    windows.version ? `v${windows.version}` : null,
    windows.sizeMb > 0 ? `${windows.sizeMb} MB` : null,
    windows.minOs,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <section
      id="get-app"
      aria-labelledby="hero-title"
      className="relative isolate overflow-hidden pb-16 pt-[calc(4rem+clamp(4rem,8vw,7rem))]"
    >
      <div aria-hidden="true" className="hero-aura" />
      <div aria-hidden="true" className="dot-grid" />

      <div className="container-page relative">
        <div className="mx-auto max-w-[58rem] text-center">
          <span
            className="hero-rise eyebrow rounded-full border border-line bg-surface/70 px-3.5 py-2 shadow-soft backdrop-blur-sm"
            style={{ animationDelay: "0.02s" }}
          >
            <span
              aria-hidden="true"
              className="h-1.5 w-1.5 rounded-full bg-sage"
            />
            {copy.hero.eyebrow}
          </span>

          <h1
            id="hero-title"
            className="hero-rise-title type-display mt-7 text-ink"
          >
            {titleLead}
            {titleAccent ? "," : ""}
            {titleAccent && (
              <span className="block text-terracotta">{titleAccent}</span>
            )}
          </h1>

          <p
            className="hero-rise type-lede mx-auto mt-7 max-w-[44rem]"
            style={{ animationDelay: "0.12s" }}
          >
            {copy.hero.description}
          </p>

          <div
            className="hero-rise mt-9 flex flex-col items-center justify-center gap-4 sm:flex-row sm:gap-5"
            style={{ animationDelay: "0.18s" }}
          >
            {windowsAvailable ? (
              <a
                href={windows.url}
                className="btn btn-primary"
                data-testid="hero-primary-cta"
                data-state="available"
              >
                <DownloadIcon className="h-4 w-4" />
                {copy.hero.primaryCta}
              </a>
            ) : (
              <span
                role="button"
                tabIndex={0}
                aria-disabled="true"
                aria-describedby="windows-download-note"
                data-testid="hero-primary-cta"
                data-state="coming-soon"
                className="btn btn-disabled"
              >
                <DownloadIcon className="h-4 w-4" />
                {copy.hero.primaryCta}
                <span className="btn-soon-chip">{copy.hero.soonChip}</span>
              </span>
            )}

            <TextLink href="#preview">{copy.hero.secondaryCta}</TextLink>
          </div>

          <p
            id="windows-download-note"
            className="hero-rise mt-4 text-xs leading-relaxed text-ink-muted"
            style={{ animationDelay: "0.24s" }}
          >
            {windowsAvailable
              ? windowsDetail
              : copy.hero.primaryNoteSoon}{" "}
            {!windowsAvailable && (
              <Link
                href="/download"
                className="text-link text-xs underline decoration-line underline-offset-4"
              >
                {copy.hero.downloadDetails}
              </Link>
            )}
          </p>

          <div className="hero-rise" style={{ animationDelay: "0.3s" }}>
            <StoreBadges className="mt-8" />
          </div>
        </div>

        <HeroStage
          desktop={<DesktopWindow />}
          phone={<PhonePreview />}
        />

        <p
          className="hero-rise mt-1 text-center text-[0.7rem] font-medium tracking-wide text-ink-muted"
          style={{ animationDelay: "0.4s" }}
        >
          {copy.preview.label} · {copy.preview.note}
        </p>

        <div
          className="hero-rise mt-12 border-y border-line py-5"
          style={{ animationDelay: "0.46s" }}
        >
          <ul className="flex flex-wrap items-center justify-center gap-2.5">
            {copy.hero.capabilities.map((capability) => (
              <li
                key={capability}
                className="inline-flex items-center gap-2 rounded-full border border-line bg-surface/70 px-3.5 py-1.5 text-xs font-medium text-ink-muted"
              >
                <CheckIcon className="h-3.5 w-3.5 text-sage" />
                {capability}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
