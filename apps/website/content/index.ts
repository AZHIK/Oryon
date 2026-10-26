import { en, type Copy } from "./en";
import { SW_REVIEW_STATUS, sw } from "./sw";

/**
 * All copy lives in this module. English ships today; Swahili is typed against
 * the English shape and is deliberately marked as a draft.
 */
export const copyByLocale = { en, sw } as const;

export type Locale = keyof typeof copyByLocale;

export const defaultLocale: Locale = "en";

/** The copy used by the site today. Change this once Swahili is reviewed. */
export const copy: Copy = copyByLocale[defaultLocale];

export { en, sw, SW_REVIEW_STATUS };
export type { Copy };
