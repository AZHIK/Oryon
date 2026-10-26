import type { Metadata } from "next";

import { FaqSection } from "@/components/home/faq-section";
import { FeatureBento } from "@/components/home/feature-bento";
import { FinalCta } from "@/components/home/final-cta";
import { Hero } from "@/components/home/hero";
import { HowItWorks } from "@/components/home/how-it-works";
import { OfflineSection } from "@/components/home/offline-section";
import { PlatformsSection } from "@/components/home/platforms-section";
import { TeamSection } from "@/components/home/team-section";
import { SoftwareJsonLd } from "@/components/seo/software-json-ld";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.home.title,
  description: copy.meta.home.description,
  path: "/",
});

export default function HomePage() {
  return (
    <>
      <Hero />
      <FeatureBento />
      <HowItWorks />
      <OfflineSection />
      <TeamSection />
      <PlatformsSection />
      <FaqSection />
      <FinalCta />
      <SoftwareJsonLd />
    </>
  );
}
