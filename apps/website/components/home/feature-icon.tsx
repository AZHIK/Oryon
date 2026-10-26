import {
  BoxIcon,
  ChartIcon,
  ChefHatIcon,
  ClockIcon,
  CreditCardIcon,
  FileIcon,
  SparklesIcon,
  UsersIcon,
  WifiOffIcon,
} from "@/components/icons";

const ICONS = {
  offline: WifiOffIcon,
  inventory: BoxIcon,
  team: UsersIcon,
  payments: CreditCardIcon,
  recipes: ChefHatIcon,
  reports: FileIcon,
  dashboard: ChartIcon,
  history: ClockIcon,
  insights: SparklesIcon,
  advanced: ChartIcon,
} as const;

export type FeatureIconName = keyof typeof ICONS;

export function FeatureIcon({
  name,
  className,
}: {
  name: string;
  className?: string;
}) {
  const Icon = ICONS[name as FeatureIconName] ?? BoxIcon;
  return <Icon className={className} />;
}
