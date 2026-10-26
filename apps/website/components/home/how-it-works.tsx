import { SectionHeading } from "@/components/ui/section-heading";
import { copy } from "@/content";

export function HowItWorks() {
  return (
    <section
      id="how-it-works"
      aria-labelledby="how-title"
      className="section bg-app"
    >
      <div className="container-page">
        <SectionHeading
          eyebrow={copy.howItWorks.eyebrow}
          title={copy.howItWorks.title}
          description={copy.howItWorks.description}
          titleId="how-title"
          align="center"
        />

        <div className="steps-grid">
          {copy.howItWorks.steps.map((step, index) => (
            <article key={step.title} className="step-card">
              <span className="step-number">
                {String(index + 1).padStart(2, "0")}
              </span>
              <h3 className="type-h3 mt-4">{step.title}</h3>
              <p className="step-copy">{step.description}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
