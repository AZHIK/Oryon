import { LogoMark } from "@/components/brand/logo";
import { copy } from "@/content";
import { cn } from "@/lib/cn";

const BARS = [42, 64, 50, 78, 58, 72, 96];

export function PhonePreview() {
  const phone = copy.preview.phone;

  return (
    <div className="device-phone select-none" aria-hidden="true">
      <div className="device-phone-screen">
        <div className="device-phone-island" />

        <div className="hidden h-full flex-col md:flex">
          <div className="flex items-center justify-between px-2.5 pt-1.5 text-[clamp(0.3rem,0.5vw,0.42rem)] font-semibold text-[#1f1a15]">
            <span>{phone.statusTime}</span>
            <span className="flex items-end gap-[2px]">
              <span className="h-1 w-[2px] rounded-sm bg-[#1f1a15]/70" />
              <span className="h-1.5 w-[2px] rounded-sm bg-[#1f1a15]/70" />
              <span className="h-2 w-[2px] rounded-sm bg-[#1f1a15]/70" />
              <span className="ml-1 h-2 w-3 rounded-[2px] border border-[#1f1a15]/50" />
            </span>
          </div>

          <div className="px-2.5 pt-3">
            <p className="text-[clamp(0.3rem,0.5vw,0.42rem)] font-medium uppercase tracking-[0.14em] text-[#6b5f55]">
              {phone.title}
            </p>
            <p className="mt-0.5 text-[clamp(0.65rem,1.25vw,1rem)] font-semibold leading-none tracking-[-0.03em] text-[#1f1a15]">
              {phone.total}
            </p>
            <p className="mt-1 text-[clamp(0.3rem,0.52vw,0.44rem)] font-medium text-[#4c6b4f]">
              {phone.sales}
            </p>
          </div>

          <div className="brand-gradient mx-2.5 mt-2.5 rounded-[clamp(0.5rem,1vw,0.8rem)] p-2 text-white">
            <p className="text-[clamp(0.28rem,0.46vw,0.4rem)] font-medium text-white">
              {phone.chartLabel}
            </p>
            <div className="mt-1.5 flex h-[clamp(1.4rem,2.8vw,2.2rem)] items-end gap-[2px]">
              {BARS.map((height, index) => (
                <span
                  key={index}
                  className={cn(
                    "flex-1 rounded-t-[2px]",
                    index === BARS.length - 1 ? "bg-white" : "bg-white/55",
                  )}
                  style={{ height: `${height}%` }}
                />
              ))}
            </div>
          </div>

          <div className="mt-2.5 flex-1 px-2.5">
            <p className="text-[clamp(0.28rem,0.46vw,0.4rem)] font-semibold uppercase tracking-[0.12em] text-[#6b5f55]">
              {phone.recentLabel}
            </p>
            <div className="mt-1 space-y-1.5">
              {phone.rows.map((row) => (
                <div
                  key={`${row.name}-${row.meta}`}
                  className="flex items-center justify-between gap-1 border-b border-black/5 pb-1.5"
                >
                  <div className="min-w-0">
                    <p className="truncate text-[clamp(0.3rem,0.52vw,0.44rem)] font-semibold leading-tight text-[#1f1a15]">
                      {row.name}
                    </p>
                    <p className="truncate text-[clamp(0.26rem,0.42vw,0.36rem)] leading-tight text-[#6b5f55]">
                      {row.meta}
                    </p>
                  </div>
                  <p className="shrink-0 text-[clamp(0.28rem,0.48vw,0.42rem)] font-medium text-[#1f1a15]">
                    {row.price}
                  </p>
                </div>
              ))}
            </div>
          </div>

          <div className="flex items-center justify-around border-t border-black/10 px-2 py-1.5">
            {phone.tabs.map((tab, index) => (
              <span
                key={tab}
                className={cn(
                  "text-[clamp(0.26rem,0.44vw,0.38rem)] font-medium",
                  index === 0 ? "text-terracotta-deep" : "text-[#6b5f55]",
                )}
              >
                {tab}
              </span>
            ))}
          </div>
        </div>

        <div className="flex h-full flex-col md:hidden">
          <div className="brand-gradient mx-2 mt-2 flex flex-1 items-center justify-center rounded-[1rem]">
            <LogoMark className="h-7 w-7" />
          </div>
          <div className="space-y-1.5 px-3 py-3">
            <div className="h-1.5 w-2/3 rounded-full bg-[#1f1a15]/15" />
            <div className="h-1.5 w-1/2 rounded-full bg-[#1f1a15]/10" />
            <div className="mt-2 h-7 rounded-lg bg-[#1f1a15]/5" />
            <div className="h-7 rounded-lg bg-[#1f1a15]/5" />
          </div>
          <div className="mx-2 mb-2 h-6 rounded-full bg-terracotta-deep" />
        </div>
      </div>
    </div>
  );
}
