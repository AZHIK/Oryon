import { siteConfig } from "@/site.config";

const brand = siteConfig.name;

import type { Copy } from "./en";

/**
 * ⚠️ DRAFT — machine-assisted Swahili.
 * NEEDS NATIVE-SPEAKER REVIEW before this locale is shown to visitors.
 *
 * Do not enable `sw` in a locale switcher or ship it as final copy until a
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
        `Pakua ${brand} kwa Windows, au tafuta orodha za Google Play na App Store zinapotolewa.`,
    },
    support: {
      title: "Msaada",
      description:
        `Majibu ya maswali ya kawaida kuhusu ${brand}, pamoja na njia za kuwasiliana na timu.`,
    },
    privacy: {
      title: "Sera ya faragha",
      description:
        `Jinsi ${brand} inavyoshughulikia namba za simu, data ya biashara na taarifa zilizohifadhiwa kwenye kifaa chako.`,
    },
    terms: {
      title: "Masharti ya matumizi",
      description:
        `Masharti yanayotumika unapotumia programu na tovuti ya ${brand}.`,
    },
  },
  nav: {
    homeLabel: `Nyumbani ya ${siteConfig.name}`,
    links: [
      { label: "Bidhaa", href: "/#product" },
      { label: "Vipengele", href: "/#features" },
      { label: "Inavyofanya kazi", href: "/#how-it-works" },
      { label: "Timu", href: "/#team" },
      { label: "Msaada", href: "/support" },
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
      `Mauzo, bidhaa, wafanyakazi na ripoti katika programu moja tulivu. Endelea kuhudumia mtandao unapokatika — ${brand} hurejea unapopatikana.`,
    primaryCta: "Pakua kwa Windows",
    primaryCtaSoon: "Chaguo za kupakua",
    secondaryCta: "Tazama inavyofanya kazi",
    primaryNoteReady: "Windows 10 au zaidi · 64-bit",
    primaryNoteSoon:
      "Kifungu cha Windows kinakuja hivi karibuni. Tazama chaguo za kupakua.",
    desktopAlt:
      `Dashibodi ya ${brand} kwenye kompyuta ikionyesha mauzo, oda, wafanyakazi, bidhaa na fedha mahali pamoja.`,
    mobileAlt:
      `Dashibodi ya ${brand} kwenye simu ikiwa na vifungo vya haraka vya mauzo, bidhaa, maarifa na wafanyakazi.`,
    offlineBadge: "Inafanya kazi bila mtandao",
    previewLabel: "Onyesho la bidhaa",
    capabilities: [
      {
        key: "offline",
        title: "Uza bila mtandao",
        description: "Endelea kuhudumia kaunta.",
        tone: "mint",
      },
      {
        key: "inventory",
        title: "Fuatilia bidhaa",
        description: "Mboga na vitu vya menyu.",
        tone: "blue",
      },
      {
        key: "team",
        title: "Majukumu ya wafanyakazi",
        description: "Kifaa kimoja, PIN yako.",
        tone: "purple",
      },
      {
        key: "reports",
        title: "Excel na PDF",
        description: "Ripoti unazoweza kushiriki.",
        tone: "orange",
      },
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
  features: {
    eyebrow: "Nafasi moja tulivu",
    title: "Imeundwa kwa jinsi mgahawa unavyofanya kazi.",
    description:
      "Tabu chache, maelezo machache ya mkono, mshangao mdogo wakati wa kufunga. Mambo muhimu yapo pamoja na yanaendelea kufanya kazi mtandao usipokuwepo.",
    items: [
      {
        key: "offline",
        title: "Mauzo yasiyongoje mtandao",
        description:
          `Pokea oda na uandike malipo bila mtandao. ${brand} huhifadhi mauzo kwenye kifaa na kusawazisha mtandao unaporejea.`,
        tone: "mint",
      },
      {
        key: "recipes",
        title: "Mapishi na uzalishaji",
        description:
          "Pima gharama ya chakula na fuatilia maandalizi kutoka viungo hadi sahani, ili jikoni na kumbukumbu ya bidhaa zisalie sawa.",
        tone: "orange",
      },
      {
        key: "inventory",
        title: "Bidhaa unazoweza kuamini",
        description:
          "Fuatilia mboga na vitu vya menyu unapouza, kupokea na kurekebisha. Ona kinachopungua kabla ya huduma.",
        tone: "blue",
      },
      {
        key: "team",
        title: "Kifaa kimoja, kila jukumu",
        description:
          "Mpe kila mtu jukumu lake na kuingia kwa PIN kwenye kifaa cha pamoja. Ufikiaji hufuata jukumu uliloweka.",
        tone: "purple",
      },
      {
        key: "reports",
        title: "Ripoti tayari kushiriki",
        description:
          "Pitia historia ya mauzo na toa faili safi za Excel au PDF kwa kumbukumbu zako.",
        tone: "orange",
      },
      {
        key: "dashboard",
        title: "Mtazamo tulivu wa leo",
        description:
          "Mauzo, oda, wafanyakazi na bidhaa zipo pamoja kwenye dashibodi moja, hivyo uamuzi unaofuata ni rahisi kuona.",
        tone: "mint",
      },
    ],
    comingSoon: {
      title: "Inakuja",
      description:
        "Tunaongeza uwezo tunapokuwa tumeutayarisha kwa huduma halisi.",
      badge: "Inakuja hivi karibuni",
      items: [
        {
          key: "electronicPayments",
          title: "Malipo ya QR na kadi",
          description:
            "Ruhusu wageni kuchanganua QR au kulipa kwa kadi, kisha linganisha malipo hayo na mauzo ya siku.",
          badge: "",
        },
        {
          key: "aiMode",
          title: "AI mode",
          description:
            "Wakala wa mgahawa anayeshughulikia kazi zinazorudi. Huandaa muhtasari wa siku, hufuatilia bidhaa na hupendekeza hatua inayofuata, ili wewe ubaki kwenye huduma.",
          badge: "Agent",
        },
        {
          key: "advancedReports",
          title: "Ripoti za kina",
          description:
            "Mitazamo ya kina kwa wamiliki wanaotaka kuchimba zaidi.",
          badge: "",
        },
      ],
    },
  },
  howItWorks: {
    eyebrow: "Mauzo, mwanzo hadi mwisho",
    title: "Kutoka mguso wa kwanza hadi ripoti ya siku.",
    description:
      `${brand} hufanya utaratibu kuwa mfupi, mtandao uwe imara au kaunta iwe na shughuli nyingi.`,
    steps: [
      {
        title: "Ongeza oda",
        description:
          "Gusa vitu kwenye menyu. Idadi na bei hubadilika unapoendelea.",
      },
      {
        title: "Pokea malipo",
        description:
          "Andika mauzo kwa TZS na endelea kuhudumia foleni.",
      },
      {
        title: "Toa risiti",
        description:
          "Chapisha au shiriki risiti, kisha anza mauzo mengine.",
      },
      {
        title: "Sawazisha mtandao ukiwepo",
        description:
          "Mauzo na mabadiliko ya bidhaa hupakiwa nyuma mtandao unaporejea.",
      },
    ],
  },
  offline: {
    eyebrow: "Bila mtandao kwanza",
    title: "Mtandao unaweza kukatika. Huduma haipaswi.",
    description:
      `${brand} huhifadhi nakala ya menyu, bidhaa na mauzo kwenye kifaa. Uza, pokea malipo na sasisha bidhaa bila mtandao. Mtandao unaporejea, hurejea yenyewe.`,
    bullets: [
      "Mauzo na risiti hubaki kwenye kifaa.",
      "Mabadiliko ya bidhaa husubiri hadi yaweze kusawazishwa.",
      "Hali wazi huonyesha wafanyakazi kilichohifadhiwa.",
    ],
    card: {
      title: "Kifaa hiki",
      status: "Bila mtandao",
      rows: ["Mauzo yamehifadhiwa", "Bidhaa zimesasishwa", "Risiti iko tayari"],
      footerTitle: "Inasubiri kusawazisha",
      footerCopy: `${brand} itajaribu tena yenyewe mtandao unaporejea.`,
    },
  },
  team: {
    eyebrow: "Timu yako",
    title: "Programu moja, timu yako yote.",
    description:
      "Kila mtu huingia kwenye kifaa cha pamoja kwa PIN yake. Majukumu huweka skrini na vitendo sahihi mikononi pa sahihi — bila kuingia tofauti kwa kila zamu.",
    bullets: [
      "Majukumu na ruhusa za wafanyakazi.",
      "Kuingia kwa PIN kwenye kifaa cha pamoja.",
      "Uhamisho rahisi wakati zamu inabadilika.",
    ],
    card: {
      title: "Wafanyakazi kwenye kifaa hiki",
      chip: "Kuingia kwa PIN",
      rows: [
        { role: "Mmiliki", tone: "violet", meta: "Ufikiaji kamili" },
        { role: "Meneja", tone: "cyan", meta: "Shughuli za kila siku" },
        { role: "Mhudumu", tone: "amber", meta: "Kuuza na risiti" },
        { role: "Jikoni", tone: "magenta", meta: "Bidhaa na jikoni" },
      ],
      footer: "Kila mtu huingia kwa jukumu lake.",
    },
  },
  platforms: {
    eyebrow: "Mahali unapofanya kazi",
    title: `Tumia ${brand} kwenye vifaa ulivyo navyo.`,
    description:
      "Anza na programu ya Windows kwenye kaunta. Programu za simu zinatayarishwa kwa maduka.",
    windows: {
      title: "Windows",
      description: "Programu kamili kwa kompyuta ya kaunta.",
      requirement: "Windows 10 au zaidi, 64-bit",
      cta: "Tazama maelezo ya Windows",
    },
    googlePlay: {
      title: "Google Play",
      description: "Uza, angalia bidhaa na pitia siku yako kwenye simu.",
    },
    appStore: {
      title: "App Store",
      description: "Nafasi hiyo tulivu, imeundwa kwa iPhone.",
    },
    statusAvailable: "Inapatikana",
    statusComingSoon: "Inakuja hivi karibuni",
    note: "Chaguo za kupakua zitaonekana hapa kila toleo linapotolewa.",
    cta: "Tazama chaguo zote za kupakua",
  },
  faq: {
    eyebrow: "Vizuri kujua",
    title: "Maswali ambayo wamiliki wa mikahawa huuliza.",
    description:
      "Majibu mafupi kuhusu kazi bila mtandao, wafanyakazi, ripoti na kuanza.",
    supportCta: "Tembelea msaada",
    items: [
      {
        question: `${brand} inafanya kazi bila mtandao?`,
        answer:
          `Ndiyo. Mauzo, risiti, mabadiliko ya bidhaa na vitendo vya wafanyakazi vinaendelea kwenye kifaa. ${brand} husawazisha mtandao unaporejea.`,
      },
      {
        question: "Nini naweza kutumia bila mtandao?",
        answer:
          "Mauzo, risiti, bidhaa za mboga na menyu, historia ya mauzo, na majukumu ya wafanyakazi kwa kuingia kwa PIN kwenye kifaa cha pamoja.",
      },
      {
        question: "Wafanyakazi wanaweza kushiriki kifaa kimoja?",
        answer:
          "Ndiyo. Kila mtu ana jukumu lake na huingia kwa PIN, hivyo vitendo hubaki kwa mtu sahihi.",
      },
      {
        question: "Naweza kutoa mauzo yangu?",
        answer:
          `Ndiyo. ${brand} hutoa historia ya mauzo kwa Excel na PDF, tayari kushiriki au kuhifadhi.`,
      },
      {
        question: "Ninahitaji nini kuitumia?",
        answer:
          "Programu ya Windows inahitaji Windows 10 au zaidi, 64-bit. Orodha za Google Play na App Store zinakuja hivi karibuni.",
      },
      {
        question: "Data yangu iko salama?",
        answer:
          `Programu huhifadhi hifadhidata yake ya ndani kwa usimbaji fiche kwenye kifaa na kuisawazisha na nafasi yako ya ${brand}. Tovuti hii haitumii vifuatiliaji vya matangazo.`,
      },
    ],
  },
  cta: {
    eyebrow: "Tayari unapoweza",
    title: "Mgahawa tulivu huanza na programu moja.",
    description:
      `Tazama ${brand} inavyoweza kufanya, au nenda moja kwa moja kwenye chaguo za kupakua.`,
    primary: "Tazama chaguo za kupakua",
    secondary: "Wasiliana na msaada",
    noteSoon: "Kifungu cha Windows kinakuja hivi karibuni.",
    noteReady: "Windows 10 au zaidi, 64-bit.",
  },
  footer: {
    blurb:
      "Programu ya mikahawa inayofanya kazi bila mtandao kwa Tanzania. Uza, fuatilia bidhaa, simamia timu na toa ripoti — hata mtandao unapokatika.",
    productHeading: "Bidhaa",
    downloadHeading: "Pakua",
    companyHeading: "Kampuni",
    productLinks: [
      { label: "Vipengele", href: "/#features" },
      { label: "Inavyofanya kazi", href: "/#how-it-works" },
      { label: "Bila mtandao", href: "/#offline" },
      { label: "Timu", href: "/#team" },
      { label: "Vifaa", href: "/#platforms" },
    ],
    downloadLinks: [
      { label: "Chaguo zote za kupakua", href: "/download" },
      { label: "Windows", href: "/download" },
      { label: "Google Play", href: "/download" },
      { label: "App Store", href: "/download" },
    ],
    companyLinks: [
      { label: "Msaada", href: "/support" },
      { label: "Faragha", href: "/privacy" },
      { label: "Masharti", href: "/terms" },
    ],
    contactHeading: "Mawasiliano",
    whatsapp: "WhatsApp",
    email: "Barua pepe",
    contactSoon: "Msaada wa WhatsApp na barua pepe unatayarishwa.",
    copyright: `© ${new Date().getFullYear()} ${siteConfig.name}. Haki zote zimehifadhiwa.`,
    builtFor: "Kwa mikahawa ya Tanzania.",
  },
  downloadPage: {
    eyebrow: "Pakua",
    title: `Peleka ${brand} kwenye kaunta.`,
    description:
      "Kifungu cha Windows kinatayarishwa. Orodha za maduka zitafuata. Hivi ndivyo utakavyohitaji kitakapotolewa.",
    backHome: "Rudi nyumbani",
    statusReady: "Inapatikana sasa",
    statusSoon: "Inakuja hivi karibuni",
    windows: {
      title: `${brand} kwa Windows`,
      description:
        "Programu kamili: mauzo, bidhaa, wafanyakazi, ripoti na dashibodi.",
      download: "Pakua kwa Windows",
      comingSoon: "Kifungu kinakuja hivi karibuni",
      versionLabel: "Toleo",
      sizeLabel: "Ukubwa",
      checksumLabel: "SHA-256",
      minOsLabel: "Inafanya kazi kwenye",
      copy: "Nakili checksum",
      copied: "Imenakiliwa",
      waiting:
        "Toleo, ukubwa na checksum vitaonekana hapa toleo linapotolewa.",
      installTitle: "Jinsi ya kufunga",
      installSteps: [
        "Pakua kifungu na ukifungue.",
        `Fuata maelekezo, kisha fungua ${brand} kutoka menyu ya Start.`,
        "Ingia kwa namba yako ya simu na uanze kuuza.",
      ],
      smartScreenTitle: "Kuhusu Windows SmartScreen",
      smartScreenBody:
        "Kifungu hiki hakina sahihi ya kidijitali bado. Kitakapotolewa, Windows inaweza kuonyesha onyo la SmartScreen. Chagua “More info”, kisha “Run anyway” ikiwa umeipakua kutoka tovuti hii.",
      smartScreenSigned:
        "Kifungu hiki kina sahihi ya kidijitali. Windows inapaswa kutambua mchapishaji.",
      note:
        "Data yako hubaki kwenye kifaa hiki na husawazishwa ukiwa mtandaoni.",
    },
    stores: {
      title: `${brand} kwenye simu yako`,
      description:
        "Orodha za Google Play na App Store zinatayarishwa.",
      googlePlay: "Google Play",
      appStore: "App Store",
      comingSoon: "Inakuja hivi karibuni",
    },
    helpTitle: "Unahitaji msaada?",
    helpDescription:
      "Tembelea msaada kwa majibu ya maswali ya kawaida kuhusu usanidi na kazi bila mtandao.",
    helpCta: "Nenda kwenye msaada",
  },
  supportPage: {
    eyebrow: "Msaada",
    title: "Tunaweza kukusaidiaje?",
    description:
      "Majibu ya maswali ya kawaida, na njia za kuwasiliana na timu zinapopatikana.",
    contactTitle: "Wasiliana nasi",
    contactDescription:
      "Msaada wa WhatsApp na barua pepe unatayarishwa. Utaonekana hapa ukiwa tayari.",
    whatsappTitle: "WhatsApp",
    whatsappDescription: "Njia ya haraka zaidi ya kufikia timu.",
    emailTitle: "Barua pepe",
    emailDescription: "Kwa maswali ya akaunti na usanidi.",
    comingSoon: "Inakuja hivi karibuni",
    openWhatsApp: "Fungua WhatsApp",
    sendEmail: "Tuma barua pepe",
    downloadTitle: "Unatafuta programu?",
    downloadDescription:
      "Tazama chaguo za Windows na simu, pamoja na kilicho tayari leo.",
    downloadCta: "Nenda kwenye vipakuliwa",
  },
  privacyPage: {
    eyebrow: "Kisheria",
    title: "Sera ya faragha",
    lastUpdated: "Imesasishwa 26 Oktoba 2026",
    draft: "Rasimu — inasubiri ukaguzi wa kisheria",
    intro:
      `Sera hii inaeleza ${brand} inakusanya nini, kwa nini, na chaguo ulizonazo. Imeandikwa kwa wamiliki wa mikahawa wanaotumia programu Tanzania.`,
    sections: [
      {
        heading: "Tunachokusanya",
        paragraphs: [
          "Taarifa za akaunti: namba yako ya simu hutumika kuingia kwa msimbo wa mara moja unaotumwa kwa SMS. Ukiongeza barua pepe au wasifu wa biashara, tunahifadhi taarifa hizo pia.",
          "Data ya biashara: mauzo, malipo, bidhaa, wasambazaji, majukumu ya wafanyakazi, maduka na ripoti unazounda kwenye programu. Hii ni taarifa inayofanya nafasi yako ifanye kazi.",
          "Data ya kifaa: programu huhifadhi hifadhidata ya ndani kwenye kifaa ili iendelee kufanya kazi bila mtandao. Hifadhidata husimbwa kwa fiche.",
        ],
      },
      {
        heading: "Jinsi tunavyotumia",
        paragraphs: [
          `Tunatumia taarifa zako kuendesha nafasi yako ya ${brand}, kusawazisha data kati ya vifaa, kutoa msaada, kuweka huduma salama na kuboresha bidhaa.`,
          "Hatuuzi data yako ya biashara. Hatumii vifuatiliaji vya matangazo kwenye tovuti hii.",
        ],
      },
      {
        heading: "Nani anaweza kuiona",
        paragraphs: [
          "Wewe na wafanyakazi unaowaalika mnaweza kuona data inayoruhusiwa na majukumu yao. Watoa huduma wetu huchakata data kwa ajili ya kuendesha huduma tu, kwa mfano kutuma SMS na barua pepe.",
          "Tunaweza kufichua taarifa ikiwa sheria inahitaji au ikiwa ni muhimu kulinda huduma na watumiaji wake.",
        ],
      },
      {
        heading: "Mahali inapohifadhiwa",
        paragraphs: [
          "Data yako ya ndani hubaki kwenye kifaa. Data iliyosawazishwa huhifadhiwa kwenye seva zinazotumika kuendesha huduma. Tunatumia hatua za kiufundi na za mpangilio kulinda taarifa.",
        ],
      },
      {
        heading: "Chaguo zako",
        paragraphs: [
          "Unaweza kupitia na kusasisha taarifa za biashara kwenye programu. Unaweza kutuuliza kuhusu ufikiaji, marekebisho au kufuta data ya akaunti yako kwa kuwasiliana na msaada. Baadhi ya kumbukumbu zinaweza kuhitajika kuhifadhiwa kwa sababu za kisheria au uhasibu.",
        ],
      },
      {
        heading: "Mawasiliano",
        paragraphs: [
          "Maswali kuhusu sera hii yanaweza kutumwa kupitia ukurasa wa msaada. Njia za mawasiliano zinatayarishwa, na rasimu hii itasasishwa zitakapopatikana.",
        ],
      },
    ],
  },
  termsPage: {
    eyebrow: "Kisheria",
    title: "Masharti ya matumizi",
    lastUpdated: "Imesasishwa 26 Oktoba 2026",
    draft: "Rasimu — inasubiri ukaguzi wa kisheria",
    intro:
      `Masharti haya yanatumika unapotumia programu na tovuti ya ${brand}. Kwa kutumia ${brand}, unakubali masharti haya.`,
    sections: [
      {
        heading: "Akaunti yako",
        paragraphs: [
          "Unahitaji namba ya simu kuingia. Weka misimbo yako ya mara moja na PIN za wafanyakazi kwa siri. Unawajibika kwa shughuli kwenye akaunti yako na kwa majukumu unayowapa wafanyakazi.",
        ],
      },
      {
        heading: "Kutumia programu",
        paragraphs: [
          `${brand} ni chombo cha uendeshaji wa mgahawa. Itumie kwa uhalali na kwa biashara tu ulizoruhusiwa kusimamia. Usijaribu kuvuruga huduma, kufikia data ya biashara nyingine, au kufungua msimbo wa programu kwa njia isiyoruhusiwa.`,
        ],
      },
      {
        heading: "Data bila mtandao na usawazishaji",
        paragraphs: [
          "Programu huhifadhi nakala ya data yako kwenye kifaa ili ifanye kazi bila mtandao. Husawazisha mtandao unapopatikana. Ukiondoa programu ya Windows kabla ya data kusawazishwa, hifadhidata ya ndani na ufunguo wake wa usimbaji huondolewa na kumbukumbu zisizosawazishwa zinaweza kupotea.",
        ],
      },
      {
        heading: "Upatikanaji",
        paragraphs: [
          `Tunafanya kazi ili ${brand} ipatikane na iwe sahihi, lakini hatuwezi kuahidi huduma bila kukatika. Matengenezo, muunganisho na watoa huduma wengine wanaweza kuathiri usawazishaji na kuingia.`,
        ],
      },
      {
        heading: "Maudhui yetu",
        paragraphs: [
          `Jina la ${brand}, nembo, programu na maudhui ya tovuti ni mali ya wamiliki wake. Huna ruhusa kunakili au kuwasambaza bila idhini.`,
        ],
      },
      {
        heading: "Mabadiliko",
        paragraphs: [
          "Tunaweza kusasisha masharti haya kadri bidhaa inavyobadilika. Toleo la hivi karibuni litachapishwa hapa. Mabadiliko yakiwa makubwa, tutayaeleza waziwazi kabla hayajaanza kutumika.",
        ],
      },
      {
        heading: "Mawasiliano",
        paragraphs: [
          "Maswali kuhusu masharti haya yanaweza kutumwa kupitia ukurasa wa msaada. Njia za mawasiliano zinatayarishwa, na rasimu hii itasasishwa zitakapopatikana.",
        ],
      },
    ],
  },
  common: {
    comingSoon: "Inakuja hivi karibuni",
    copy: "Nakili",
    copied: "Imenakiliwa",
    learnMore: "Jifunze zaidi",
    opensInNewTab: "hufunguka kwenye kichupo kipya",
    backHome: "Rudi nyumbani",
  },
};
