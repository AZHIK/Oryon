import type { Metadata } from "next";
import Link from "next/link";

import { ChevronRightIcon } from "@/components/icons";
import { TextLink } from "@/components/ui/text-link";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.download.title,
  description: copy.meta.download.description,
  path: "/download/",
});

export default function DownloadPage() {
  return (
    <section className="relative isolate overflow-hidden pt-[calc(4rem+clamp(5rem,10vw,8rem))] pb-[clamp(5rem,10vw,9rem)]">
      <div aria-hidden="true" className="hero-aura" />

      <div className="container-page relative">
        <div className="max-w-[44rem]">
          <p className="eyebrow">{copy.downloadPage.eyebrow}</p>
          <h1 className="type-h2 mt-5 text-ink">{copy.downloadPage.title}</h1>
          <p className="type-lede mt-6">{copy.downloadPage.description}</p>

          <div className="mt-9 flex flex-col items-start gap-5 sm:flex-row sm:items-center">
            <Link href="/" className="btn btn-secondary">
              <ChevronRightIcon className="h-4 w-4 rotate-180" />
              {copy.downloadPage.backHome}
            </Link>
            <TextLink href="/#preview">
              {copy.downloadPage.seeFeatures}
            </TextLink>
          </div>
        </div>
      </div>
    </section>
  );
}
