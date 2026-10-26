import type { ReactNode } from "react";

import { cn } from "@/lib/cn";

type Tone = "neutral" | "mint" | "blue" | "orange" | "purple";

export function Badge({
  children,
  tone = "neutral",
  className,
}: {
  children: ReactNode;
  tone?: Tone;
  className?: string;
}) {
  return (
    <span
      className={cn(
        "chip",
        tone !== "neutral" && `chip-${tone}`,
        className,
      )}
    >
      {children}
    </span>
  );
}
