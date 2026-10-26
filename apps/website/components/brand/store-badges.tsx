import Image from "next/image";

import { copy } from "@/content";
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

function StoreBadge({ store }: { store: StoreKey }) {
  const badge = BADGES[store];
  const href = storeHref(store);

  return (
    <div
      className="flex items-center"
      data-store={store}
      data-state={href ? "available" : "coming-soon"}
    >
      {href ? (
        <a
          href={href}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={`${badge.alt} (${copy.stores.opensInNewTab})`}
          className="rounded-[0.45rem] transition-transform duration-300 ease-[cubic-bezier(0.25,0.1,0.25,1)] hover:-translate-y-0.5"
        >
          <Image
            src={badge.src}
            alt={badge.alt}
            width={badge.width}
            height={badge.height}
            unoptimized
            className="h-10 w-auto sm:h-11"
          />
        </a>
      ) : (
        <span
          role="link"
          tabIndex={0}
          aria-disabled="true"
          aria-label={`${badge.alt} — ${copy.stores.comingSoon}`}
          className="cursor-not-allowed rounded-[0.45rem]"
        >
          <Image
            src={badge.src}
            alt=""
            width={badge.width}
            height={badge.height}
            unoptimized
            className="h-10 w-auto sm:h-11"
          />
        </span>
      )}
    </div>
  );
}

export function StoreBadges({ className }: { className?: string }) {
  const googlePlay = isStoreAvailable("googlePlay");
  const appStore = isStoreAvailable("appStore");

  let note = copy.stores.noteBothSoon;
  if (googlePlay && appStore) note = copy.stores.noteBothLive;
  else if (googlePlay) note = copy.stores.noteAppSoon;
  else if (appStore) note = copy.stores.noteGoogleSoon;

  return (
    <div className={className}>
      <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-3">
        <StoreBadge store="googlePlay" />
        <StoreBadge store="appStore" />
      </div>
      <p className="mt-2.5 text-center text-xs text-ink-muted">{note}</p>
    </div>
  );
}
