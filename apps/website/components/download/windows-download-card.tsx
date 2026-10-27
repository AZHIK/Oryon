"use client";

import { CopyButton } from "@/components/download/copy-button";
import {
  ClockIcon,
  DownloadIcon,
  MonitorIcon,
  ShieldIcon,
} from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { en as copy } from "@/content/en";
import { siteConfig } from "@/site.config";

import { useWindowsRelease } from "./use-windows-release";

/**
 * The Windows card on /download/. The server renders the "Coming soon" state;
 * once the browser can see a published installer the card switches to the
 * download state without a site rebuild.
 */
export function WindowsDownloadCard() {
  const windows = siteConfig.downloads.windows;
  const { release } = useWindowsRelease();

  const available = Boolean(release);
  const version = release?.version ?? windows.version;
  const sizeMb = release?.sizeMb ?? windows.sizeMb;
  const sha256 = release?.sha256 ?? windows.sha256;
  const url = release?.url ?? windows.url;
  const canDownload = available && Boolean(url);

  return (
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
            <h2 className="type-h3">{copy.downloadPage.windows.title}</h2>
            <p className="mt-1 max-w-xl text-sm leading-relaxed text-muted">
              {copy.downloadPage.windows.description}
            </p>
          </div>
        </div>
        <Badge tone={available ? "mint" : "orange"}>
          {available
            ? copy.downloadPage.statusReady
            : copy.downloadPage.statusSoon}
        </Badge>
      </div>

      {available ? (
        <div className="mt-6 grid gap-3 rounded-xl border border-line bg-surface-muted p-4 sm:grid-cols-3">
          {version ? (
            <div>
              <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                {copy.downloadPage.windows.versionLabel}
              </p>
              <p className="mt-1 text-sm font-semibold">{version}</p>
            </div>
          ) : null}
          {sizeMb > 0 ? (
            <div>
              <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
                {copy.downloadPage.windows.sizeLabel}
              </p>
              <p className="mt-1 text-sm font-semibold">{sizeMb} MB</p>
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

      {sha256 ? (
        <div className="mt-4">
          <p className="text-[0.6875rem] font-semibold uppercase tracking-[0.08em] text-muted">
            {copy.downloadPage.windows.checksumLabel}
          </p>
          <div className="mt-2 flex flex-col gap-2 sm:flex-row sm:items-center">
            <code className="min-w-0 flex-1 overflow-x-auto rounded-lg border border-line bg-surface-muted px-3 py-2 text-xs leading-relaxed text-muted">
              {sha256}
            </code>
            <CopyButton
              value={sha256}
              label={copy.downloadPage.windows.copy}
              copiedLabel={copy.downloadPage.windows.copied}
            />
          </div>
        </div>
      ) : null}

      <div className="mt-6 flex flex-col items-start gap-3 sm:flex-row sm:items-center">
        {canDownload ? (
          <a href={url} className="btn btn-primary w-full sm:w-auto" download>
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
        <h3 className="type-h3">{copy.downloadPage.windows.installTitle}</h3>
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
  );
}
