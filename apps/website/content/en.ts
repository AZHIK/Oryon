import { siteConfig } from "@/site.config";

/**
 * English copy — the only locale currently shipped.
 *
 * The product name, tagline and domain are interpolated from site.config.ts.
 * Never replace these placeholders with a literal name.
 */
export const en = {
  meta: {
    home: {
      title: siteConfig.tagline,
      description: siteConfig.description,
    },
    download: {
      title: "Download",
      description:
        "Download the Windows installer or find the Google Play and App Store listings for the restaurant app.",
    },
  },
  nav: {
    homeLabel: `${siteConfig.name} home`,
    links: [
      { label: "Features", href: "/#features" },
      { label: "How it works", href: "/#how-it-works" },
      { label: "Offline", href: "/#offline" },
      { label: "Team", href: "/#team" },
    ],
    download: "Download",
    primaryLabel: "Primary",
    mobilePrimaryLabel: "Mobile primary",
    openMenu: "Open menu",
    closeMenu: "Close menu",
    skipToContent: "Skip to content",
  },
  hero: {
    eyebrow: "Built for restaurants in Tanzania",
    title: siteConfig.tagline,
    description:
      "Sales, stock, staff and reports. Ready when the internet isn’t.",
    primaryCta: "Download for Windows",
    soonChip: "Soon",
    primaryNoteSoon:
      "The Windows installer is coming soon. See what’s included and what you’ll need.",
    primaryNoteReady: "Windows 10 or later · 64-bit",
    downloadDetails: "See download details",
    secondaryCta: "See the app",
    previewAlt: "Preview of the point-of-sale window and the phone app",
    previewLabel: "Product preview",
    previewNote: "Sample data.",
    offlineBadge: "Works offline",
    capabilities: [
      "Works offline",
      "Built for restaurants",
      "Staff roles",
      "Excel and PDF reports",
    ],
  },
  stores: {
    googlePlayAlt: "Get it on Google Play",
    appStoreAlt: "Download on the App Store",
    comingSoon: "Coming soon",
    noteBothSoon: "Google Play and App Store listings are coming soon.",
    noteGoogleSoon: "The Google Play listing is coming soon.",
    noteAppSoon: "The App Store listing is coming soon.",
    noteBothLive: "Also available on Google Play and the App Store.",
    opensInNewTab: "opens in a new tab",
  },
  preview: {
    label: "Product preview",
    note: "Sample data.",
    desktop: {
      windowTitle: "New sale",
      search: "Search menu",
      categories: ["All", "Mains", "Drinks"],
      items: [
        { name: "Ugali", price: "TZS 3,000", tone: "terracotta" },
        { name: "Pilau", price: "TZS 6,500", tone: "gold" },
        { name: "Kuku", price: "TZS 12,000", tone: "sage" },
        { name: "Chapati", price: "TZS 1,500", tone: "gold" },
        { name: "Mchicha", price: "TZS 4,000", tone: "sage" },
        { name: "Soda", price: "TZS 2,000", tone: "terracotta" },
      ],
      ticketTitle: "Table 4",
      ticketSubtitle: "3 items",
      ticketLines: [
        { name: "Pilau", qty: "1", price: "6,500" },
        { name: "Kuku", qty: "1", price: "12,000" },
        { name: "Soda", qty: "2", price: "4,000" },
      ],
      totalLabel: "Total",
      total: "TZS 22,500",
      charge: "Charge",
    },
    phone: {
      statusTime: "9:41",
      title: "Today",
      total: "TZS 184,500",
      sales: "18 sales",
      chartLabel: "Sales this week",
      recentLabel: "Recent",
      rows: [
        { name: "Pilau", meta: "Table 2", price: "6,500" },
        { name: "Soda × 3", meta: "Counter", price: "6,000" },
        { name: "Chapati × 2", meta: "Takeaway", price: "3,000" },
      ],
      tabs: ["Sell", "Stock", "Reports"],
    },
  },
  downloadPage: {
    eyebrow: "Downloads",
    title: "The installer is almost ready.",
    description:
      "We’re preparing the Windows build and the Google Play and App Store listings. Until then, you can see what the app does and how a sale works.",
    backHome: "Back to home",
    seeFeatures: "See what the app does",
  },
  common: {
    comingSoon: "Coming soon",
    copy: "Copy",
    copied: "Copied",
    learnMore: "Learn more",
  },
};

export type Copy = typeof en;
