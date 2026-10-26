import { TextLink } from "@/components/ui/text-link";
import { Faq } from "@/components/ui/faq";
import { SectionHeading } from "@/components/ui/section-heading";
import { copy } from "@/content";

export function FaqSection() {
  return (
    <section
      id="faq"
      aria-labelledby="faq-title"
      className="section border-t border-line bg-surface"
    >
      <div className="container-page">
        <div className="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
          <div>
            <SectionHeading
              eyebrow={copy.faq.eyebrow}
              title={copy.faq.title}
              description={copy.faq.description}
              titleId="faq-title"
            />
            <div className="mt-6">
              <TextLink href="/support">{copy.faq.supportCta}</TextLink>
            </div>
          </div>

          <Faq items={copy.faq.items} />
        </div>
      </div>
    </section>
  );
}
