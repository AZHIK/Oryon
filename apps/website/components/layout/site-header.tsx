"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";

import { LogoMark } from "@/components/brand/logo";
import {
  ChevronRightIcon,
  CloseIcon,
  DownloadIcon,
  MenuIcon,
} from "@/components/icons";
import { en as copy } from "@/content/en";
import { cn } from "@/lib/cn";
import { siteConfig } from "@/site.config";

const EASE: [number, number, number, number] = [0.25, 0.1, 0.25, 1];

function isRouteActive(pathname: string, href: string): boolean {
  if (href.includes("#")) return false;
  return href === "/" ? pathname === "/" : pathname.startsWith(href);
}

export function SiteHeader() {
  const pathname = usePathname();
  const reduceMotion = useReducedMotion();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 6);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!open) return;

    const panel = panelRef.current;
    const trigger = triggerRef.current;
    const links = panel
      ? Array.from(
          panel.querySelectorAll<HTMLElement>("a[href], button:not([disabled])"),
        )
      : [];
    const focusables = [trigger, ...links].filter(
      (element): element is HTMLElement => Boolean(element),
    );

    links[0]?.focus();

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        setOpen(false);
        trigger?.focus();
        return;
      }

      if (event.key !== "Tab" || focusables.length === 0) return;

      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      const active = document.activeElement;

      if (event.shiftKey && active === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && active === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  useEffect(() => {
    const query = window.matchMedia("(min-width: 1024px)");
    const onChange = () => {
      if (query.matches) setOpen(false);
    };
    query.addEventListener("change", onChange);
    return () => query.removeEventListener("change", onChange);
  }, []);

  const downloadActive = pathname.startsWith("/download");

  return (
    <header className="site-header" data-scrolled={scrolled}>
      <div className="container-page">
        <div className="flex h-[4.5rem] items-center justify-between gap-5">
          <Link
            href="/"
            aria-label={copy.nav.homeLabel}
            className="flex items-center gap-2.5 rounded-lg"
            onClick={() => setOpen(false)}
          >
            <LogoMark className="h-9 w-9 text-fill" />
            <span className="text-[1.0625rem] font-semibold tracking-[-0.025em] text-ink">
              {siteConfig.name}
            </span>
          </Link>

          <nav
            aria-label={copy.nav.primaryLabel}
            className="hidden items-center gap-0.5 lg:flex"
          >
            {copy.nav.links.map((link) => {
              const active = isRouteActive(pathname, link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  aria-current={active ? "page" : undefined}
                  className={cn("nav-link", active && "nav-link-active")}
                >
                  {link.label}
                </Link>
              );
            })}
          </nav>

          <div className="hidden items-center gap-2.5 lg:flex">
            <Link
              href="/download"
              aria-current={downloadActive ? "page" : undefined}
              className="btn btn-primary btn-sm"
            >
              <DownloadIcon className="h-4 w-4" />
              {copy.nav.download}
            </Link>
          </div>

          <button
            ref={triggerRef}
            type="button"
            onClick={() => setOpen((value) => !value)}
            aria-expanded={open}
            aria-controls={open ? "mobile-menu" : undefined}
            aria-label={open ? copy.nav.closeMenu : copy.nav.openMenu}
            className="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-line bg-surface text-ink transition-colors hover:bg-mint-surface lg:hidden"
          >
            {open ? (
              <CloseIcon className="h-5 w-5" />
            ) : (
              <MenuIcon className="h-5 w-5" />
            )}
          </button>
        </div>
      </div>

      <AnimatePresence>
        {open && (
          <motion.div
            id="mobile-menu"
            ref={panelRef}
            className="mobile-menu lg:hidden"
            initial={reduceMotion ? false : { opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduceMotion ? undefined : { opacity: 0, y: -8 }}
            transition={{ duration: 0.2, ease: EASE }}
          >
            <div className="container-page py-5">
              <nav aria-label={copy.nav.mobilePrimaryLabel}>
                <ul className="flex flex-col">
                  {copy.nav.links.map((link) => {
                    const active = isRouteActive(pathname, link.href);
                    return (
                      <li key={link.href}>
                        <Link
                          href={link.href}
                          onClick={() => setOpen(false)}
                          aria-current={active ? "page" : undefined}
                          className={cn(
                            "flex items-center justify-between border-b border-line py-4 text-[1.15rem] font-semibold tracking-[-0.02em]",
                            active ? "text-accent" : "text-ink",
                          )}
                        >
                          {link.label}
                          <ChevronRightIcon className="h-4 w-4 text-muted" />
                        </Link>
                      </li>
                    );
                  })}
                </ul>
              </nav>

              <Link
                href="/download"
                onClick={() => setOpen(false)}
                className="btn btn-primary mt-6 w-full"
              >
                <DownloadIcon className="h-4 w-4" />
                {copy.nav.download}
              </Link>
              <p className="mt-3 text-center text-xs text-muted">
                {copy.hero.primaryNoteSoon}
              </p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
