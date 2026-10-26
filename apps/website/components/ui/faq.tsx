import { cn } from "@/lib/cn";

type FaqItem = {
  question: string;
  answer: string;
};

export function Faq({
  items,
  className,
}: {
  items: readonly FaqItem[];
  className?: string;
}) {
  return (
    <div className={cn("faq-list", className)}>
      {items.map((item) => (
        <details key={item.question} className="faq-item">
          <summary className="faq-summary">
            <span>{item.question}</span>
            <span className="faq-icon" aria-hidden="true">
              +
            </span>
          </summary>
          <div className="faq-answer">
            <p>{item.answer}</p>
          </div>
        </details>
      ))}
    </div>
  );
}
