import { siteConfig } from "@/site.config";

const brand = siteConfig.name;

/**
 * English copy — the only locale currently shipped.
 *
 * The product name, tagline and domain are interpolated from site.config.ts.
 * Never replace these with a literal name.
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
        `Download ${brand} for Windows, or find the Google Play and App Store listings as they are published.`,
    },
    support: {
      title: "Support",
      description:
        `Answers to common questions about ${brand}, plus the ways to reach the team.`,
    },
    privacy: {
      title: "Privacy policy",
      description:
        `How ${brand} handles phone numbers, business data and the information stored on your device.`,
    },
    terms: {
      title: "Terms of use",
      description:
        `The terms that apply when you use the ${brand} restaurant app and website.`,
    },
  },
  nav: {
    homeLabel: `${siteConfig.name} home`,
    links: [
      { label: "Product", href: "/#product" },
      { label: "Features", href: "/#features" },
      { label: "How it works", href: "/#how-it-works" },
      { label: "Team", href: "/#team" },
      { label: "Support", href: "/support" },
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
      `Sales, stock, staff and reports in one calm app. Keep serving when the internet drops — ${brand} catches up when it returns.`,
    primaryCta: "Download for Windows",
    primaryCtaSoon: "Download options",
    secondaryCta: "See what it does",
    primaryNoteReady: "Windows 10 or later · 64-bit",
    primaryNoteSoon:
      "The Windows installer is coming soon. See the download options.",
    desktopAlt:
      `The ${brand} desktop dashboard showing sales, orders, staff, stock and finance in one view.`,
    mobileAlt:
      `The ${brand} mobile dashboard with quick actions for sales, stock, insights and staff.`,
    offlineBadge: "Works offline",
    previewLabel: "Product preview",
    capabilities: [
      {
        key: "offline",
        title: "Sell offline",
        description: "Keep the counter moving.",
        tone: "mint",
      },
      {
        key: "inventory",
        title: "Track stock",
        description: "Groceries and menu items.",
        tone: "blue",
      },
      {
        key: "team",
        title: "Staff roles",
        description: "One device, own PIN.",
        tone: "purple",
      },
      {
        key: "reports",
        title: "Excel and PDF",
        description: "Reports you can share.",
        tone: "orange",
      },
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
  features: {
    eyebrow: "One calm workspace",
    title: "Built for the way a restaurant actually runs.",
    description:
      "Fewer tabs, fewer handwritten notes, fewer surprises at closing time. The essentials sit together and keep working when the signal does not.",
    items: [
      {
        key: "offline",
        title: "Sales that do not wait for signal",
        description:
          `Take orders and record payments offline. ${brand} saves the sale on the device and syncs it when the connection returns.`,
        tone: "mint",
      },
      {
        key: "recipes",
        title: "Recipes and production",
        description:
          "Cost a dish and follow prep from ingredients to plate, so the kitchen and the stock record stay aligned.",
        tone: "orange",
      },
      {
        key: "inventory",
        title: "Stock you can trust",
        description:
          "Track groceries and menu items as you sell, receive and adjust. See what is running low before service does.",
        tone: "blue",
      },
      {
        key: "team",
        title: "One device, every role",
        description:
          "Give each person their own staff role and a shared-device PIN login. Access follows the role you set.",
        tone: "purple",
      },
      {
        key: "reports",
        title: "Reports ready to share",
        description:
          "Review sales history and export clean Excel or PDF files for your records, your accountant or your bank.",
        tone: "orange",
      },
      {
        key: "dashboard",
        title: "A calmer view of today",
        description:
          "Sales, orders, staff and stock sit together on one dashboard, so the next decision is easier to see.",
        tone: "mint",
      },
    ],
    comingSoon: {
      title: "On the way",
      description:
        "We add capabilities only when they are ready for a real service.",
      badge: "Coming soon",
      items: [
        {
          key: "electronicPayments",
          title: "QR and card payments",
          description:
            "Let guests scan a QR code or pay by card, then reconcile those payments with the day’s sales.",
          badge: "",
        },
        {
          key: "aiMode",
          title: "AI mode",
          description:
            "A restaurant agent that handles the repetitive work. It prepares the daily summary, watches stock and suggests the next step, so you can stay on the floor.",
          badge: "Agent",
        },
        {
          key: "advancedReports",
          title: "Advanced reports",
          description:
            "Deeper views for owners who want to dig further.",
          badge: "",
        },
      ],
    },
  },
  howItWorks: {
    eyebrow: "A sale, start to finish",
    title: "From the first tap to the day’s report.",
    description:
      `${brand} keeps the routine short, whether the connection is strong or the counter is busy.`,
    steps: [
      {
        title: "Add the order",
        description:
          "Tap items from the menu. Quantities and prices update as you go.",
      },
      {
        title: "Take payment",
        description:
          "Record the sale in TZS and keep the queue moving.",
      },
      {
        title: "Hand over the receipt",
        description:
          "Print or share a receipt, then start the next sale.",
      },
      {
        title: "Sync when online",
        description:
          "Sales and stock changes upload in the background when a connection returns.",
      },
    ],
  },
  offline: {
    eyebrow: "Offline-first",
    title: "The internet can drop. Service does not have to.",
    description:
      `${brand} keeps a local copy of your menu, stock and sales on the device. Sell, take payment and update stock while offline. When a connection returns, it catches up automatically.`,
    bullets: [
      "Sales and receipts stay on the device.",
      "Stock changes queue until they can sync.",
      "A clear status shows staff what is saved.",
    ],
    card: {
      title: "This device",
      status: "Offline",
      rows: [
        "Sale saved",
        "Stock updated",
        "Receipt ready",
      ],
      footerTitle: "Waiting to sync",
      footerCopy: `${brand} will retry automatically when the connection returns.`,
    },
  },
  team: {
    eyebrow: "Your team",
    title: "One app, your whole team.",
    description:
      "Every person signs in on the shared device with their own PIN. Roles keep the right screens and actions in the right hands — without separate logins for every shift.",
    bullets: [
      "Staff roles and permissions.",
      "Shared-device PIN login.",
      "A simple handover at shift change.",
    ],
    card: {
      title: "Staff on this device",
      chip: "PIN login",
      rows: [
        { role: "Owner", tone: "violet", meta: "Full access" },
        { role: "Manager", tone: "cyan", meta: "Day-to-day operations" },
        { role: "Cashier", tone: "amber", meta: "Selling and receipts" },
        { role: "Kitchen", tone: "magenta", meta: "Stock and kitchen" },
      ],
      footer: "Each person signs in with their own role.",
    },
  },
  platforms: {
    eyebrow: "Where you work",
    title: `Use ${brand} on the devices you already have.`,
    description:
      "Start with the Windows app at the counter. The phone apps are being prepared for the stores.",
    windows: {
      title: "Windows",
      description: "The full app for your counter desktop.",
      requirement: "Windows 10 or later, 64-bit",
      cta: "See Windows details",
    },
    googlePlay: {
      title: "Google Play",
      description: "Sell, check stock and review the day from your phone.",
    },
    appStore: {
      title: "App Store",
      description: "The same calm workspace, built for iPhone.",
    },
    statusAvailable: "Available",
    statusComingSoon: "Coming soon",
    note: "Download options will appear here as each release is published.",
    cta: "See all download options",
  },
  faq: {
    eyebrow: "Good to know",
    title: "Questions restaurant owners ask.",
    description:
      "Short answers about offline work, staff, reports and getting started.",
    supportCta: "Visit support",
    items: [
      {
        question: `Does ${brand} work without internet?`,
        answer:
          `Yes. Selling, receipts, stock changes and staff actions keep working on the device. ${brand} syncs them when a connection returns.`,
      },
      {
        question: "What can I use offline?",
        answer:
          "Sales, receipts, inventory for groceries and menu items, sales history, and staff roles with shared-device PIN login.",
      },
      {
        question: "Can staff share one device?",
        answer:
          "Yes. Each person has their own role and signs in with a PIN, so actions stay tied to the right person.",
      },
      {
        question: "Can I export my sales?",
        answer:
          `Yes. ${brand} exports sales history to Excel and PDF, ready to share or keep for your records.`,
      },
      {
        question: "What do I need to run it?",
        answer:
          "The Windows app needs Windows 10 or later, 64-bit. The Google Play and App Store listings are coming soon.",
      },
      {
        question: "Is my data safe?",
        answer:
          `The app keeps its local database encrypted on your device and syncs it to your ${brand} workspace. This website does not use advertising trackers.`,
      },
    ],
  },
  cta: {
    eyebrow: "Ready when you are",
    title: "A calmer restaurant starts with one app.",
    description:
      `See what ${brand} can do, or go straight to the download options.`,
    primary: "See download options",
    secondary: "Talk to support",
    noteSoon: "Windows installer coming soon.",
    noteReady: "Windows 10 or later, 64-bit.",
  },
  footer: {
    blurb:
      "The offline-first restaurant app for Tanzania. Sell, track stock, manage your team and export reports — even when the internet drops.",
    productHeading: "Product",
    downloadHeading: "Download",
    companyHeading: "Company",
    productLinks: [
      { label: "Features", href: "/#features" },
      { label: "How it works", href: "/#how-it-works" },
      { label: "Offline", href: "/#offline" },
      { label: "Team", href: "/#team" },
      { label: "Platforms", href: "/#platforms" },
    ],
    downloadLinks: [
      { label: "All download options", href: "/download" },
      { label: "Windows", href: "/download" },
      { label: "Google Play", href: "/download" },
      { label: "App Store", href: "/download" },
    ],
    companyLinks: [
      { label: "Support", href: "/support" },
      { label: "Privacy", href: "/privacy" },
      { label: "Terms", href: "/terms" },
    ],
    contactHeading: "Contact",
    whatsapp: "WhatsApp",
    email: "Email",
    contactSoon: "WhatsApp and email support are being set up.",
    copyright: `© ${new Date().getFullYear()} ${siteConfig.name}. All rights reserved.`,
    builtFor: "For restaurants in Tanzania.",
  },
  downloadPage: {
    eyebrow: "Download",
    title: `Take ${brand} to the counter.`,
    description:
      "Install Oryon on a Windows counter or a phone. Here is what you need, and what is ready today.",
    backHome: "Back to home",
    statusReady: "Available now",
    statusSoon: "Coming soon",
    windows: {
      title: `${brand} for Windows`,
      description:
        "The full app: sales, stock, staff, reports and the dashboard.",
      download: "Download for Windows",
      comingSoon: "Installer coming soon",
      versionLabel: "Version",
      sizeLabel: "Size",
      checksumLabel: "SHA-256",
      minOsLabel: "Works on",
      copy: "Copy checksum",
      copied: "Copied",
      waiting:
        "Version, size and checksum will appear here when the release is published.",
      installTitle: "How to install",
      installSteps: [
        "Download the installer and open it.",
        `Follow the prompts, then open ${brand} from the Start menu.`,
        "Sign in with your phone number and start selling.",
      ],
      smartScreenTitle: "About Windows SmartScreen",
      smartScreenBody:
        "Because this installer is not code-signed, Windows may show a SmartScreen warning. Choose “More info”, then “Run anyway” only if you downloaded the file from this site.",
      smartScreenSigned:
        "This installer is code-signed. Windows should recognise the publisher.",
      note:
        "Your data stays on this device and syncs when you are online.",
    },
    stores: {
      title: `${brand} on your phone`,
      description:
        "The Google Play and App Store listings are being prepared.",
      googlePlay: "Google Play",
      appStore: "App Store",
      comingSoon: "Coming soon",
    },
    helpTitle: "Need a hand?",
    helpDescription:
      "Visit support for answers to common questions about setup and offline work.",
    helpCta: "Go to support",
  },
  supportPage: {
    eyebrow: "Support",
    title: "How can we help?",
    description:
      "Answers to common questions, and the ways to reach the team as they come online.",
    contactTitle: "Talk to us",
    contactDescription:
      "WhatsApp and email support are being set up. They will appear here as soon as they are live.",
    whatsappTitle: "WhatsApp",
    whatsappDescription: "The quickest way to reach the team.",
    emailTitle: "Email",
    emailDescription: "For account and setup questions.",
    comingSoon: "Coming soon",
    openWhatsApp: "Open WhatsApp",
    sendEmail: "Send email",
    downloadTitle: "Looking for the app?",
    downloadDescription:
      "See the Windows and mobile options, including what is ready today.",
    downloadCta: "Go to downloads",
  },
  privacyPage: {
    eyebrow: "Legal",
    title: "Privacy policy",
    lastUpdated: "Last updated 26 October 2026",
    draft: "Draft — pending legal review",
    intro:
      `This policy explains what ${brand} collects, why we collect it, and the choices you have. It is written for restaurant owners using the app in Tanzania.`,
    sections: [
      {
        heading: "What we collect",
        paragraphs: [
          "Account details: your phone number is used to sign in with a one-time code sent by SMS. If you add an email address or business profile, we store those details too.",
          "Business data: the sales, payments, inventory, suppliers, staff roles, stores and reports you create in the app. This is the information that makes your workspace work.",
          "Device data: the app stores a local database on the device so it can keep working offline. The database is encrypted at rest.",
        ],
      },
      {
        heading: "How we use it",
        paragraphs: [
          `We use your information to run your ${brand} workspace, sync data between your devices, provide support, keep the service secure and improve the product.`,
          "We do not sell your business data. We do not use advertising trackers on this website.",
        ],
      },
      {
        heading: "Who can see it",
        paragraphs: [
          "You and the staff you invite can see the data allowed by their roles. Our service providers process data only to run the service, for example SMS delivery and email delivery.",
          "We may disclose information if the law requires it or if it is necessary to protect the service and its users.",
        ],
      },
      {
        heading: "Where it is stored",
        paragraphs: [
          "Your local data stays on the device. Synced data is stored on servers used to operate the service. We use reasonable technical and organisational measures to protect it.",
        ],
      },
      {
        heading: "Your choices",
        paragraphs: [
          "You can review and update business details in the app. You can ask us about access, correction or deletion of your account data by contacting support. Some records may need to be kept for legal or accounting reasons.",
        ],
      },
      {
        heading: "Contact",
        paragraphs: [
          "Questions about this policy can be sent through the support page. Contact channels are being set up, and this draft will be updated when they are live.",
        ],
      },
    ],
  },
  termsPage: {
    eyebrow: "Legal",
    title: "Terms of use",
    lastUpdated: "Last updated 26 October 2026",
    draft: "Draft — pending legal review",
    intro:
      `These terms apply when you use the ${brand} app and website. By using ${brand}, you agree to them.`,
    sections: [
      {
        heading: "Your account",
        paragraphs: [
          "You need a phone number to sign in. Keep your one-time codes and staff PINs private. You are responsible for the activity on your account and for the roles you assign to staff.",
        ],
      },
      {
        heading: "Using the app",
        paragraphs: [
          `${brand} is a restaurant operations tool. Use it lawfully and only for businesses you are authorised to manage. Do not attempt to disrupt the service, access another business’s data, or reverse engineer the app.`,
        ],
      },
      {
        heading: "Offline data and sync",
        paragraphs: [
          "The app keeps a local copy of your data so it can work offline. It syncs when a connection is available. If you uninstall the Windows app before data has synced, the local database and its encryption key are removed and unsynced records may be lost.",
        ],
      },
      {
        heading: "Availability",
        paragraphs: [
          `We work to keep ${brand} available and accurate, but we cannot promise uninterrupted service. Maintenance, connectivity and third-party providers can affect sync and sign-in.`,
        ],
      },
      {
        heading: "Our content",
        paragraphs: [
          `The ${brand} name, logo, software and website content belong to their owners. You may not copy or redistribute them without permission.`,
        ],
      },
      {
        heading: "Changes",
        paragraphs: [
          "We may update these terms as the product changes. The latest version will be published here. If a change is significant, we will make that clear before it takes effect.",
        ],
      },
      {
        heading: "Contact",
        paragraphs: [
          "Questions about these terms can be sent through the support page. Contact channels are being set up, and this draft will be updated when they are live.",
        ],
      },
    ],
  },
  common: {
    comingSoon: "Coming soon",
    copy: "Copy",
    copied: "Copied",
    learnMore: "Learn more",
    opensInNewTab: "opens in a new tab",
    backHome: "Back to home",
  },
};

export type Copy = typeof en;
