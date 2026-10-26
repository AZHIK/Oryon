import Link from "next/link";

import { ChevronRightIcon, DownloadIcon } from "@/components/icons";
import { copy } from "@/content";
import { isDownloadAvailable, siteConfig } from "@/site.config";

export function FinalCta() {
  const windowsAvailable = isDownloadAvailable(siteConfig.downloads.windows);

  return (
    <section className="section-tight bg-app" aria-labelledby="cta-title">
      <div className="container-page">
        <div className="cta-band on-dark">
          <div aria-hidden="true" className="cta-pattern" />
          <div className="relative mx-auto max-w-3xl text-center">
            <p className="eyebrow">{copy.cta.eyebrow}</p>
            <h2 id="cta-title" className="type-h2 mt-3">
              {copy.cta.title}
            </h2>
            <p className="type-lede mx-auto mt-4 max-w-2xl">
              {copy.cta.description}
            </p>
            <div className="mt-7 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <Link href="/download" className="btn btn-mint btn-lg w-full sm:w-auto">
                <DownloadIcon className="h-4 w-4" />
                {copy.cta.primary}
              </Link>
              <Link
                href="/support"
                className="btn btn-outline-light btn-lg w-full sm:w-auto"
              >
                {copy.cta.secondary}
                <ChevronRightIcon className="h-4 w-4" />
              </Link>
            </div>
            <p className="mt-4 text-xs text-mint">
              {windowsAvailable ? copy.cta.noteReady : copy.cta.noteSoon}
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
