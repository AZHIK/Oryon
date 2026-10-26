import Image from "next/image";

import mobileShot from "@/assets/images/product_screenshots/mobile_shot.png";
import { copy } from "@/content";
import { cn } from "@/lib/cn";

export function PhonePreview({ className }: { className?: string }) {
  return (
    <div className={cn("phone-frame", className)}>
      <div className="phone-screen">
        <Image
          src={mobileShot}
          alt={copy.hero.mobileAlt}
          width={mobileShot.width}
          height={mobileShot.height}
          sizes="288px"
          className="h-auto w-full"
        />
      </div>
    </div>
  );
}
