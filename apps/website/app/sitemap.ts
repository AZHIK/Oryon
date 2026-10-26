import type { MetadataRoute } from "next";

import { siteUrl } from "@/site.config";

export const dynamic = "force-static";

const routes = [
  { path: "/", changeFrequency: "monthly" as const, priority: 1 },
  { path: "/download/", changeFrequency: "monthly" as const, priority: 0.9 },
  { path: "/support/", changeFrequency: "monthly" as const, priority: 0.6 },
  { path: "/privacy/", changeFrequency: "yearly" as const, priority: 0.3 },
  { path: "/terms/", changeFrequency: "yearly" as const, priority: 0.3 },
];

export default function sitemap(): MetadataRoute.Sitemap {
  return routes.map((route) => ({
    url: `${siteUrl}${route.path}`,
    changeFrequency: route.changeFrequency,
    priority: route.priority,
  }));
}
