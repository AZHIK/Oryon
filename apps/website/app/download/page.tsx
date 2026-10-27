import type { Metadata } from "next";
import Link from "next/link";

import { StoreBadge } from "@/components/brand/store-badges";
import { WindowsStatusBadge } from "@/components/download/windows-availability";
import { WindowsDownloadCard } from "@/components/download/windows-download-card";
import { ChevronLeftIcon, ChevronRightIcon } from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";
import { isStoreAvailable, siteConfig } from "@/site.config";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.download.title,
  description: copy.meta.download.description,
  path: "/download/",
});

export default function DownloadPage() {
  const windows = siteConfig.downloads.windows;
  const googleAvailable = isStoreAvailable("googlePlay");
  const appleAvailable = isStoreAvailable("appStore");

  return (
    <div className="bg-app">
      <section className="pt-[calc(4.5rem+clamp(2.5rem,5vw,4rem))] pb-10">
        <div className="container-page">
          <Link href="/" className="text-link">
            <ChevronLeftIcon className="h-3.5 w-3.5" />
            {copy.downloadPage.backHome}
          </Link>

          <div className="mt-7 max-w-3xl">
            <p className="eyebrow">{copy.downloadPage.eyebrow}</p>
            <h1 className="type-h2 mt-3">{copy.downloadPage.title}</h1>
            <p className="type-lede mt-4">{copy.downloadPage.description}</p>
            <div className="mt-5 flex flex-wrap items-center gap-2">
              <WindowsStatusBadge />
              <Badge>{windows.minOs}</Badge>
            </div>
          </div>
        </div>
      </section>

      <section className="pb-[clamp(4rem,8vw,7rem)]">
        <div className="container-page grid items-start gap-6 lg:grid-cols-[1.55fr_1fr]">
          <WindowsDownloadCard />

          <div className="space-y-6">
            <div>
              <h2 className="type-h3">{copy.downloadPage.stores.title}</h2>
              <p className="mt-1 text-sm leading-relaxed text-muted">
                {copy.downloadPage.stores.description}
              </p>

              <div className="mt-4 space-y-4">
                <article className="card p-5">
                  <StoreBadge store="googlePlay" />
                  <h3 className="mt-3 text-base font-semibold">
                    {copy.downloadPage.stores.googlePlay}
                  </h3>
                  <div className="mt-2">
                    <Badge tone={googleAvailable ? "mint" : "orange"}>
                      {googleAvailable
                        ? copy.downloadPage.statusReady
                        : copy.downloadPage.stores.comingSoon}
                    </Badge>
                  </div>
                </article>

                <article className="card p-5">
                  <StoreBadge store="appStore" />
                  <h3 className="mt-3 text-base font-semibold">
                    {copy.downloadPage.stores.appStore}
                  </h3>
                  <div className="mt-2">
                    <Badge tone={appleAvailable ? "mint" : "orange"}>
                      {appleAvailable
                        ? copy.downloadPage.statusReady
                        : copy.downloadPage.stores.comingSoon}
                    </Badge>
                  </div>
                </article>
              </div>
            </div>

            <article className="card p-5">
              <h2 className="text-base font-semibold">
                {copy.downloadPage.helpTitle}
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {copy.downloadPage.helpDescription}
              </p>
              <div className="mt-4">
                <Link href="/support" className="text-link">
                  {copy.downloadPage.helpCta}
                  <ChevronRightIcon className="h-3.5 w-3.5" />
                </Link>
              </div>
            </article>
          </div>
        </div>
      </section>
    </div>
  );
}
