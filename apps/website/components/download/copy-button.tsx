"use client";

import { useState } from "react";

import { CheckIcon, CopyIcon } from "@/components/icons";
import { en as copy } from "@/content/en";

export function CopyButton({
  value,
  label,
  copiedLabel,
}: {
  value: string;
  label?: string;
  copiedLabel?: string;
}) {
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  }

  return (
    <button
      type="button"
      onClick={handleCopy}
      className="btn btn-secondary btn-sm shrink-0"
      aria-live="polite"
    >
      {copied ? (
        <CheckIcon className="h-3.5 w-3.5" />
      ) : (
        <CopyIcon className="h-3.5 w-3.5" />
      )}
      {copied ? (copiedLabel ?? copy.common.copied) : (label ?? copy.common.copy)}
    </button>
  );
}
