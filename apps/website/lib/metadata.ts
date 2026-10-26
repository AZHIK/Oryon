import type { Metadata } from "next";

import desktopShot from "@/assets/images/product_screenshots/desktop_shot.png";
import { siteConfig, siteUrl } from "@/site.config";

const socialImage = new URL(desktopShot.src, siteUrl).toString();
const socialImageAlt = `${siteConfig.name} dashboard — ${siteConfig.tagline}`;

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
          url: socialImage,
          width: desktopShot.width,
          height: desktopShot.height,
          alt: socialImageAlt,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: [socialImage],
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
