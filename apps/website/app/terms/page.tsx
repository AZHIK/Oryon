import type { Metadata } from "next";

import { LegalPage } from "@/components/legal/legal-page";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.terms.title,
  description: copy.meta.terms.description,
  path: "/terms/",
});

export default function TermsPage() {
  return (
    <LegalPage
      eyebrow={copy.termsPage.eyebrow}
      title={copy.termsPage.title}
      lastUpdated={copy.termsPage.lastUpdated}
      draft={copy.termsPage.draft}
      intro={copy.termsPage.intro}
      sections={copy.termsPage.sections}
    />
  );
}
