import type { Metadata } from "next";

import { siteConfig, siteUrl } from "@/site.config";

type PageMetadataInput = {
  title: string;
  description: string;
  /** Root-relative path with a trailing slash, for example "/download/". */
  path: string;
  noIndex?: boolean;
};

export function buildMetadata({
  title,
  description,
  path,
  noIndex = false,
}: PageMetadataInput): Metadata {
  const socialTitle = `${title} — ${siteConfig.name}`;
  const canonical = path;

  return {
    title,
    description,
    alternates: { canonical },
    openGraph: {
      type: "website",
      siteName: siteConfig.name,
      locale: siteConfig.locale,
      title: socialTitle,
      description,
      url: canonical,
      images: [
        {
          url: "/og.png",
          width: 1200,
          height: 630,
          alt: `${siteConfig.name} — ${siteConfig.tagline}`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: ["/og.png"],
    },
    ...(noIndex ? { robots: { index: false, follow: false } } : {}),
  };
}

export const baseMetadata: Metadata = {
  metadataBase: new URL(siteUrl),
  applicationName: siteConfig.name,
  title: {
    default: `${siteConfig.name} — ${siteConfig.tagline}`,
    template: `%s — ${siteConfig.name}`,
  },
  description: siteConfig.description,
  alternates: { canonical: "/" },
  formatDetection: { telephone: false, address: false, email: false },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
};
