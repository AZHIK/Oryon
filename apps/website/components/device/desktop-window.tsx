import { LogoMark } from "@/components/brand/logo";
import {
  WindowCloseIcon,
  WindowMaximiseIcon,
  WindowMinimiseIcon,
} from "@/components/icons";
import { copy } from "@/content";
import { cn } from "@/lib/cn";
import { siteConfig } from "@/site.config";

const TONE_CLASS: Record<string, string> = {
  terracotta: "tone-terracotta",
  sage: "tone-sage",
  gold: "tone-gold",
};

const SIDEBAR_ITEMS = [
  "bg-terracotta",
  "bg-[#1f1a15]/15",
  "bg-[#1f1a15]/15",
  "bg-[#1f1a15]/15",
];

export function DesktopWindow() {
  const desktop = copy.preview.desktop;

  return (
    <div className="device-desktop select-none" aria-hidden="true">
      <div className="device-desktop-inner">
        <div className="device-titlebar">
          <div className="flex min-w-0 items-center gap-1.5">
            <LogoMark className="h-3.5 w-3.5 shrink-0" />
            <span className="device-titlebar-title hidden font-medium text-white/85 md:inline">
              {siteConfig.name}
            </span>
            <span
              aria-hidden="true"
              className="hidden h-2.5 w-px shrink-0 bg-white/20 md:block"
            />
            <span className="device-titlebar-title hidden text-white/55 md:inline">
              {desktop.windowTitle}
            </span>
          </div>

          <div className="flex shrink-0 items-center gap-2.5">
            <WindowMinimiseIcon className="device-window-control" />
            <WindowMaximiseIcon className="device-window-control" />
            <WindowCloseIcon className="device-window-control" />
          </div>
        </div>

        <div className="device-body">
          <div className="hidden h-full w-full md:flex">
            <div className="hidden w-[8.5%] shrink-0 flex-col items-center gap-2 border-r border-black/5 bg-[#f6f0e8] pt-3 sm:flex">
            {SIDEBAR_ITEMS.map((color, index) => (
              <span
                key={index}
                className={cn(
                  "h-3.5 w-3.5 rounded-[4px] sm:h-4 sm:w-4",
                  color,
                )}
              />
            ))}
          </div>

          <div className="min-w-0 flex-1 bg-white p-2 sm:p-3">
            <div className="flex items-center justify-between gap-2">
              <p className="text-[clamp(0.5rem,0.9vw,0.72rem)] font-semibold tracking-[-0.02em] text-[#1f1a15]">
                {desktop.windowTitle}
              </p>
              <div className="hidden items-center gap-1 rounded-full border border-black/10 bg-[#faf7f3] px-2 py-1 sm:flex">
                <span className="h-1.5 w-1.5 rounded-full border border-[#6b5f55]/50" />
                <span className="text-[clamp(0.32rem,0.5vw,0.46rem)] text-[#6b5f55]">
                  {desktop.search}
                </span>
              </div>
            </div>

            <div className="mt-2 flex flex-wrap gap-1">
              {desktop.categories.map((category, index) => (
                <span
                  key={category}
                  className={cn(
                    "rounded-full px-1.5 py-0.5 text-[clamp(0.32rem,0.52vw,0.46rem)] font-medium",
                    index === 0
                      ? "bg-terracotta-deep text-white"
                      : "bg-[#f4eee6] text-[#6b5f55]",
                  )}
                >
                  {category}
                </span>
              ))}
            </div>

            <div className="mt-2 grid grid-cols-2 gap-1.5 sm:grid-cols-3">
              {desktop.items.map((item) => (
                <div
                  key={item.name}
                  className="rounded-lg border border-black/5 bg-white p-1.5 shadow-[0_1px_2px_rgba(31,26,21,0.05)]"
                >
                  <div
                    className={cn(
                      "mb-1 aspect-[4/3] rounded-md",
                      TONE_CLASS[item.tone] ?? "tone-terracotta",
                    )}
                  />
                  <p className="truncate text-[clamp(0.34rem,0.58vw,0.5rem)] font-semibold leading-tight text-[#1f1a15]">
                    {item.name}
                  </p>
                  <p className="truncate text-[clamp(0.3rem,0.5vw,0.44rem)] leading-tight text-[#6b5f55]">
                    {item.price}
                  </p>
                </div>
              ))}
            </div>
          </div>

          <div className="hidden w-[31%] shrink-0 flex-col border-l border-black/5 bg-[#fbf7f2] md:flex">
            <div className="flex items-start justify-between gap-2 border-b border-black/5 px-2.5 py-2">
              <div>
                <p className="text-[clamp(0.42rem,0.68vw,0.62rem)] font-semibold leading-tight text-[#1f1a15]">
                  {desktop.ticketTitle}
                </p>
                <p className="text-[clamp(0.32rem,0.5vw,0.46rem)] text-[#6b5f55]">
                  {desktop.ticketSubtitle}
                </p>
              </div>
              <span className="rounded-full bg-[#efe4d7] px-1.5 py-0.5 text-[clamp(0.28rem,0.42vw,0.4rem)] font-medium text-[#6b5f55]">
                {desktop.ticketLines.length}
              </span>
            </div>

            <div className="flex-1 space-y-1.5 px-2.5 py-2">
              {desktop.ticketLines.map((line) => (
                <div
                  key={line.name}
                  className="flex items-baseline justify-between gap-2"
                >
                  <span className="truncate text-[clamp(0.34rem,0.58vw,0.5rem)] text-[#1f1a15]">
                    {line.name}
                    <span className="ml-1 text-[#6b5f55]">× {line.qty}</span>
                  </span>
                  <span className="text-[clamp(0.34rem,0.58vw,0.5rem)] font-medium text-[#1f1a15]">
                    {line.price}
                  </span>
                </div>
              ))}
            </div>

            <div className="border-t border-black/10 px-2.5 py-2">
              <div className="flex items-baseline justify-between gap-2">
                <span className="text-[clamp(0.32rem,0.52vw,0.46rem)] text-[#6b5f55]">
                  {desktop.totalLabel}
                </span>
                <span className="text-[clamp(0.44rem,0.72vw,0.66rem)] font-semibold tracking-[-0.02em] text-[#1f1a15]">
                  {desktop.total}
                </span>
              </div>
              <div className="brand-gradient mt-2 rounded-full py-1.5 text-center text-[clamp(0.34rem,0.56vw,0.5rem)] font-semibold text-white">
                {desktop.charge}
              </div>
            </div>
          </div>
          </div>

          <div className="brand-gradient flex h-full w-full items-center justify-center p-4 md:hidden">
            <div className="w-[72%] max-w-[14rem] rounded-2xl border border-white/25 bg-white/10 p-3">
              <div className="flex items-center gap-2">
                <LogoMark className="h-5 w-5" />
                <div className="h-1.5 w-16 rounded-full bg-white/60" />
              </div>
              <div className="mt-3 grid grid-cols-3 gap-1.5">
                {Array.from({ length: 6 }).map((_, index) => (
                  <div
                    key={index}
                    className="aspect-[4/3] rounded-md bg-white/15"
                  />
                ))}
              </div>
              <div className="mt-3 h-1.5 w-2/3 rounded-full bg-white/30" />
              <div className="mt-1.5 h-1.5 w-1/2 rounded-full bg-white/20" />
              <div className="mt-3 h-6 rounded-full bg-white/85" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
