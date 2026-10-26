/**
 * Single source of truth for the product identity, contact details and
 * download/store links.
 *
 * Nothing in `app/` or `components/` may hardcode the product name, tagline or
 * domain. Import this file instead.
 *
 * Empty strings are intentional: the UI renders a polished "Coming soon"
 * state and CONTENT_TODO.md records the gap. Never point these at a dead URL.
 */

export type FeatureStatus = "shipped" | "coming-soon";

/**
 * Flip a flag to "shipped" on the day the capability is actually available to
 * customers. The marketing site must not claim unshipped capabilities.
 */
export const FEATURES_STATUS = {
  offlineSales: "shipped",
  offlineInventory: "shipped",
  staffRoles: "shipped",
  sharedDevicePinLogin: "shipped",
  salesHistory: "shipped",
  excelExport: "shipped",
  pdfExport: "shipped",
  recipesAndProduction: "coming-soon",
  aiInsights: "coming-soon",
  advancedReports: "coming-soon",
} as const satisfies Record<string, FeatureStatus>;

export type DownloadInfo = {
  /** Direct installer URL. Empty string means "not published yet". */
  url: string;
  /** Human-readable version, for example "1.0.0". */
  version: string;
  /** Installer size in megabytes. 0 hides the size. */
  sizeMb: number;
  /** Lower-case or upper-case SHA-256 hex digest. */
  sha256: string;
  /** Supported operating systems, written for a restaurant owner. */
  minOs: string;
  /** Whether the installer is code-signed. Drives the SmartScreen note. */
  signed: boolean;
};

export type StoreKey = "googlePlay" | "appStore";

export type Stores = Record<StoreKey, string>;

export const DOWNLOADS: {
  windows: DownloadInfo;
  macos?: DownloadInfo;
  androidApk?: DownloadInfo;
} = {
  windows: {
    url: "",
    version: "",
    sizeMb: 0,
    sha256: "",
    minOs: "Windows 10 or later, 64-bit",
    signed: false,
  },
  // macos: { ... } is hidden automatically until a URL is configured.
  // androidApk: { ... } is hidden automatically until a URL is configured.
};

const STORES: Stores = {
  googlePlay: "",
  appStore: "",
};

export const siteConfig = {
  name: "Oryon",
  tagline: "Run your restaurant, even offline.",
  description:
    "The offline-first restaurant app for Tanzania. Sell, track stock, manage your team and export reports — even when the internet drops.",
  domain: "oryonfoods.com",
  locale: "en_TZ",
  contact: {
    /**
     * WhatsApp number in international format, digits only
     * (for example "255712345678"). Empty means "coming soon".
     */
    whatsapp: "",
    /** Support email address. Empty means "coming soon". */
    email: "",
  },
  stores: STORES,
  downloads: DOWNLOADS,
};

/** Derived once so the domain is written down in exactly one place. */
export const siteUrl = `https://${siteConfig.domain}`;

export function hasWhatsApp(): boolean {
  return siteConfig.contact.whatsapp.replace(/\D/g, "").length > 0;
}

export function hasEmail(): boolean {
  return siteConfig.contact.email.trim().length > 0;
}

export function isDownloadAvailable(download: DownloadInfo | undefined): boolean {
  return Boolean(download?.url.trim());
}

export function isStoreAvailable(store: StoreKey): boolean {
  return siteConfig.stores[store].trim().length > 0;
}
