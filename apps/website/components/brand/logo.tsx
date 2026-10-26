import { cn } from "@/lib/cn";

type LogoMarkProps = {
  className?: string;
};

/**
 * Oryon's mark: the same teal tile and fork/knife used in the app sidebar.
 * Decorative — always pair it with an accessible name at the call site.
 */
export function LogoMark({ className }: LogoMarkProps) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      aria-hidden="true"
      focusable="false"
      className={cn("text-teal", className)}
    >
      <rect width="32" height="32" rx="9.5" fill="currentColor" />
      <g
        stroke="#FFFFFF"
        strokeWidth="1.65"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M9.7 6.2v5.2" />
        <path d="M12 6.2v5.2" />
        <path d="M14.3 6.2v5.2" />
        <path d="M9.7 11.4h4.6" />
        <path d="M12 11.4v14.4" />
        <path d="M22.3 6.2c-1.3 2.2-2 4.4-2 6.4 0 1.7.9 2.8 2 2.8s2-1.1 2-2.8c0-2-.7-4.2-2-6.4Z" />
        <path d="M22.3 15.4v10.4" />
      </g>
      <circle cx="26.2" cy="6" r="1.1" fill="#A0F0D8" />
    </svg>
  );
}
