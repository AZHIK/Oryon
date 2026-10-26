import type { Metadata } from "next";
import Link from "next/link";

import { StoreBadge } from "@/components/brand/store-badges";
import { CopyButton } from "@/components/download/copy-button";
import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ClockIcon,
  DownloadIcon,
  MonitorIcon,
  ShieldIcon,
} from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";
import {
  isDownloadAvailable,
  isStoreAvailable,
  siteConfig,
} from "@/site.config";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.download.title,
  description: copy.meta.download.description,
  path: "/download/",
});

export default function DownloadPage() {
  const windows = siteConfig.downloads.windows;
  const windowsAvailable = isDownloadAvailable(windows);
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
              <Badge tone={windowsAvailable ? "mint" : "orange"}>
                {windowsAvailable
                  ? copy.downloadPage.statusReady
                  : copy.downloadPage.statusSoon}
              </Badge>
              <Badge>{windows.minOs}</Badge>
            </div>
          </div>
        </div>
      </section>

      <section className="pb-[clamp(4rem,8vw,7rem)]">
        <div className="container-page grid items-start gap-6 lg:grid-cols-[1.55fr_1fr]">
          <article className="card card-panel p-5 sm:p-7">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="flex items-start gap-3">
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone="mint"
                  aria-hidden="true"
                >
                  <MonitorIcon className="h-5 w-5" />
                </span>
                <div>
                  <h2 className="type-h3">
                    {copy.downloadPage.windows.title}
                  </h2>
                  <p className="mt-1 max-w-xl text-sm leading-relaxed text-muted">
                    {copy.downloadPage.windows.description}
                  </p>
                </div>
              </div>
              <Badge tone={windowsAvailable ? "mint" : "orange"}>
                {windowsAvailable
                  ? copy.downloadPage.statusReady
                  : copy.downloadPage.statusSoon}
              </Badge>
            </div>

            {windowsAvailable ? (
              <div className="mt-6 grid gap-3 rounded-xl border border-line bg-surface-muted p-4 sm:grid-cols-3">
                {windows.version ? (
                  <div>
                    <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                      {copy.downloadPage.windows.versionLabel}
                    </p>
                    <p className="mt-1 text-sm font-semibold">{windows.version}</p>
                  </div>
                ) : null}
                {windows.sizeMb > 0 ? (
                  <div>
                    <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                      {copy.downloadPage.windows.sizeLabel}
                    </p>
                    <p className="mt-1 text-sm font-semibold">
                      {windows.sizeMb} MB
                    </p>
                  </div>
                ) : null}
                <div>
                  <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                    {copy.downloadPage.windows.minOsLabel}
                  </p>
                  <p className="mt-1 text-sm font-semibold">{windows.minOs}</p>
                </div>
              </div>
            ) : (
              <p
                id="windows-waiting-note"
                className="mt-6 flex items-start gap-2 rounded-xl border border-line bg-surface-muted p-4 text-sm leading-relaxed text-muted"
              >
                <ClockIcon className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                {copy.downloadPage.windows.waiting}
              </p>
            )}

            {windows.sha256 ? (
              <div className="mt-4">
                <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                  {copy.downloadPage.windows.checksumLabel}
                </p>
                <div className="mt-2 flex flex-col gap-2 sm:flex-row sm:items-center">
                  <code className="min-w-0 flex-1 overflow-x-auto rounded-lg border border-line bg-surface-muted px-3 py-2 text-xs leading-relaxed text-muted">
                    {windows.sha256}
                  </code>
                  <CopyButton
                    value={windows.sha256}
                    label={copy.downloadPage.windows.copy}
                    copiedLabel={copy.downloadPage.windows.copied}
                  />
                </div>
              </div>
            ) : null}

            <div className="mt-6 flex flex-col items-start gap-3 sm:flex-row sm:items-center">
              {windowsAvailable ? (
                <a href={windows.url} className="btn btn-primary w-full sm:w-auto">
                  <DownloadIcon className="h-4 w-4" />
                  {copy.downloadPage.windows.download}
                </a>
              ) : (
                <span
                  role="button"
                  tabIndex={0}
                  aria-disabled="true"
                  aria-describedby="windows-waiting-note"
                  className="btn btn-disabled w-full sm:w-auto"
                >
                  <ClockIcon className="h-4 w-4" />
                  {copy.downloadPage.windows.comingSoon}
                </span>
              )}
              <p className="text-xs leading-relaxed text-muted">
                {copy.downloadPage.windows.note}
              </p>
            </div>

            <div className="mt-8 border-t border-line pt-6">
              <h3 className="type-h3">
                {copy.downloadPage.windows.installTitle}
              </h3>
              <ol className="mt-4 space-y-3">
                {copy.downloadPage.windows.installSteps.map((step, index) => (
                  <li key={step} className="flex items-start gap-3">
                    <span className="step-number" aria-hidden="true">
                      {index + 1}
                    </span>
                    <span className="pt-1 text-sm leading-relaxed text-muted">
                      {step}
                    </span>
                  </li>
                ))}
              </ol>
            </div>

            {!windows.signed ? (
              <div className="mt-6 rounded-xl border border-line bg-surface-muted p-4">
                <div className="flex items-center gap-2">
                  <ShieldIcon className="h-4 w-4 text-accent" />
                  <p className="text-sm font-semibold">
                    {copy.downloadPage.windows.smartScreenTitle}
                  </p>
                </div>
                <p className="mt-2 text-xs leading-relaxed text-muted">
                  {copy.downloadPage.windows.smartScreenBody}
                </p>
              </div>
            ) : null}
          </article>

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
