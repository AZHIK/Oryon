import { FEATURES_STATUS, type FeatureStatus } from "@/site.config";

/** Narrows the `as const` feature flags before comparing them to a status. */
function isShipped(status: FeatureStatus): boolean {
  return status === "shipped";
}

function isComingSoon(status: FeatureStatus): boolean {
  return status === "coming-soon";
}

/**
 * Maps the marketing feature keys to the flags the owner controls. A feature
 * is only shown or described when every capability it promises is shipped.
 */
export function isMainFeatureShipped(key: string): boolean {
  switch (key) {
    case "offline":
      return isShipped(FEATURES_STATUS.offlineSales);
    case "inventory":
      return isShipped(FEATURES_STATUS.offlineInventory);
    case "team":
      return (
        isShipped(FEATURES_STATUS.staffRoles) &&
        isShipped(FEATURES_STATUS.sharedDevicePinLogin)
      );
    case "payments":
      return isShipped(FEATURES_STATUS.electronicPayments);
    case "recipes":
      return isShipped(FEATURES_STATUS.recipesAndProduction);
    case "reports":
      return (
        isShipped(FEATURES_STATUS.excelExport) &&
        isShipped(FEATURES_STATUS.pdfExport)
      );
    case "dashboard":
      return isShipped(FEATURES_STATUS.dashboard);
    default:
      return true;
  }
}

export function isFeatureComingSoon(key: string): boolean {
  return isComingSoon(FEATURES_STATUS[key as keyof typeof FEATURES_STATUS]);
}
