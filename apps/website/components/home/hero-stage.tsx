import { DesktopWindow } from "@/components/device/desktop-window";
import { PhonePreview } from "@/components/device/phone-preview";
import { copy } from "@/content";

/**
 * Product showcase. The real desktop screenshot leads on larger screens and
 * the real mobile screenshot leads on phones, so neither is stretched to fit
 * the other's aspect ratio.
 */
export function HeroStage() {
  return (
    <div className="hero-showcase">
      <div className="hidden md:block">
        <DesktopWindow />
      </div>
      <div className="md:hidden">
        <PhonePreview />
      </div>
      <div className="hero-float hidden md:flex">
        <span className="hero-float-dot" aria-hidden="true" />
        {copy.hero.offlineBadge}
      </div>
    </div>
  );
}
