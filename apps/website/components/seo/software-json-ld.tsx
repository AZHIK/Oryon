import desktopShot from "@/assets/images/product_screenshots/desktop_shot.png";
import { copy } from "@/content";
import { isMainFeatureShipped } from "@/lib/features";
import { siteConfig, siteUrl } from "@/site.config";

export function SoftwareJsonLd() {
  const data = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.name,
    applicationCategory: "BusinessApplication",
    operatingSystem: "Windows",
    description: siteConfig.description,
    url: siteUrl,
    inLanguage: "en",
    screenshot: new URL(desktopShot.src, siteUrl).toString(),
    featureList: copy.features.items
      .filter((item) => isMainFeatureShipped(item.key))
      .map((item) => item.title),
    publisher: {
      "@type": "Organization",
      name: siteConfig.name,
      url: siteUrl,
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, "\\u003c"),
      }}
    />
  );
}
