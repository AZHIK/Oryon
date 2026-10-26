import { FEATURES_STATUS } from "@/site.config";

/**
 * Maps the marketing feature keys to the flags the owner controls. A feature
 * is only shown or described when every capability it promises is shipped.
 */
export function isMainFeatureShipped(key: string): boolean {
  switch (key) {
    case "offline":
      return FEATURES_STATUS.offlineSales === "shipped";
    case "inventory":
      return FEATURES_STATUS.offlineInventory === "shipped";
    case "team":
      return (
        FEATURES_STATUS.staffRoles === "shipped" &&
        FEATURES_STATUS.sharedDevicePinLogin === "shipped"
      );
    case "payments":
      return FEATURES_STATUS.electronicPayments === "shipped";
    case "recipes":
      return FEATURES_STATUS.recipesAndProduction === "shipped";
    case "reports":
      return (
        FEATURES_STATUS.excelExport === "shipped" &&
        FEATURES_STATUS.pdfExport === "shipped"
      );
    case "dashboard":
      return FEATURES_STATUS.dashboard === "shipped";
    default:
      return true;
  }
}

export function isFeatureComingSoon(key: string): boolean {
  return (
    FEATURES_STATUS[key as keyof typeof FEATURES_STATUS] === "coming-soon"
  );
}
