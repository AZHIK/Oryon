import type { Metadata } from "next";

import { Hero } from "@/components/home/hero";
import { copy } from "@/content";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.home.title,
  description: copy.meta.home.description,
  path: "/",
});

export default function HomePage() {
  return <Hero />;
}
