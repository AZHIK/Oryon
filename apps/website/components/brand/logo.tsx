import { cn } from "@/lib/cn";

type LogoMarkProps = {
  className?: string;
};

/**
 * The product mark: a warm terracotta tile holding an "O" with one gold grain.
 * Decorative — always pair it with an accessible name at the call site.
 */
export function LogoMark({ className }: LogoMarkProps) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      aria-hidden="true"
      focusable="false"
      className={cn("text-terracotta", className)}
    >
      <rect width="32" height="32" rx="9.5" fill="currentColor" />
      <path
        d="M16 6.4a9.6 9.6 0 1 0 0 19.2 9.6 9.6 0 0 0 0-19.2Zm0 3.15a6.45 6.45 0 1 1 0 12.9 6.45 6.45 0 0 1 0-12.9Z"
        fill="#FBF7F2"
      />
      <circle cx="23.7" cy="8.4" r="1.55" fill="#C99A2E" />
    </svg>
  );
}
