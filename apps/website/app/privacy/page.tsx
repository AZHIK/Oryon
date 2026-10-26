import type { Metadata } from "next";

import { LegalPage } from "@/components/legal/legal-page";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.privacy.title,
  description: copy.meta.privacy.description,
  path: "/privacy/",
});

export default function PrivacyPage() {
  return (
    <LegalPage
      eyebrow={copy.privacyPage.eyebrow}
      title={copy.privacyPage.title}
      lastUpdated={copy.privacyPage.lastUpdated}
      draft={copy.privacyPage.draft}
      intro={copy.privacyPage.intro}
      sections={copy.privacyPage.sections}
    />
  );
}
