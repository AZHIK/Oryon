import { Badge } from "@/components/ui/badge";
import { SectionHeading } from "@/components/ui/section-heading";
import { FeatureIcon } from "@/components/home/feature-icon";
import { CheckIcon } from "@/components/icons";
import { copy } from "@/content";
import {
  isFeatureComingSoon,
  isMainFeatureShipped,
} from "@/lib/features";

const COMING_META: Record<string, { icon: string; tone: string }> = {
  electronicPayments: { icon: "payments", tone: "orange" },
  aiMode: { icon: "insights", tone: "mint" },
  advancedReports: { icon: "advanced", tone: "blue" },
};

const BENTO_CLASSES = [
  "bento-hero",
  "bento-side",
  "bento-third",
  "bento-third",
  "bento-third",
  "bento-hero",
] as const;

export function FeatureBento() {
  const shippedItems = copy.features.items.filter((item) =>
    isMainFeatureShipped(item.key),
  );

  const comingItems = copy.features.comingSoon.items.filter((item) =>
    isFeatureComingSoon(item.key),
  );

  return (
    <section
      id="features"
      aria-labelledby="features-title"
      className="section border-t border-line bg-surface"
    >
      <div className="container-page">
        <SectionHeading
          eyebrow={copy.features.eyebrow}
          title={copy.features.title}
          description={copy.features.description}
          titleId="features-title"
        />

        <div className="bento-grid mt-10">
          {shippedItems.map((item, index) => {
            const spanClass = BENTO_CLASSES[index] ?? "bento-third";

            return (
              <article
                key={item.key}
                className={`bento-card card-hover ${spanClass}${
                  index === 0 ? " bento-card-mint" : ""
                }`}
              >
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone={item.tone}
                  aria-hidden="true"
                >
                  <FeatureIcon name={item.key} className="h-5 w-5" />
                </span>
                <h3 className="type-h3 mt-4">{item.title}</h3>
                <p className="bento-copy">{item.description}</p>

                {item.key === "offline" && (
                  <ul className="mt-5 flex flex-wrap gap-2">
                    {copy.offline.card.rows.map((row) => (
                      <li key={row} className="chip chip-mint">
                        <CheckIcon className="h-3 w-3" />
                        {row}
                      </li>
                    ))}
                  </ul>
                )}

                {item.key === "team" && (
                  <ul className="mt-5 flex flex-wrap gap-2">
                    {copy.team.card.rows.map((row) => (
                      <li key={row.role} className="chip">
                        <span
                          className="h-1.5 w-1.5 rounded-full"
                          style={{ backgroundColor: `var(--role-${row.tone})` }}
                          aria-hidden="true"
                        />
                        {row.role}
                      </li>
                    ))}
                  </ul>
                )}
              </article>
            );
          })}

          {comingItems.length > 0 && (
            <article className="bento-card bento-side-wide bg-surface-muted">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <h3 className="type-h3">
                    {copy.features.comingSoon.title}
                  </h3>
                  <p className="bento-copy max-w-xl">
                    {copy.features.comingSoon.description}
                  </p>
                </div>
                <Badge tone="orange">{copy.features.comingSoon.badge}</Badge>
              </div>

              <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-1">
                {comingItems.map((item) => {
                  const meta = COMING_META[item.key] ?? {
                    icon: "insights",
                    tone: "blue",
                  };
                  return (
                    <div
                      key={item.title}
                      className={`coming-item ${
                        item.key === "aiMode" ? "coming-item-ai" : ""
                      }`}
                    >
                      <span
                        className="icon-tile"
                        data-tone={meta.tone}
                        aria-hidden="true"
                      >
                        <FeatureIcon name={meta.icon} className="h-4 w-4" />
                      </span>
                      <div>
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="text-sm font-semibold leading-snug">
                            {item.title}
                          </p>
                          {item.badge ? (
                            <Badge tone="mint">{item.badge}</Badge>
                          ) : null}
                        </div>
                        <p className="mt-1 text-xs leading-relaxed text-muted">
                          {item.description}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </article>
          )}
        </div>
      </div>
    </section>
  );
}
