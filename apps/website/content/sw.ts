import { siteConfig } from "@/site.config";

import type { Copy } from "./en";

/**
 * ⚠️ DRAFT — machine-assisted Swahili.
 * NEEDS NATIVE-SPEAKER REVIEW before this locale is shown to visitors.
 *
 * Do not enable `sw` in the locale switcher or ship it as final copy until a
 * native speaker has reviewed every string.
 */
export const SW_REVIEW_STATUS =
  "DRAFT — needs native-speaker review" as const;

export const sw: Copy = {
  meta: {
    home: {
      title: "Endesha mgahawa wako, hata bila mtandao.",
      description:
        "Programu ya mikahawa inayofanya kazi bila mtandao kwa Tanzania. Uza, fuatilia bidhaa, simamia timu yako na toa ripoti — hata mtandao unapokatika.",
    },
    download: {
      title: "Pakua",
      description:
        "Pakua kifungu cha Windows au tafuta orodha za Google Play na App Store za programu ya mgahawa.",
    },
  },
  nav: {
    homeLabel: `Nyumbani ya ${siteConfig.name}`,
    links: [
      { label: "Vipengele", href: "/#features" },
      { label: "Inavyofanya kazi", href: "/#how-it-works" },
      { label: "Bila mtandao", href: "/#offline" },
      { label: "Timu", href: "/#team" },
    ],
    download: "Pakua",
    primaryLabel: "Menyu kuu",
    mobilePrimaryLabel: "Menyu kuu ya simu",
    openMenu: "Fungua menyu",
    closeMenu: "Funga menyu",
    skipToContent: "Ruka hadi maudhui",
  },
  hero: {
    eyebrow: "Imeundwa kwa mikahawa ya Tanzania",
    title: "Endesha mgahawa wako, hata bila mtandao.",
    description:
      "Mauzo, bidhaa, wafanyakazi na ripoti. Tayari mtandao usipokuwepo.",
    primaryCta: "Pakua kwa Windows",
    soonChip: "Hivi karibuni",
    primaryNoteSoon:
      "Kifungu cha Windows kinakuja hivi karibuni. Tazama kinachojumuishwa na unachohitaji.",
    primaryNoteReady: "Windows 10 au zaidi · 64-bit",
    downloadDetails: "Tazama maelezo ya kupakua",
    secondaryCta: "Tazama programu",
    previewAlt: "Onyesho la dirisha la mauzo na programu ya simu",
    previewLabel: "Onyesho la bidhaa",
    previewNote: "Data ni mfano.",
    offlineBadge: "Inafanya kazi bila mtandao",
    capabilities: [
      "Inafanya kazi bila mtandao",
      "Imeundwa kwa mikahawa",
      "Majukumu ya wafanyakazi",
      "Ripoti za Excel na PDF",
    ],
  },
  stores: {
    googlePlayAlt: "Pata kwenye Google Play",
    appStoreAlt: "Pakua kwenye App Store",
    comingSoon: "Inakuja hivi karibuni",
    noteBothSoon:
      "Orodha za Google Play na App Store zinakuja hivi karibuni.",
    noteGoogleSoon: "Orodha ya Google Play inakuja hivi karibuni.",
    noteAppSoon: "Orodha ya App Store inakuja hivi karibuni.",
    noteBothLive: "Pia zinapatikana kwenye Google Play na App Store.",
    opensInNewTab: "hufunguka kwenye kichupo kipya",
  },
  preview: {
    label: "Onyesho la bidhaa",
    note: "Data ni mfano.",
    desktop: {
      windowTitle: "Mauzo mapya",
      search: "Tafuta menyu",
      categories: ["Zote", "Chakula", "Vinywaji"],
      items: [
        { name: "Ugali", price: "TZS 3,000", tone: "terracotta" },
        { name: "Pilau", price: "TZS 6,500", tone: "gold" },
        { name: "Kuku", price: "TZS 12,000", tone: "sage" },
        { name: "Chapati", price: "TZS 1,500", tone: "gold" },
        { name: "Mchicha", price: "TZS 4,000", tone: "sage" },
        { name: "Soda", price: "TZS 2,000", tone: "terracotta" },
      ],
      ticketTitle: "Meza 4",
      ticketSubtitle: "Vitu 3",
      ticketLines: [
        { name: "Pilau", qty: "1", price: "6,500" },
        { name: "Kuku", qty: "1", price: "12,000" },
        { name: "Soda", qty: "2", price: "4,000" },
      ],
      totalLabel: "Jumla",
      total: "TZS 22,500",
      charge: "Toza",
    },
    phone: {
      statusTime: "9:41",
      title: "Leo",
      total: "TZS 184,500",
      sales: "Mauzo 18",
      chartLabel: "Mauzo wiki hii",
      recentLabel: "Hivi karibuni",
      rows: [
        { name: "Pilau", meta: "Meza 2", price: "6,500" },
        { name: "Soda × 3", meta: "Kaunta", price: "6,000" },
        { name: "Chapati × 2", meta: "Kuchukua", price: "3,000" },
      ],
      tabs: ["Uza", "Bidhaa", "Ripoti"],
    },
  },
  downloadPage: {
    eyebrow: "Vipakuliwa",
    title: "Kifungu kiko karibu kuwa tayari.",
    description:
      "Tunatayarisha toleo la Windows na orodha za Google Play na App Store. Hadi wakati huo, unaweza kuona programu inavyofanya kazi na jinsi mauzo yanavyokwenda.",
    backHome: "Rudi nyumbani",
    seeFeatures: "Tazama programu inavyofanya kazi",
  },
  common: {
    comingSoon: "Inakuja hivi karibuni",
    copy: "Nakili",
    copied: "Imenakiliwa",
    learnMore: "Jifunze zaidi",
  },
};
