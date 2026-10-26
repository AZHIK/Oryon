import { CheckIcon, KeyIcon } from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { SectionHeading } from "@/components/ui/section-heading";
import { copy } from "@/content";

export function TeamSection() {
  return (
    <section
      id="team"
      aria-labelledby="team-title"
      className="section border-y border-line bg-surface"
    >
      <div className="container-page">
        <div className="grid items-center gap-10 lg:grid-cols-2 lg:gap-14">
          <div>
            <SectionHeading
              eyebrow={copy.team.eyebrow}
              title={copy.team.title}
              description={copy.team.description}
              titleId="team-title"
            />
            <ul className="mt-6 grid gap-3">
              {copy.team.bullets.map((bullet) => (
                <li
                  key={bullet}
                  className="flex items-start gap-2.5 text-sm text-muted"
                >
                  <CheckIcon className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                  <span>{bullet}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="role-card">
            <div className="flex items-center justify-between gap-3">
              <h3 className="text-base font-semibold">
                {copy.team.card.title}
              </h3>
              <Badge tone="mint">
                <KeyIcon className="h-3 w-3" />
                {copy.team.card.chip}
              </Badge>
            </div>

            <div className="mt-4">
              {copy.team.card.rows.map((row) => (
                <div key={row.role} className="role-row">
                  <span
                    className="role-dot"
                    data-tone={row.tone}
                    aria-hidden="true"
                  />
                  <span className="role-name">{row.role}</span>
                  <span className="role-meta">{row.meta}</span>
                </div>
              ))}
            </div>

            <div className="mt-4 flex items-center gap-2 border-t border-line pt-4 text-xs text-muted">
              <KeyIcon className="h-3.5 w-3.5 text-accent" />
              {copy.team.card.footer}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
