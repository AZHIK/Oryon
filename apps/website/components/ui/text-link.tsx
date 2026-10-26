import Link from "next/link";
import type { ReactNode } from "react";

import { ChevronRightIcon } from "@/components/icons";
import { cn } from "@/lib/cn";

type TextLinkProps = {
  href: string;
  children: ReactNode;
  className?: string;
  quiet?: boolean;
};

export function TextLink({
  href,
  children,
  className,
  quiet = false,
}: TextLinkProps) {
  return (
    <Link
      href={href}
      className={cn("text-link group", quiet && "text-link-quiet", className)}
    >
      {children}
      <ChevronRightIcon className="h-3.5 w-3.5 transition-transform duration-300 group-hover:translate-x-0.5" />
    </Link>
  );
}
