import { CheckCircleIcon, RefreshIcon } from "@/components/icons";
import { SectionHeading } from "@/components/ui/section-heading";
import { copy } from "@/content";

export function OfflineSection() {
  return (
    <section
      id="offline"
      aria-labelledby="offline-title"
      className="band-dark on-dark section"
    >
      <div aria-hidden="true" className="band-glow" />

      <div className="container-page relative">
        <div className="grid items-center gap-10 lg:grid-cols-[1.05fr_0.95fr] lg:gap-14">
          <div>
            <SectionHeading
              eyebrow={copy.offline.eyebrow}
              title={copy.offline.title}
              description={copy.offline.description}
              titleId="offline-title"
            />
            <ul className="offline-list">
              {copy.offline.bullets.map((bullet) => (
                <li key={bullet}>
                  <CheckCircleIcon className="h-4 w-4" />
                  <span>{bullet}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="sync-card surface-light">
            <div className="flex items-center justify-between gap-3">
              <p className="text-sm font-semibold">{copy.offline.card.title}</p>
              <span className="chip">
                <span
                  className="h-1.5 w-1.5 rounded-full bg-muted"
                  aria-hidden="true"
                />
                {copy.offline.card.status}
              </span>
            </div>

            <div className="mt-3">
              {copy.offline.card.rows.map((row) => (
                <div key={row} className="sync-row">
                  <span className="flex items-center gap-2.5 text-sm font-medium">
                    <span className="sync-check" aria-hidden="true">
                      <CheckCircleIcon className="h-3.5 w-3.5" />
                    </span>
                    {row}
                  </span>
                </div>
              ))}
            </div>

            <div className="mt-4 flex items-start gap-2.5 border-t border-line pt-4">
              <RefreshIcon className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
              <div>
                <p className="text-xs font-semibold">
                  {copy.offline.card.footerTitle}
                </p>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  {copy.offline.card.footerCopy}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
