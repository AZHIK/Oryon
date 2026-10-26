import Link from "next/link";

import { ChevronLeftIcon, ClockIcon } from "@/components/icons";
import { copy } from "@/content";

type LegalSection = {
  heading: string;
  paragraphs: readonly string[];
};

type LegalPageProps = {
  eyebrow: string;
  title: string;
  lastUpdated: string;
  draft: string;
  intro: string;
  sections: readonly LegalSection[];
};

export function LegalPage({
  eyebrow,
  title,
  lastUpdated,
  draft,
  intro,
  sections,
}: LegalPageProps) {
  return (
    <div className="bg-app">
      <section className="pt-[calc(4.5rem+clamp(2.5rem,5vw,4rem))] pb-[clamp(4rem,8vw,7rem)]">
        <div className="container-narrow">
          <article className="card p-6 sm:p-10">
            <p className="eyebrow">{eyebrow}</p>
            <h1 className="type-h2 mt-3">{title}</h1>
            <p className="mt-2 text-xs text-muted">{lastUpdated}</p>

            <div className="draft-note mt-5">
              <ClockIcon className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{draft}</span>
            </div>

            <div className="legal-prose mt-7">
              <p>{intro}</p>
              {sections.map((section) => (
                <section key={section.heading}>
                  <h2>{section.heading}</h2>
                  {section.paragraphs.map((paragraph) => (
                    <p key={paragraph}>{paragraph}</p>
                  ))}
                </section>
              ))}
            </div>
          </article>

          <div className="mt-6">
            <Link href="/" className="text-link">
              <ChevronLeftIcon className="h-3.5 w-3.5" />
              {copy.common.backHome}
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
