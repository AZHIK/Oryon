import { StoreBadge } from "@/components/brand/store-badges";
import { MonitorIcon } from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { SectionHeading } from "@/components/ui/section-heading";
import { TextLink } from "@/components/ui/text-link";
import { copy } from "@/content";
import {
  isDownloadAvailable,
  isStoreAvailable,
  siteConfig,
} from "@/site.config";

export function PlatformsSection() {
  const windowsAvailable = isDownloadAvailable(siteConfig.downloads.windows);
  const googleAvailable = isStoreAvailable("googlePlay");
  const appleAvailable = isStoreAvailable("appStore");

  return (
    <section
      id="platforms"
      aria-labelledby="platforms-title"
      className="section bg-app"
    >
      <div className="container-page">
        <SectionHeading
          eyebrow={copy.platforms.eyebrow}
          title={copy.platforms.title}
          description={copy.platforms.description}
          titleId="platforms-title"
          align="center"
        />

        <div className="platform-grid">
          <article className="platform-card">
            <div>
              <span
                className="icon-tile icon-tile-lg"
                data-tone="mint"
                aria-hidden="true"
              >
                <MonitorIcon className="h-5 w-5" />
              </span>
              <h3 className="type-h3 mt-4">{copy.platforms.windows.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {copy.platforms.windows.description}
              </p>
              <p className="mt-2 text-xs text-muted">
                {copy.platforms.windows.requirement}
              </p>
            </div>
            <div>
              <Badge tone={windowsAvailable ? "mint" : "orange"}>
                {windowsAvailable
                  ? copy.platforms.statusAvailable
                  : copy.platforms.statusComingSoon}
              </Badge>
              <div className="mt-3">
                <TextLink href="/download">
                  {copy.platforms.windows.cta}
                </TextLink>
              </div>
            </div>
          </article>

          <article className="platform-card">
            <div>
              <StoreBadge store="googlePlay" />
              <h3 className="type-h3 mt-4">
                {copy.platforms.googlePlay.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {copy.platforms.googlePlay.description}
              </p>
            </div>
            <Badge tone={googleAvailable ? "mint" : "orange"}>
              {googleAvailable
                ? copy.platforms.statusAvailable
                : copy.platforms.statusComingSoon}
            </Badge>
          </article>

          <article className="platform-card">
            <div>
              <StoreBadge store="appStore" />
              <h3 className="type-h3 mt-4">
                {copy.platforms.appStore.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-muted">
                {copy.platforms.appStore.description}
              </p>
            </div>
            <Badge tone={appleAvailable ? "mint" : "orange"}>
              {appleAvailable
                ? copy.platforms.statusAvailable
                : copy.platforms.statusComingSoon}
            </Badge>
          </article>
        </div>

        <div className="mt-8 text-center">
          <p className="text-xs text-muted">{copy.platforms.note}</p>
          <div className="mt-3">
            <TextLink href="/download">{copy.platforms.cta}</TextLink>
          </div>
        </div>
      </div>
    </section>
  );
}
