import Link from "next/link";

import { StoreBadges } from "@/components/brand/store-badges";
import {
  WindowsHeroCta,
  WindowsHeroNote,
} from "@/components/download/windows-availability";
import { HeroStage } from "@/components/home/hero-stage";
import { FeatureIcon } from "@/components/home/feature-icon";
import { ChevronRightIcon } from "@/components/icons";
import { copy } from "@/content";

export function Hero() {
  const comma = copy.hero.title.indexOf(",");
  const titleLead =
    comma === -1 ? copy.hero.title : copy.hero.title.slice(0, comma);
  const titleAccent =
    comma === -1 ? "" : copy.hero.title.slice(comma + 1).trim();

  return (
    <section
      id="product"
      aria-labelledby="hero-title"
      className="hero"
    >
      <div aria-hidden="true" className="hero-glow" />

      <div className="container-page relative">
        <div className="mx-auto max-w-[48rem] text-center">
          <span className="eyebrow-pill">
            <span className="eyebrow-dot" aria-hidden="true" />
            {copy.hero.eyebrow}
          </span>

          <h1 id="hero-title" className="type-display mt-5">
            {titleLead}
            {titleAccent ? "," : ""}
            {titleAccent && (
              <span className="block text-accent">{titleAccent}</span>
            )}
          </h1>

          <p className="type-lede mx-auto mt-5 max-w-[42rem]">
            {copy.hero.description}
          </p>

          <div className="mt-7 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <WindowsHeroCta />

            <Link
              href="#features"
              className="btn btn-secondary btn-lg w-full sm:w-auto"
            >
              {copy.hero.secondaryCta}
              <ChevronRightIcon className="h-4 w-4" />
            </Link>
          </div>

          <WindowsHeroNote />

          <StoreBadges className="mt-5" />
        </div>

        <HeroStage />

        <div className="capability-grid">
          {copy.hero.capabilities.map((capability) => (
            <div key={capability.key} className="capability-card">
              <span
                className="icon-tile"
                data-tone={capability.tone}
                aria-hidden="true"
              >
                <FeatureIcon
                  name={capability.key}
                  className="h-5 w-5"
                />
              </span>
              <div>
                <p className="capability-title">{capability.title}</p>
                <p className="capability-copy">{capability.description}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
