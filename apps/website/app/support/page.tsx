import type { Metadata } from "next";
import Link from "next/link";

import {
  ChevronRightIcon,
  DownloadIcon,
  MailIcon,
  WhatsAppIcon,
} from "@/components/icons";
import { Badge } from "@/components/ui/badge";
import { Faq } from "@/components/ui/faq";
import { SectionHeading } from "@/components/ui/section-heading";
import { copy } from "@/content";
import { mailtoHref, whatsappHref } from "@/lib/links";
import { buildMetadata } from "@/lib/metadata";

export const metadata: Metadata = buildMetadata({
  title: copy.meta.support.title,
  description: copy.meta.support.description,
  path: "/support/",
});

export default function SupportPage() {
  const whatsapp = whatsappHref();
  const email = mailtoHref();

  return (
    <div className="bg-app">
      <section className="pt-[calc(4.5rem+clamp(2.5rem,5vw,4rem))] pb-[clamp(3rem,6vw,5rem)]">
        <div className="container-page">
          <div className="max-w-3xl">
            <p className="eyebrow">{copy.supportPage.eyebrow}</p>
            <h1 className="type-h2 mt-3">{copy.supportPage.title}</h1>
            <p className="type-lede mt-4">{copy.supportPage.description}</p>
          </div>

          <h2 className="type-h3 mt-8">{copy.supportPage.contactTitle}</h2>

          <div className="mt-4 grid gap-4 md:grid-cols-2">
            {whatsapp ? (
              <a
                href={whatsapp}
                target="_blank"
                rel="noopener noreferrer"
                className="card card-hover p-6"
              >
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone="mint"
                  aria-hidden="true"
                >
                  <WhatsAppIcon className="h-5 w-5" />
                </span>
                <h3 className="type-h3 mt-4">
                  {copy.supportPage.whatsappTitle}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {copy.supportPage.whatsappDescription}
                </p>
                <div className="mt-4">
                  <span className="text-link">
                    {copy.supportPage.openWhatsApp}
                    <ChevronRightIcon className="h-3.5 w-3.5" />
                  </span>
                </div>
              </a>
            ) : (
              <div className="card p-6">
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone="mint"
                  aria-hidden="true"
                >
                  <WhatsAppIcon className="h-5 w-5" />
                </span>
                <h3 className="type-h3 mt-4">
                  {copy.supportPage.whatsappTitle}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {copy.supportPage.whatsappDescription}
                </p>
                <div className="mt-4">
                  <Badge tone="orange">{copy.supportPage.comingSoon}</Badge>
                </div>
              </div>
            )}

            {email ? (
              <a href={email} className="card card-hover p-6">
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone="blue"
                  aria-hidden="true"
                >
                  <MailIcon className="h-5 w-5" />
                </span>
                <h3 className="type-h3 mt-4">
                  {copy.supportPage.emailTitle}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {copy.supportPage.emailDescription}
                </p>
                <div className="mt-4">
                  <span className="text-link">
                    {copy.supportPage.sendEmail}
                    <ChevronRightIcon className="h-3.5 w-3.5" />
                  </span>
                </div>
              </a>
            ) : (
              <div className="card p-6">
                <span
                  className="icon-tile icon-tile-lg"
                  data-tone="blue"
                  aria-hidden="true"
                >
                  <MailIcon className="h-5 w-5" />
                </span>
                <h3 className="type-h3 mt-4">
                  {copy.supportPage.emailTitle}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {copy.supportPage.emailDescription}
                </p>
                <div className="mt-4">
                  <Badge tone="orange">{copy.supportPage.comingSoon}</Badge>
                </div>
              </div>
            )}
          </div>

          <p className="mt-5 max-w-2xl text-sm leading-relaxed text-muted">
            {copy.supportPage.contactDescription}
          </p>
        </div>
      </section>

      <section className="section border-t border-line bg-surface">
        <div className="container-page">
          <div className="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
            <SectionHeading
              eyebrow={copy.faq.eyebrow}
              title={copy.faq.title}
              description={copy.faq.description}
              titleId="support-faq-title"
            />
            <Faq items={copy.faq.items} />
          </div>
        </div>
      </section>

      <section className="section-tight bg-app">
        <div className="container-page">
          <div className="card flex flex-col items-start justify-between gap-5 p-6 sm:flex-row sm:items-center">
            <div>
              <h2 className="type-h3">{copy.supportPage.downloadTitle}</h2>
              <p className="mt-1 text-sm text-muted">
                {copy.supportPage.downloadDescription}
              </p>
            </div>
            <Link href="/download" className="btn btn-primary shrink-0">
              <DownloadIcon className="h-4 w-4" />
              {copy.supportPage.downloadCta}
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
