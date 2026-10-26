"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";

import { LogoMark } from "@/components/brand/logo";
import {
  ArrowDownIcon,
  CloseIcon,
  MenuIcon,
} from "@/components/icons";
import { en as copy } from "@/content/en";
import { siteConfig } from "@/site.config";

const APPLE_EASE: [number, number, number, number] = [0.25, 0.1, 0.25, 1];

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

  return (
    <header className="site-header" data-scrolled={scrolled}>
      <div className="container-page">
        <div className="flex h-16 items-center justify-between gap-5">
          <Link
            href="/"
            aria-label={copy.nav.homeLabel}
            className="flex items-center gap-2.5 rounded-lg"
            onClick={() => setOpen(false)}
          >
            <LogoMark className="h-8 w-8" />
            <span className="text-[1.0625rem] font-semibold tracking-[-0.025em] text-ink">
              {siteConfig.name}
            </span>
          </Link>

          <nav
            aria-label={copy.nav.primaryLabel}
            className="hidden items-center gap-0.5 lg:flex"
          >
            {copy.nav.links.map((link) => (
              <Link key={link.href} href={link.href} className="nav-link">
                {link.label}
              </Link>
            ))}
          </nav>

          <div className="hidden items-center gap-2.5 lg:flex">
            <Link
              href="/download"
              className="btn btn-primary btn-sm"
              aria-label={copy.nav.download}
            >
              {copy.nav.download}
              <ArrowDownIcon className="h-3.5 w-3.5" />
            </Link>
          </div>

          <button
            ref={triggerRef}
            type="button"
            onClick={() => setOpen((value) => !value)}
            aria-expanded={open}
            aria-controls={open ? "mobile-menu" : undefined}
            aria-label={open ? copy.nav.closeMenu : copy.nav.openMenu}
            className="inline-flex h-11 w-11 items-center justify-center rounded-full border border-line bg-surface/70 text-ink transition-colors hover:bg-surface-muted lg:hidden"
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
            initial={reduceMotion ? false : { opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduceMotion ? undefined : { opacity: 0, y: -10 }}
            transition={{ duration: 0.28, ease: APPLE_EASE }}
          >
            <div className="container-page py-6">
              <nav aria-label={copy.nav.mobilePrimaryLabel}>
                <ul className="flex flex-col">
                  {copy.nav.links.map((link) => (
                    <li key={link.href}>
                      <Link
                        href={link.href}
                        onClick={() => setOpen(false)}
                        className="flex items-center justify-between border-b border-line py-4 text-[1.35rem] font-semibold tracking-[-0.02em] text-ink"
                      >
                        {link.label}
                        <ArrowDownIcon className="h-4 w-4 -rotate-90 text-ink-muted" />
                      </Link>
                    </li>
                  ))}
                </ul>
              </nav>

              <Link
                href="/download"
                onClick={() => setOpen(false)}
                className="btn btn-primary mt-6 w-full"
              >
                {copy.nav.download}
                <ArrowDownIcon className="h-4 w-4" />
              </Link>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  );
}
