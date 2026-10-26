import Link from "next/link";

import { LogoMark } from "@/components/brand/logo";
import { MailIcon, WhatsAppIcon } from "@/components/icons";
import { copy } from "@/content";
import { mailtoHref, whatsappHref } from "@/lib/links";
import { siteConfig, siteUrl } from "@/site.config";

type FooterLink = {
  label: string;
  href: string;
};

function FooterColumn({
  heading,
  links,
}: {
  heading: string;
  links: readonly FooterLink[];
}) {
  return (
    <div>
      <h2 className="footer-heading">{heading}</h2>
      <ul className="mt-3 space-y-1.5">
        {links.map((link) => (
          <li key={`${heading}-${link.href}-${link.label}`}>
            <Link href={link.href} className="footer-link">
              {link.label}
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function SiteFooter() {
  const whatsapp = whatsappHref();
  const email = mailtoHref();

  return (
    <footer className="site-footer">
      <div className="container-page py-12 sm:py-14">
        <div className="grid gap-10 md:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1fr_1fr]">
          <div>
            <Link
              href="/"
              aria-label={copy.nav.homeLabel}
              className="inline-flex items-center gap-2.5"
            >
              <LogoMark className="h-9 w-9 text-fill" />
              <span className="text-[1.0625rem] font-semibold tracking-[-0.025em]">
                {siteConfig.name}
              </span>
            </Link>
            <p className="mt-4 max-w-sm text-sm leading-relaxed text-muted">
              {copy.footer.blurb}
            </p>

            <h2 className="footer-heading mt-6">
              {copy.footer.contactHeading}
            </h2>
            <div className="mt-3 space-y-2">
              {whatsapp ? (
                <a
                  href={whatsapp}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="footer-link inline-flex items-center gap-2"
                >
                  <WhatsAppIcon className="h-4 w-4 text-accent" />
                  {copy.footer.whatsapp}
                </a>
              ) : null}
              {email ? (
                <a
                  href={email}
                  className="footer-link inline-flex items-center gap-2"
                >
                  <MailIcon className="h-4 w-4 text-accent" />
                  {copy.footer.email}
                </a>
              ) : null}
              {!whatsapp && !email ? (
                <p className="max-w-xs text-xs leading-relaxed text-muted">
                  {copy.footer.contactSoon}
                </p>
              ) : null}
            </div>
          </div>

          <FooterColumn
            heading={copy.footer.productHeading}
            links={copy.footer.productLinks}
          />
          <FooterColumn
            heading={copy.footer.downloadHeading}
            links={copy.footer.downloadLinks}
          />
          <FooterColumn
            heading={copy.footer.companyHeading}
            links={copy.footer.companyLinks}
          />
        </div>

        <div className="mt-10 flex flex-col gap-2 border-t border-line pt-5 text-xs text-muted sm:flex-row sm:items-center sm:justify-between">
          <p>{copy.footer.copyright}</p>
          <p>
            {copy.footer.builtFor}{" "}
            <a href={siteUrl} className="text-accent hover:underline">
              {siteConfig.domain}
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}
