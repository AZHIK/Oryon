import Image from "next/image";

import desktopShot from "@/assets/images/product_screenshots/desktop_shot.png";
import { copy } from "@/content";
import { cn } from "@/lib/cn";

export function DesktopWindow({ className }: { className?: string }) {
  return (
    <div className={cn("hero-window", className)}>
      <div className="hero-window-inner">
        <Image
          src={desktopShot}
          alt={copy.hero.desktopAlt}
          width={desktopShot.width}
          height={desktopShot.height}
          sizes="(max-width: 767px) 100vw, (max-width: 1200px) 92vw, 1088px"
          className="h-auto w-full"
        />
      </div>
    </div>
  );
}
