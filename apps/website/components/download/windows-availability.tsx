"use client";

import Link from "next/link";

import { DownloadIcon } from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { en as copy } from "@/content/en";

import { useWindowsRelease } from "./use-windows-release";

/**
 * Small client-side pieces that flip the Windows "Coming soon" state as soon
 * as an installer is published under /downloads/.
 *
 * They share one probe per page load (see use-windows-release.ts), so adding
 * more of them does not add more requests.
 */

export function WindowsStatusBadge({
  availableLabel = copy.downloadPage.statusReady,
  soonLabel = copy.downloadPage.statusSoon,
}: {
  availableLabel?: string;
  soonLabel?: string;
}) {
  const { release } = useWindowsRelease();

  return (
    <Badge tone={release ? "mint" : "orange"}>
      {release ? availableLabel : soonLabel}
    </Badge>
  );
}

export function WindowsHeroCta() {
  const { release } = useWindowsRelease();

  if (release) {
    return (
      <a
        href={release.url}
        className="btn btn-primary btn-lg w-full sm:w-auto"
        data-testid="hero-primary-cta"
        data-state="available"
        download
      >
        <DownloadIcon className="h-4 w-4" />
        {copy.hero.primaryCta}
      </a>
    );
  }

  return (
    <Link
      href="/download"
      className="btn btn-primary btn-lg w-full sm:w-auto"
      data-testid="hero-primary-cta"
      data-state="coming-soon"
    >
      <DownloadIcon className="h-4 w-4" />
      {copy.hero.primaryCtaSoon}
    </Link>
  );
}

export function WindowsHeroNote() {
  const { release } = useWindowsRelease();

  return (
    <p className="mt-3 text-xs leading-relaxed text-muted">
      {release ? copy.hero.primaryNoteReady : copy.hero.primaryNoteSoon}
    </p>
  );
}

export function WindowsCtaNote({ className }: { className?: string }) {
  const { release } = useWindowsRelease();

  return (
    <p className={className}>
      {release ? copy.cta.noteReady : copy.cta.noteSoon}
    </p>
  );
}
