import Image from "next/image";

import { copy } from "@/content";
import { cn } from "@/lib/cn";
import { storeHref } from "@/lib/links";
import { isStoreAvailable, type StoreKey } from "@/site.config";

const BADGES = {
  googlePlay: {
    src: "/badges/google-play.svg",
    alt: copy.stores.googlePlayAlt,
    width: 180,
    height: 54,
  },
  appStore: {
    src: "/badges/app-store.svg",
    alt: copy.stores.appStoreAlt,
    width: 120,
    height: 40,
  },
} as const;

export function StoreBadge({
  store,
  className,
}: {
  store: StoreKey;
  className?: string;
}) {
  const badge = BADGES[store];
  const href = storeHref(store);

  const artwork = (
    <Image
      src={badge.src}
      alt={href ? badge.alt : ""}
      width={badge.width}
      height={badge.height}
      unoptimized
      className="h-10 w-auto"
    />
  );

  if (href) {
    return (
      <a
        href={href}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={`${badge.alt} (${copy.stores.opensInNewTab})`}
        className={cn(
          "store-badge-wrap transition-transform duration-200 hover:-translate-y-0.5",
          className,
        )}
      >
        {artwork}
      </a>
    );
  }

  return (
    <span
      role="link"
      tabIndex={0}
      aria-disabled="true"
      aria-label={`${badge.alt} — ${copy.stores.comingSoon}`}
      className={cn("store-badge-wrap cursor-not-allowed", className)}
    >
      {artwork}
    </span>
  );
}

export function StoreBadges({
  className,
  showNote = true,
}: {
  className?: string;
  showNote?: boolean;
}) {
  const googlePlay = isStoreAvailable("googlePlay");
  const appStore = isStoreAvailable("appStore");

  let note = copy.stores.noteBothSoon;
  if (googlePlay && appStore) note = copy.stores.noteBothLive;
  else if (googlePlay) note = copy.stores.noteAppSoon;
  else if (appStore) note = copy.stores.noteGoogleSoon;

  return (
    <div className={className}>
      <div className="flex flex-wrap items-center justify-center gap-2.5">
        <StoreBadge store="googlePlay" />
        <StoreBadge store="appStore" />
      </div>
      {showNote && (
        <p className="mt-2 text-center text-xs text-muted">{note}</p>
      )}
    </div>
  );
}
