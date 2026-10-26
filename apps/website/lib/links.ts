import { siteConfig, type StoreKey } from "@/site.config";

export function whatsappHref(message?: string): string | null {
  const digits = siteConfig.contact.whatsapp.replace(/\D/g, "");
  if (!digits) return null;

  const text =
    message ?? `Hello ${siteConfig.name}, I’d like to learn more about the app.`;
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`;
}

export function mailtoHref(subject?: string): string | null {
  const email = siteConfig.contact.email.trim();
  if (!email) return null;

  const query = subject ? `?subject=${encodeURIComponent(subject)}` : "";
  return `mailto:${email}${query}`;
}

export function storeHref(store: StoreKey): string | null {
  const url = siteConfig.stores[store].trim();
  return url || null;
}
