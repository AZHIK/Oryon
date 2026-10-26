"use client";

import { motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";

const APPLE_EASE: [number, number, number, number] = [0.25, 0.1, 0.25, 1];

type RevealProps = {
  children: ReactNode;
  className?: string;
  delay?: number;
  y?: number;
  once?: boolean;
};

/**
 * Apple-style fade-up on scroll. The whole animation is transform + opacity,
 * and it is skipped entirely when the visitor prefers reduced motion.
 */
export function Reveal({
  children,
  className,
  delay = 0,
  y = 24,
  once = true,
}: RevealProps) {
  const reduceMotion = useReducedMotion();

  return (
    <motion.div
      className={className}
      initial={reduceMotion ? false : { opacity: 0, y }}
      whileInView={reduceMotion ? undefined : { opacity: 1, y: 0 }}
      viewport={{ once, margin: "-8% 0px -8% 0px" }}
      transition={{ duration: 0.8, delay, ease: APPLE_EASE }}
    >
      {children}
    </motion.div>
  );
}
