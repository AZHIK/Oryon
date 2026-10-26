"use client";

import {
  motion,
  useReducedMotion,
  useScroll,
  useTransform,
} from "motion/react";
import { useRef, type ReactNode } from "react";

import { en as copy } from "@/content/en";

type HeroStageProps = {
  desktop: ReactNode;
  phone: ReactNode;
};

/**
 * Layered device composition. Only transform and opacity are animated, and the
 * scroll-linked movement is disabled when the visitor prefers reduced motion.
 */
export function HeroStage({ desktop, phone }: HeroStageProps) {
  const ref = useRef<HTMLDivElement>(null);
  const reduceMotion = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start center", "end start"],
  });

  const scale = useTransform(scrollYProgress, [0, 0.7], [1, 0.94]);
  const desktopY = useTransform(scrollYProgress, [0, 1], [0, 62]);
  const phoneY = useTransform(scrollYProgress, [0, 1], [18, -42]);
  const phoneRotate = useTransform(scrollYProgress, [0, 1], [-2.4, 1.2]);

  return (
    <div
      ref={ref}
      id="preview"
      className="relative mx-auto mt-14 w-full max-w-[62rem] scroll-mt-28 pb-20 sm:mt-20 sm:pb-24"
    >
      <div aria-hidden="true" className="hero-stage-glow" />

      <div
        className="hero-stage-in"
        style={{ animationDelay: "0.2s" }}
        role="img"
        aria-label={copy.hero.previewAlt}
      >
        <motion.div
          style={reduceMotion ? undefined : { scale }}
          className="relative"
        >
          <motion.div
            style={reduceMotion ? undefined : { y: desktopY }}
            className="relative z-10 mx-auto w-[93%] sm:w-full"
          >
            {desktop}
          </motion.div>

          <motion.div
            style={
              reduceMotion
                ? undefined
                : { y: phoneY, rotate: phoneRotate }
            }
            className="absolute -bottom-3 right-[1.5%] z-20 w-[30%] max-w-[13.75rem] origin-bottom sm:-bottom-9 sm:right-[-1%] sm:w-[24%] lg:w-[22.5%]"
          >
            {phone}
          </motion.div>

          <div className="hero-float bottom-7 left-4 hidden sm:flex">
            <span className="hero-float-dot" aria-hidden="true" />
            {copy.hero.offlineBadge}
          </div>
        </motion.div>
      </div>
    </div>
  );
}
