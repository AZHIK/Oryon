/// Shared user-visible copy, in one place.
///
/// Screen-specific prose stays with its screen — hoisting every sentence
/// here would trade locality for a phonebook. What lives here is copy
/// repeated across screens: common actions, permission-gating states, save
/// failures, and placeholders. One wording fix lands everywhere at once,
/// and a future localization pass starts from this file.
library;

import 'app_limits.dart';
import '../l10n/l10n.dart';

abstract final class AppStrings {
  // -------------------------------------------------------------------------
  // Common actions
  // -------------------------------------------------------------------------

  static String get save => L10n.t('save', 'Save');
  static String get cancel => L10n.t('cancel', 'Cancel');
  static String get delete => L10n.t('delete', 'Delete');
  static String get retry => L10n.t('retry', 'Retry');
  static String get refresh => L10n.t('refresh', 'Refresh');
  static String get sessionExpiredTitle =>
      L10n.t('sessionExpiredTitle', 'Session expired');
  static String get sessionExpiredBody => L10n.t(
    'sessionExpiredBody',
    'You have been signed out. Please enter your phone number to sign in again.',
  );
  static String get sessionExpiredOk => L10n.t('sessionExpiredOk', 'OK');
  static String get close => L10n.t('close', 'Close');
  static String get clear => L10n.t('clear', 'Clear');
  static String get add => L10n.t('add', 'Add');
  static String get edit => L10n.t('edit', 'Edit');
  static String get done => L10n.t('done', 'Done');
  static String get exportPdf => L10n.t('exportPdf', 'Export PDF');
  static String get exportExcel => L10n.t('exportExcel', 'Export Excel');

  // -------------------------------------------------------------------------
  // Permission gating
  // -------------------------------------------------------------------------

  static String accessDeniedFor(String feature) => '$feature Access Denied';
  static String get offlineMode => L10n.t('offlineMode', 'Offline Mode');
  static String get offlineSubtitle => L10n.t(
    'offlineSubtitle',
    'Permission check unavailable. Some features may be disabled.',
  );
  static String get noPermission => L10n.t('noPermission', 'No permission');
  static String get accessDenied => L10n.t('accessDenied', 'Access Denied');
  static String get permissionDeniedHint => L10n.t(
    'permissionDeniedHint',
    'You do not have permission to access this screen.',
  );
  static String get offlinePermissionsHint => L10n.t(
    'offlinePermissionsHint',
    'Permission check unavailable while offline.\n'
        'This feature may be disabled in offline mode.',
  );
  static String get lackingPermission =>
      L10n.t('lackingPermission', 'You lack permission for this action');
  static String get lackingScreenPermission => L10n.t(
    'lackingScreenPermission',
    'You lack permission to access this screen',
  );
  static String get offlinePermissionsTooltip => L10n.t(
    'offlinePermissionsTooltip',
    'Offline mode: permissions unavailable',
  );
  static String get offlineCheckUnavailable => L10n.t(
    'offlineCheckUnavailable',
    'Offline: permission check unavailable',
  );
  static String get permissionCheckFailed =>
      L10n.t('permissionCheckFailed', 'Permission check failed');
  static String get errorTitle => L10n.t('errorTitle', 'Error');

  // -------------------------------------------------------------------------
  // Save failures
  // -------------------------------------------------------------------------

  static String saveFailed(Object error) => 'Could not save: $error';
  static String get apiRequestFailed =>
      L10n.t('apiRequestFailed', 'API request failed');

  // -------------------------------------------------------------------------
  // Placeholders
  // -------------------------------------------------------------------------

  static String get unknown => L10n.t('unknown', 'Unknown');
  static String get unknownItem => L10n.t('unknownItem', 'Unknown item');

  // -------------------------------------------------------------------------
  // Photos
  // -------------------------------------------------------------------------

  static String get uploadImage => L10n.t('uploadImage', 'Upload image');
  static String get imageHint => L10n.t(
    'imageHint',
    'PNG or JPG · up to ${AppLimits.imageMaxBytes ~/ (1024 * 1024)} MB',
  );
  static String get removeImage => L10n.t('removeImage', 'Remove image');
  static String get couldNotOpenImagePicker =>
      L10n.t('couldNotOpenImagePicker', 'Could not open the image picker');

  // -------------------------------------------------------------------------
  // Navigation destinations
  // -------------------------------------------------------------------------

  static String get navDashboard => L10n.t('navDashboard', 'Dashboard');
  static String get navPos => L10n.t('navPos', 'POS');
  static String get navSales => L10n.t('navSales', 'Sales');
  static String get navCustomers => L10n.t('navCustomers', 'Customers');
  static String get navProduction => L10n.t('navProduction', 'Production');
  static String get navSuppliers => L10n.t('navSuppliers', 'Suppliers');
  static String get navCouriers => L10n.t('navCouriers', 'Couriers');
  static String get navFinance => L10n.t('navFinance', 'Finance');
  static String get navReports => L10n.t('navReports', 'Reports');
  static String get navInsights => L10n.t('navInsights', 'Insights');
  static String get navInventory => L10n.t('navInventory', 'Inventory');
  static String get navStaff => L10n.t('navStaff', 'Staff');
  static String get navSettings => L10n.t('navSettings', 'Settings');
  static String get navGroupSell => L10n.t('navGroupSell', 'Sell');
  static String get navGroupStock => L10n.t('navGroupStock', 'Stock');
  static String get navGroupManage => L10n.t('navGroupManage', 'Manage');
  static String get navGroupAnalytics =>
      L10n.t('navGroupAnalytics', 'Reporting');
  static String get navMore => L10n.t('navMore', 'More');
  static String get navMoreDestinations =>
      L10n.t('navMoreDestinations', 'More destinations');
  static String get navGoTo => L10n.t('navGoTo', 'Go to');
  static String get themeFollowSystem =>
      L10n.t('themeFollowSystem', 'Theme: follow system');
  static String get followSystem => L10n.t('followSystem', 'Follow system');
  static String get lightTheme => L10n.t('lightTheme', 'Light theme');
  static String get darkTheme => L10n.t('darkTheme', 'Dark theme');

  // -------------------------------------------------------------------------
  // Top bar
  // -------------------------------------------------------------------------

  static String get chatWithAssistant =>
      L10n.t('chatWithAssistant', 'Chat with Assistant');
  static String get help => L10n.t('help', 'Help');
  static String get helpComingSoon =>
      L10n.t('helpComingSoon', 'Help center coming soon');
  static String get accountAndOptions =>
      L10n.t('accountAndOptions', 'Account & options');
  static String get endShift => L10n.t('endShift', 'End shift');
  static String get endShiftSubtitle => L10n.t(
    'endShiftSubtitle',
    'Lock this terminal — sign back in with your PIN',
  );
  static String get logout => L10n.t('logout', 'Logout');
  static String get logoutSubtitle =>
      L10n.t('logoutSubtitle', 'Sign out everywhere on this terminal');
  static String get notifications => L10n.t('notifications', 'Notifications');
  static String get filterLabel => L10n.t('filterLabel', 'Filter');
  static String get sortTooltip => L10n.t('sortTooltip', 'Sort');
  static String sortAscending(String option) => '$option — ascending';
  static String sortDescending(String option) => '$option — descending';
  static String get sortFallback => L10n.t('sortFallback', 'Sort');
  static String get filtersTitle => L10n.t('filtersTitle', 'Filters');
  static String get noResults => L10n.t('noResults', 'No results');
  static String showingRange(int first, int last, int total) =>
      'Showing $first–$last of $total';
  static String get previousPage => L10n.t('previousPage', 'Previous page');
  static String get nextPage => L10n.t('nextPage', 'Next page');
  static String pagerPosition(int page, int count) => '$page / $count';
  static String get tryDifferentSearch => L10n.t(
    'tryDifferentSearch',
    'Try a different search or clear your filters.',
  );
  static String get rangeMin => L10n.t('rangeMin', 'Min');
  static String get rangeMax => L10n.t('rangeMax', 'Max');
  static String get rangeSeparator => L10n.t('rangeSeparator', '–');
  static String get rowActions => L10n.t('rowActions', 'Row actions');
  static String get copyPath => L10n.t('copyPath', 'Copy path');

  // -------------------------------------------------------------------------
  // Chat assistant & cash tender
  // -------------------------------------------------------------------------

  static String get assistantTitle =>
      L10n.t('assistantTitle', 'Restaurant Assistant');
  static String get savedTick => L10n.t('savedTick', 'Saved');
  static String get frontOfHouse => L10n.t('frontOfHouse', 'Front of house');
  static String get noRole => L10n.t('noRole', 'No role');
  static String get startConversation =>
      L10n.t('startConversation', 'Start a conversation');
  static String get askAboutOrders => L10n.t(
    'askAboutOrders',
    'Ask me about orders, inventory, sales, and more',
  );
  static String get typeMessage =>
      L10n.t('typeMessage', 'Type your message...');
  static String get amountTendered =>
      L10n.t('amountTendered', 'Amount tendered');
  static String get exactChip => L10n.t('exactChip', 'Exact');
  static String quickChip(String amount) => '+$amount';
  static String get stillOwing => L10n.t('stillOwing', 'Still owing');
  static String get changeDue => L10n.t('changeDue', 'Change due');
  static String get subtotalLabel => L10n.t('subtotalLabel', 'Subtotal');
  static String discountLabel(String percent) => 'Discount ($percent)';
  static String discountValue(String amount) => '−$amount';
  static String taxLabel(String percent) => 'Tax ($percent)';
  static String get totalLabel => L10n.t('totalLabel', 'Total');
  static String get methodLabel => L10n.t('methodLabel', 'Method');
  static String get tenderedLabel => L10n.t('tenderedLabel', 'Tendered');

  // -------------------------------------------------------------------------
  // POS: customer picker
  // -------------------------------------------------------------------------

  static String get walkInAttachCustomer =>
      L10n.t('walkInAttachCustomer', 'Walk-in — attach a customer');
  static String get unknownInitial => L10n.t('unknownInitial', '?');
  static String get change => L10n.t('change', 'Change');
  static String get removeCustomer =>
      L10n.t('removeCustomer', 'Remove customer');
  static String get attachCustomer =>
      L10n.t('attachCustomer', 'Attach a customer');
  static String get searchNameOrPhone =>
      L10n.t('searchNameOrPhone', 'Search name or phone');
  static String get noCustomerWalkIn =>
      L10n.t('noCustomerWalkIn', 'No customer (walk-in)');
  static String get noMatchingCustomers =>
      L10n.t('noMatchingCustomers', 'No matching customers');
  static String get addNewCustomer =>
      L10n.t('addNewCustomer', 'Add new customer');

  // -------------------------------------------------------------------------
  // POS: menu, cart, charge
  // -------------------------------------------------------------------------

  static String get soldOutBadge => L10n.t('soldOutBadge', "86'd");
  static String quantityBadge(int? quantity) => '$quantity';
  static String get cartNoItems => L10n.t('cartNoItems', 'No items');
  static String cartItemCount(int count) =>
      '$count ${count == 1 ? 'item' : 'items'}';
  static String get cartView => L10n.t('cartView', 'View');
  static String get decrease => L10n.t('decrease', 'Decrease');
  static String get remove => L10n.t('remove', 'Remove');
  static String get increase => L10n.t('increase', 'Increase');
  static String stepperQuantity(int quantity) => '$quantity';
  static String get takePayment => L10n.t('takePayment', 'Take payment');
  static String get chargeCustomer => L10n.t('chargeCustomer', 'Customer');
  static String get chargePaymentMethod =>
      L10n.t('chargePaymentMethod', 'Payment method');
  static String orderCharged(
    String id,
    String total,
    String method,
    String changePart,
    String receiptPart,
  ) => '$id charged — $total by $method$changePart$receiptPart';
  static String chargeChangePart(String change) => ' · $change change';
  static String chargeReceiptPart(String receipt) =>
      ' · receipt $receipt printing';
  static String chargeCouponPart(String coupon) => ' · coupon $coupon printing';
  static String get printAfterCharge =>
      L10n.t('printAfterCharge', 'Print after charge');
  static String get printAfterChargeHelper => L10n.t(
    'printAfterChargeHelper',
    'Choose what prints once this sale is charged',
  );
  static String get chargeReceiptOption =>
      L10n.t('chargeReceiptOption', 'Receipt');
  static String get chargeReceiptOptionHelper =>
      L10n.t('chargeReceiptOptionHelper', 'Itemised receipt for the customer');
  static String get chargeCouponOption =>
      L10n.t('chargeCouponOption', 'Coupon');
  static String get chargeCouponOptionHelper =>
      L10n.t('chargeCouponOptionHelper', 'Short claim coupon for the order');
  static String get defaultPrintModeField =>
      L10n.t('defaultPrintModeField', 'Default print after charge');
  static String get defaultPrintModeHelper => L10n.t(
    'defaultPrintModeHelper',
    'Pre-selected in the take-payment dialog',
  );
  static String get receiptPreviewTitle =>
      L10n.t('receiptPreviewTitle', 'Receipt preview');
  static String get receiptPreviewSubtitle =>
      L10n.t('receiptPreviewSubtitle', '80mm thermal paper');
  static String get previewReceiptAction =>
      L10n.t('previewReceiptAction', 'Preview receipt');
  static String get previewReceiptBlurb =>
      L10n.t('previewReceiptBlurb', 'See the 80mm format with sample data');
  static String get couponPreviewTitle =>
      L10n.t('couponPreviewTitle', 'Coupon preview');
  static String couponSent(String id) => 'Coupon for $id sent to printer';
  static String get previewCouponAction =>
      L10n.t('previewCouponAction', 'Preview coupon');
  static String get previewCouponBlurb =>
      L10n.t('previewCouponBlurb', 'See the claim coupon with sample data');
  static String get printCoupon => L10n.t('printCoupon', 'Print coupon');
  static String get receiptPrintAction => L10n.t('receiptPrintAction', 'Print');
  static String get receiptScanHint =>
      L10n.t('receiptScanHint', 'Scan to verify receipt');
  static String get receiptWelcomeNote =>
      L10n.t('receiptWelcomeNote', 'Thank you, welcome again!');
  static String get cashReceived => L10n.t('cashReceived', 'Cash received');
  static String get chargeAmountDue => L10n.t('chargeAmountDue', 'Amount due');
  static String get cashTendered => L10n.t('cashTendered', 'Cash tendered');
  static String get chargeChange => L10n.t('chargeChange', 'Change');
  static String chargeTotal(String total) => 'Charge $total';
  static String terminalNotice(String method) =>
      'Complete the ${method.toLowerCase()} payment on the terminal, '
      'then charge to record it.';
  static String cartLineQuantity(int quantity) => '× $quantity';
  static String cartLineEach(String price) => '$price each';
  static String get searchMenu => L10n.t('searchMenu', 'Search menu');
  static String get searchMenuItems =>
      L10n.t('searchMenuItems', 'Search menu items, categories…');
  static String get clearSearch => L10n.t('clearSearch', 'Clear');
  static String get scanBarcode => L10n.t('scanBarcode', 'Scan barcode');
  static String get scannerNotConnected =>
      L10n.t('scannerNotConnected', 'Scanner not connected');
  static String get cashierRole => L10n.t('cashierRole', 'Cashier');
  static String get takingPayment => L10n.t('takingPayment', 'Taking payment');
  static String get currentOrder => L10n.t('currentOrder', 'Current order');
  static String get clearOrder => L10n.t('clearOrder', 'Clear order');
  static String get assignTable => L10n.t('assignTable', 'Assign table');
  static String get counterNoTable =>
      L10n.t('counterNoTable', 'Counter (no table)');
  static String tableNumber(int i) => 'Table $i';
  static String get counter => L10n.t('counter', 'Counter');
  static String tableLabel(Object table) => 'Table $table';
  static String get noItemsYet => L10n.t('noItemsYet', 'No items yet');
  static String get tapMenuToStart =>
      L10n.t('tapMenuToStart', 'Tap a menu item to start this order.');
  static String get charge => L10n.t('charge', 'Charge');
  static String get confirm => L10n.t('confirm', 'Confirm');
  static String get confirmPayment =>
      L10n.t('confirmPayment', 'Confirm payment');
  static String get applyDiscount => L10n.t('applyDiscount', 'Apply discount');
  static String get noDiscount => L10n.t('noDiscount', 'No discount');
  static String orderTypeTable(String orderType, Object? table) =>
      table == null ? orderType : '$orderType · $table';

  // -------------------------------------------------------------------------
  // POS screen
  // -------------------------------------------------------------------------

  static String get noMenuHere =>
      L10n.t('noMenuHere', 'Nothing on the menu here');
  static String get noMatches => L10n.t('noMatches', 'No matches');
  static String get noItemsInCategory =>
      L10n.t('noItemsInCategory', 'This category has no items yet.');
  static String nothingMatches(String query) =>
      'Nothing matches “$query” in this category.';
  static String get clearFilters => L10n.t('clearFilters', 'Clear filters');
  static String ticketTable(String table) => 'Table $table';

  // -------------------------------------------------------------------------
  // Auth: profile / PIN / OTP
  // -------------------------------------------------------------------------

  static String saveDetailsFailed(Object e) =>
      'Could not save your details: $e';
  static String get tellUsWhoYouAre =>
      L10n.t('tellUsWhoYouAre', 'Tell us who you are');
  static String get profileSubtitle => L10n.t(
    'profileSubtitle',
    'This appears on receipts, invites and the staff list',
  );
  static String get fullName => L10n.t('fullName', 'Full name');
  static String get nameExample => L10n.t('nameExample', 'Amina Hassan');
  static String get emailLabel => L10n.t('emailLabel', 'Email');
  static String get emailHelper => L10n.t(
    'emailHelper',
    'Optional — used for receipts and account recovery',
  );
  static String get emailExample => L10n.t('emailExample', 'amina@venue.com');
  static String get invalidEmail =>
      L10n.t('invalidEmail', 'Enter a valid email address');
  static String get continueAction => L10n.t('continueAction', 'Continue');
  static String sendCodeFailed(Object e) => 'Failed to send code: $e';
  static String get enterPhoneNumber =>
      L10n.t('enterPhoneNumber', 'Enter your phone number');
  static String get codeNotRight =>
      L10n.t('codeNotRight', 'That code is not right. Check your messages.');
  static String get enterYourCode => L10n.t('enterYourCode', 'Enter your code');
  static String get signIn => L10n.t('signIn', 'Sign in');
  static String codeSentTo(String phone) => 'We sent a 6-digit code to $phone';
  static String get useRegisteredPhone => L10n.t(
    'useRegisteredPhone',
    'Use the phone number your manager registered',
  );
  static String get backToProfiles =>
      L10n.t('backToProfiles', 'Back to profiles');
  static String get phoneNumber => L10n.t('phoneNumber', 'Phone number');
  static String get phoneExample =>
      L10n.t('phoneExample', '6XXXXXXXX or 7XXXXXXXX');
  static String get dialCode => L10n.t('dialCode', '+255');
  static String get sendCode => L10n.t('sendCode', 'Send code');
  static String get verifying => L10n.t('verifying', 'Verifying');
  static String resendIn(int seconds) => 'Resend code in ${seconds}s';
  static String get resendCode => L10n.t('resendCode', 'Resend code');
  static String get changeNumber => L10n.t('changeNumber', 'Change number');
  static String get codeHint =>
      L10n.t('codeHint', 'We texted you a 6-digit code');
  static String get pointOfSale => L10n.t('pointOfSale', 'Point of sale');
  static String get preparingTerminal =>
      L10n.t('preparingTerminal', 'Preparing your terminal');
  static String get whoIsWorking => L10n.t('whoIsWorking', "Who's working?");
  static String get noSignInsYet =>
      L10n.t('noSignInsYet', 'No one has signed in on this terminal yet');
  static String get chooseProfile =>
      L10n.t('chooseProfile', 'Choose your profile to unlock the till');
  static String get signInDifferently =>
      L10n.t('signInDifferently', 'Not your device? Sign in differently');
  static String get notSignedInYet =>
      L10n.t('notSignedInYet', 'Not signed in yet');
  static String get addAccount => L10n.t('addAccount', 'Add account');
  static String get addAccountSubtitle =>
      L10n.t('addAccountSubtitle', 'Sign in with a phone number');
  static String get pinsDidNotMatch =>
      L10n.t('pinsDidNotMatch', 'Those PINs did not match. Start again.');
  static String pinSaveFailed(Object e) => 'Failed to save PIN: $e';
  static String get chooseNewPin => L10n.t('chooseNewPin', 'Choose a new PIN');
  static String get confirmYourPin =>
      L10n.t('confirmYourPin', 'Confirm your PIN');
  static String get createYourPin => L10n.t('createYourPin', 'Create your PIN');
  static String get enterSamePin =>
      L10n.t('enterSamePin', 'Enter the same six digits again');
  static String get pinUnlockHint =>
      L10n.t('pinUnlockHint', "You'll use this to unlock the POS quickly");
  static String get pinSaved => L10n.t('pinSaved', 'PIN saved');
  static String get signInWithOtp =>
      L10n.t('signInWithOtp', 'Sign in with OTP instead');
  static String get switchProfile => L10n.t('switchProfile', 'Switch profile');
  static String enterPin(int length) => 'Enter your $length-digit PIN';
  static String get incorrectPinLast =>
      L10n.t('incorrectPinLast', 'Incorrect PIN — last attempt');
  static String incorrectPinLeft(int left) =>
      'Incorrect PIN, try again ($left attempts left)';
  static String get tooManyAttempts =>
      L10n.t('tooManyAttempts', 'Too many attempts');
  static String get tillLockedMoment => L10n.t(
    'tillLockedMoment',
    'For everyone\'s safety the till is locked for a moment.',
  );
  static String get secondRemaining =>
      L10n.t('secondRemaining', 'second remaining');
  static String get secondsRemaining =>
      L10n.t('secondsRemaining', 'seconds remaining');
  static String countdownSeconds(int seconds) => '$seconds';

  // -------------------------------------------------------------------------
  // Auth: marketing aside / steps / keypad
  // -------------------------------------------------------------------------

  static String get asideOrderFast =>
      L10n.t('asideOrderFast', 'Take an order in three taps');
  static String get asideSplitBill =>
      L10n.t('asideSplitBill', 'Split a bill without the maths');
  static String get asideCashUp =>
      L10n.t('asideCashUp', 'Cash up in under a minute');
  static String get asideHeadline =>
      L10n.t('asideHeadline', 'The till your\nfloor staff\nactually like.');
  static String get asideSupporting => L10n.t(
    'asideSupporting',
    'Orders, payments and takings in one place — on the counter, '
        'on a tablet, or behind the bar.',
  );
  static String stepOf(int step, int count) => '$step of $count';
  static String stepNumber(int index) => '${index + 1}';
  static String copyrightNotice(int year, String store) => '© $year $store';
  static String get deleteKey => L10n.t('deleteKey', 'Delete');

  // -------------------------------------------------------------------------
  // Onboarding
  // -------------------------------------------------------------------------

  static String get obYourBusiness => L10n.t('obYourBusiness', 'Your business');
  static String get obYourBusinessBlurb =>
      L10n.t('obYourBusinessBlurb', 'Name, type and logo');
  static String get obWhereYouTrade =>
      L10n.t('obWhereYouTrade', 'Where you trade');
  static String get obWhereYouTradeBlurb =>
      L10n.t('obWhereYouTradeBlurb', 'Address and contact');
  static String get obHowYouCharge =>
      L10n.t('obHowYouCharge', 'How you charge');
  static String get obHowYouChargeBlurb =>
      L10n.t('obHowYouChargeBlurb', 'Currency, tax and orders');
  static String get obYourTeam => L10n.t('obYourTeam', 'Your team');
  static String get obYourTeamBlurb =>
      L10n.t('obYourTeamBlurb', 'Invite the people who work here');
  static String get obDuplicateBusiness => L10n.t(
    'obDuplicateBusiness',
    'You already have a business registered to this account.',
  );
  static String get obSetupFailed => L10n.t(
    'obSetupFailed',
    'Something went wrong finishing setup — please try again.',
  );
  static String obPartialInvite(String failed) =>
      'Set up, but couldn\'t invite $failed — try again from Staff.';
  static String get obTellUsTitle =>
      L10n.t('obTellUsTitle', 'Tell us about your business');
  static String get obWhereTitle =>
      L10n.t('obWhereTitle', 'Where do you trade?');
  static String get obPrefsTitle => L10n.t('obPrefsTitle', 'A few preferences');
  static String get obTeamTitle =>
      L10n.t('obTeamTitle', 'Who else works here?');
  static String get obTellUsSubtitle =>
      L10n.t('obTellUsSubtitle', 'This appears on receipts and across the app');
  static String get obWhereSubtitle =>
      L10n.t('obWhereSubtitle', 'You can add more locations later');
  static String get obPrefsSubtitle =>
      L10n.t('obPrefsSubtitle', 'All of these can be changed in Settings');
  static String get obTeamSubtitle => L10n.t(
    'obTeamSubtitle',
    'They will get an invite to set up their own PIN',
  );
  static String get back => L10n.t('back', 'Back');
  static String get finishSetup => L10n.t('finishSetup', 'Finish setup');
  static String get sendOneInvite =>
      L10n.t('sendOneInvite', 'Send 1 invite & finish');
  static String sendInvites(int count) => 'Send $count invites & finish';
  static String get addLogo => L10n.t('addLogo', 'Add logo');
  static String get businessName => L10n.t('businessName', 'Business name');
  static String get businessNameExample =>
      L10n.t('businessNameExample', 'The Copper Fig');
  static String get businessType => L10n.t('businessType', 'Business type');
  static String get cuisineType => L10n.t('cuisineType', 'Cuisine type');
  static String get cuisineHelper => L10n.t(
    'cuisineHelper',
    'Optional — shown to customers browsing the menu',
  );
  static String get cuisineExample =>
      L10n.t('cuisineExample', 'Italian, Swahili, Grill…');
  static String get licenseDoc =>
      L10n.t('licenseDoc', 'License / registration document');
  static String get licenseDocHelper => L10n.t(
    'licenseDocHelper',
    'Optional — paste a link to where it\'s hosted',
  );
  static String get urlExample => L10n.t('urlExample', 'https://…');
  static String get locationName => L10n.t('locationName', 'Location name');
  static String get locationNameHelper =>
      L10n.t('locationNameHelper', 'What staff call this site');
  static String get locationExample => L10n.t('locationExample', 'Riverside');
  static String get addressLabel => L10n.t('addressLabel', 'Address');
  static String get addressExample =>
      L10n.t('addressExample', '84 Riverside Walk, San Francisco');
  static String get phoneLabel => L10n.t('phoneLabel', 'Phone');
  static String get currencyLabel => L10n.t('currencyLabel', 'Currency');
  static String get currencyHelper =>
      L10n.t('currencyHelper', 'Formats every amount in the app');
  static String currencyOption(String description, String label) =>
      '$description ($label)';
  static String get taxRate => L10n.t('taxRate', 'Tax rate');
  static String get taxHelper =>
      L10n.t('taxHelper', 'Applied to every ticket. Prices will read as ');
  static String taxPreview(String sample) => '$taxHelper$sample';
  static String get taxExample => L10n.t('taxExample', '8.25');
  static String get percentSuffix => L10n.t('percentSuffix', '%');
  static String get taxRangeError =>
      L10n.t('taxRangeError', 'Enter a rate between 0 and 100');
  static String get taxId => L10n.t('taxId', 'Tax ID');
  static String get taxIdHelper => L10n.t(
    'taxIdHelper',
    'Optional — VAT/GST registration number, printed on receipts',
  );
  static String get taxIdExample => L10n.t('taxIdExample', 'TIN-123456789');
  static String get regNumber =>
      L10n.t('regNumber', 'Business registration / license number');
  static String get optional => L10n.t('optional', 'Optional');
  static String get regNumberExample =>
      L10n.t('regNumberExample', 'BRN-000000');
  static String get defaultOrderType =>
      L10n.t('defaultOrderType', 'Default order type');
  static String get addAnother => L10n.t('addAnother', 'Add another');
  static String teammate(int index) => 'Teammate ${index + 1}';
  static String get removeTeammate => L10n.t('removeTeammate', 'Remove');
  static String get teammateName => L10n.t('teammateName', 'Name');
  static String get teammateNameExample =>
      L10n.t('teammateNameExample', 'Marco Rossi');
  static String get teammateEmailExample =>
      L10n.t('teammateEmailExample', 'marco@venue.com');
  static String get inviteSentToNumber =>
      L10n.t('inviteSentToNumber', 'Their invite is sent to this number');
  static String get roleLabel => L10n.t('roleLabel', 'Role');
  static String get roleHelper =>
      L10n.t('roleHelper', 'Sets what they can reach on the till');
  static String get noRushInvites => L10n.t(
    'noRushInvites',
    'No rush — you can invite people from Staff later.',
  );

  // -------------------------------------------------------------------------
  // Inventory: stock dialogs (shared)
  // -------------------------------------------------------------------------

  static String get quantityLabel => L10n.t('quantityLabel', 'Quantity');
  static String get quantityHint => L10n.t('quantityHint', '0');
  static String get notesLabel => L10n.t('notesLabel', 'Notes');
  static String get notesHint =>
      L10n.t('notesHint', 'Anything worth recording');
  static String stockOnHand(String sku, String quantity, String unit) =>
      '$sku · $quantity $unit in stock';

  // -------------------------------------------------------------------------
  // Inventory: production history
  // -------------------------------------------------------------------------

  static String get productionTitle => L10n.t('productionTitle', 'Production');
  static String get filterByDate => L10n.t('filterByDate', 'Filter by date');
  static String get recordAction => L10n.t('recordAction', 'Record');
  static String get runsMetric => L10n.t('runsMetric', 'Runs');
  static String get recordedProductions =>
      L10n.t('recordedProductions', 'Recorded productions');
  static String get adjustedMetric => L10n.t('adjustedMetric', 'Adjusted');
  static String get portionsDiffered =>
      L10n.t('portionsDiffered', 'Portions differed');
  static String get runsCount => L10n.t('runsCount', 'Runs');
  static String runsWithCount(int count) => 'Runs ($count)';
  static String get noRunsYet => L10n.t('noRunsYet', 'No production runs yet');
  static String get recordFromMenuItem => L10n.t(
    'recordFromMenuItem',
    'Record one from a menu item to see it here',
  );
  static String get whatMaking => L10n.t('whatMaking', 'What are you making?');
  static String get noRecipesYet => L10n.t(
    'noRecipesYet',
    'No recipes yet — define one for a menu item first, then come back '
        'to record the run.',
  );
  static String recipeSubtitle(int count, String name) =>
      '$count ingredients · makes $name';
  static String get adjustedBadge => L10n.t('adjustedBadge', 'Adjusted');
  static String tileDetail(
    String leadingQuantity,
    String unit,
    String name,
    String recorded,
    String sellable,
  ) => '$leadingQuantity $unit $name→ $recorded × $sellable';
  static String tileDate(String date, bool adjusted, String suggested) =>
      '$date${adjusted ? ' · suggested $suggested' : ''}';
  static String recordedAt(String date) => 'Recorded $date';
  static String get ellipsis => L10n.t('ellipsis', '…');
  static String dateChip(String from, String to) => '$from – $to';
  static String outputValue(String recorded, String sellable) =>
      '$recorded × $sellable';
  static String get outputLabel => L10n.t('outputLabel', 'Output');
  static String suggestedWas(String quantity) => 'Suggested was $quantity';
  static String portionDiff(String quantity, bool over) =>
      '$quantity ${over ? 'over' : 'under'}';
  static String get consumedSection => L10n.t('consumedSection', 'Consumed');
  static String get closeAction => L10n.t('closeAction', 'Close');

  // -------------------------------------------------------------------------
  // Shared labels used by the inventory and purchasing screens
  // -------------------------------------------------------------------------

  static String get receivedMetric => L10n.t('receivedMetric', 'Received');
  static String get stockAdded => L10n.t('stockAdded', 'Stock added');
  static String get totalValueMetric =>
      L10n.t('totalValueMetric', 'Total value');
  static String get receiveAction => L10n.t('receiveAction', 'Receive');
  static String get unknownSupplier =>
      L10n.t('unknownSupplier', 'Unknown supplier');
  static String get totalColumn => L10n.t('totalColumn', 'Total');
  static String notesLine(String notes) => 'Notes: $notes';

  // -------------------------------------------------------------------------
  // Purchases (online-only): multi-line POs, GRNs, returns, payables
  // -------------------------------------------------------------------------

  static String get purchasesTitle => L10n.t('purchasesTitle', 'Purchases');
  static String get navPurchases => L10n.t('navPurchases', 'Purchases');
  static String get navPurchasing => L10n.t('navPurchasing', 'Purchasing');
  static String get purchasingTitle => L10n.t('purchasingTitle', 'Purchasing');
  static String get newPurchaseTab => L10n.t('newPurchaseTab', 'New purchase');
  static String get purchasesSubtitle => L10n.t(
    'purchasesSubtitle',
    'Multi-line orders, receipts and supplier bills',
  );
  static String get searchPurchases =>
      L10n.t('searchPurchases', 'Search PO number or supplier…');
  static String get poNumberColumn => L10n.t('poNumberColumn', 'PO number');
  static String get supplierColumn => L10n.t('supplierColumn', 'Supplier');
  static String get orderedColumn => L10n.t('orderedColumn', 'Ordered');
  static String get allPurchasesExport =>
      L10n.t('allPurchasesExport', 'All purchase orders');
  static String get openOrdersMetric =>
      L10n.t('openOrdersMetric', 'Open orders');
  static String get awaitingApproval =>
      L10n.t('awaitingApproval', 'Needs action');
  static String get onOrderValueMetric =>
      L10n.t('onOrderValueMetric', 'On-order value');
  static String openOrdersCount(int count) => 'Open ($count)';
  static String closedOrdersCount(int count) => 'Received & cancelled ($count)';
  static String get noPurchasesYet =>
      L10n.t('noPurchasesYet', 'No purchase orders yet');
  static String get purchasesOfflineTitle =>
      L10n.t('purchasesOfflineTitle', 'Purchases need internet');
  static String get purchasesOfflineBody => L10n.t(
    'purchasesOfflineBody',
    'Purchase orders change stock and money, so they cannot be queued offline. Reconnect to continue.',
  );
  static String get retryAction => L10n.t('retryAction', 'Retry');
  static String get newOrderAction => L10n.t('newOrderAction', 'New order');
  static String get createOrderTitle =>
      L10n.t('createOrderTitle', 'New purchase order');
  static String get createOrderAction =>
      L10n.t('createOrderAction', 'Create order');
  static String get orderCreatedMessage =>
      L10n.t('orderCreatedMessage', 'Order drafted — submit it for approval');
  static String ordersCreatedMessage(int count) => L10n.tp(
    'ordersCreatedMessage',
    '{count} orders created — one per supplier.',
    {'count': '$count'},
  );
  static String createFailed(Object e) => 'Could not create order: $e';
  static String get purchaseSupplierModeLabel =>
      L10n.t('purchaseSupplierModeLabel', 'Supplier mode');
  static String get purchaseSupplierModeSingle =>
      L10n.t('purchaseSupplierModeSingle', 'One supplier');
  static String get purchaseSupplierModePerItem =>
      L10n.t('purchaseSupplierModePerItem', 'Per item');
  static String get purchaseSupplierModeNone =>
      L10n.t('purchaseSupplierModeNone', 'No supplier');
  static String get purchasePerItemHint => L10n.t(
    'purchasePerItemHint',
    'Each line gets its own supplier. Saving creates one order per supplier automatically.',
  );
  static String purchaseNoSupplierHint(String supplierName) => L10n.tp(
    'purchaseNoSupplierHint',
    'No supplier needed — the order is saved under “$supplierName”.',
    {'supplierName': supplierName},
  );
  static String get purchaseLineSupplierLabel =>
      L10n.t('purchaseLineSupplierLabel', 'Line supplier');
  static String get purchaseLineNeedsSupplier =>
      L10n.t('purchaseLineNeedsSupplier', 'Each line needs a supplier');
  static String get submitAction => L10n.t('submitAction', 'Submit');
  static String get approveAction => L10n.t('approveAction', 'Approve');
  static String get orderSubmittedMessage =>
      L10n.t('orderSubmittedMessage', 'Order submitted for approval');
  static String get orderApprovedMessage =>
      L10n.t('orderApprovedMessage', 'Order approved — ready to receive');
  static String get orderCancelledMessage =>
      L10n.t('orderCancelledMessage', 'Order cancelled');
  static String transitionFailed(String action, Object e) =>
      'Could not $action: $e';
  static String get receiveTitle => L10n.t('receiveTitle', 'Receive goods');
  static String get receiveGrnAction =>
      L10n.t('receiveGrnAction', 'Record receipt');
  static String get goodsReceivedMessage =>
      L10n.t('goodsReceivedMessage', 'Receipt recorded — stock updated');
  static String receiveFailedGeneric(Object e) => 'Could not receive: $e';
  static String get returnTitle => L10n.t('returnTitle', 'Return to supplier');
  static String get returnAction => L10n.t('returnAction', 'Record return');
  static String get returnRecordedMessage =>
      L10n.t('returnRecordedMessage', 'Return recorded — stock reduced');
  static String returnFailed(Object e) => 'Could not return: $e';
  static String get invoiceTitle => L10n.t('invoiceTitle', 'Supplier invoice');
  static String get invoiceAction => L10n.t('invoiceAction', 'Save invoice');
  static String get invoiceSavedMessage =>
      L10n.t('invoiceSavedMessage', 'Invoice saved');
  static String invoiceFailed(Object e) => 'Could not save invoice: $e';
  static String get payTitle => L10n.t('payTitle', 'Record payment');
  static String get payAction => L10n.t('payAction', 'Record payment');
  static String get paymentSavedMessage =>
      L10n.t('paymentSavedMessage', 'Payment recorded');
  static String paymentFailed(Object e) => 'Could not record payment: $e';
  static String orderSubtitle(String poNumber, String supplier) =>
      '$poNumber · $supplier';

  // -------------------------------------------------------------------------
  // Requisition: unified multi-supplier order cart
  // -------------------------------------------------------------------------

  static String get reqAddOneItem =>
      L10n.t('reqAddOneItem', 'Add at least one item to the order');

  static String get reqAddWhatsapp =>
      L10n.t('reqAddWhatsapp', 'Add WhatsApp number to send.');

  static String get reqAddWhatsappToSend => L10n.t(
    'reqAddWhatsappToSend',
    'Add a WhatsApp number to this supplier to send the order.',
  );

  static String get reqAssignAll =>
      L10n.t('reqAssignAll', 'Assign supplier to all items');

  static String get reqCartEmpty => L10n.t('reqCartEmpty', 'Cart is empty');

  static String get reqCartEmptyHint => L10n.t(
    'reqCartEmptyHint',
    'Add items from stock, then assign each a supplier — or assign one supplier to everything at once.',
  );

  static String get reqCartSubtitle =>
      L10n.t('reqCartSubtitle', 'One order, any suppliers');

  static String get reqCartTitle => L10n.t('reqCartTitle', 'Order cart');

  static String get reqClearDelivery =>
      L10n.t('reqClearDelivery', 'Clear delivery date');

  static String get reqClearSearch => L10n.t('reqClearSearch', 'Clear search');

  static String get reqClose => L10n.t('reqClose', 'Close');

  static String get reqCloseCart => L10n.t('reqCloseCart', 'Close cart');

  static String get reqConfirmedNote =>
      L10n.t('reqConfirmedNote', 'Confirmed by supplier.');

  static String get reqCopied =>
      L10n.t('reqCopied', 'Message copied to clipboard.');

  static String get reqCopyMessage => L10n.t('reqCopyMessage', 'Copy message');

  static String get reqDeliveryOptional =>
      L10n.t('reqDeliveryOptional', 'Delivery date (optional)');

  static String get reqDidItSend => L10n.t('reqDidItSend', 'Did this send?');

  static String get reqExportLoadFailed =>
      L10n.t('reqExportLoadFailed', 'Could not load order details.');

  static String get reqExportTitle =>
      L10n.t('reqExportTitle', 'Order details & export');

  static String get reqLineNeedsSupplier => L10n.t(
    'reqLineNeedsSupplier',
    'Needs a supplier before you can send this order.',
  );

  static String get reqLinkInvalid =>
      L10n.t('reqLinkInvalid', 'This order link is invalid.');

  static String get reqMarkConfirmed =>
      L10n.t('reqMarkConfirmed', 'Mark Confirmed');

  static String get reqMarkSent => L10n.t('reqMarkSent', 'Mark as Sent');

  static String get reqMarkedConfirmed =>
      L10n.t('reqMarkedConfirmed', 'Marked as confirmed.');

  static String get reqMarkedSent => L10n.t('reqMarkedSent', 'Marked as sent.');

  static String get reqMessageTitle =>
      L10n.t('reqMessageTitle', 'WhatsApp message (as prepared)');

  static String get reqMetaDelivery =>
      L10n.t('reqMetaDelivery', 'Delivery requested');

  static String get reqMetaPlaced => L10n.t('reqMetaPlaced', 'Placed');

  static String get reqMetaPoCount =>
      L10n.t('reqMetaPoCount', 'Purchase orders');

  static String get reqMetaRequisition =>
      L10n.t('reqMetaRequisition', 'Requisition');

  static String get reqMetaStatus => L10n.t('reqMetaStatus', 'Status');

  static String get reqMetaTotal =>
      L10n.t('reqMetaTotal', 'Total across suppliers');

  static String get reqNeedsInternet =>
      L10n.t('reqNeedsInternet', 'Ordering needs internet');

  static String get reqNeedsInternetBody => L10n.t(
    'reqNeedsInternetBody',
    'Supplier assignment and submit change live data, so they cannot run offline. Reconnect to continue.',
  );

  static String get reqNoBusiness =>
      L10n.t('reqNoBusiness', 'Orders need an active store context');

  static String reqNoMatch(String q) =>
      L10n.tp('reqNoMatch', 'No suppliers match "{q}".', {'q': q});

  static String get reqNoSupplier => L10n.t('reqNoSupplier', 'No supplier');

  static String get reqNoSuppliers => L10n.t(
    'reqNoSuppliers',
    'No suppliers yet. Add one from the Suppliers tab.',
  );

  static String get reqNoWhatsapp =>
      L10n.t('reqNoWhatsapp', 'No WhatsApp number');

  static String get reqNotYet => L10n.t('reqNotYet', 'Not yet');

  static String get reqOrderLoadFailed =>
      L10n.t('reqOrderLoadFailed', 'Could not load this order');

  static String get reqOrderReady =>
      L10n.t('reqOrderReady', 'Order sent for preparation');

  static String get reqOverrideAll =>
      L10n.t('reqOverrideAll', 'Override items that already have a supplier');

  static String get reqPickerBulkTitle =>
      L10n.t('reqPickerBulkTitle', 'Assign supplier to all items');

  static String reqPickerForItem(String item) =>
      L10n.tp('reqPickerForItem', 'For {item}', {'item': item});

  static String get reqPickerItemTitle =>
      L10n.t('reqPickerItemTitle', 'Choose supplier');

  static String get reqPriceTbc =>
      L10n.t('reqPriceTbc', 'price to be confirmed');

  static String get reqQtyDown => L10n.t('reqQtyDown', 'Decrease quantity');

  static String get reqQtyUp => L10n.t('reqQtyUp', 'Increase quantity');

  static String get reqReassignAll =>
      L10n.t('reqReassignAll', 'Reassign supplier for all items');

  static String get reqReconTitle =>
      L10n.t('reqReconTitle', 'Reconciliation summary');

  static String get reqSearchSuppliers =>
      L10n.t('reqSearchSuppliers', 'Search suppliers…');

  static String reqSendBlocked(String blocker) =>
      L10n.tp('reqSendBlocked', 'Send order · {blocker}', {'blocker': blocker});

  static String get reqSendOrder => L10n.t('reqSendOrder', 'Send order');

  static String get reqSendWhatsapp =>
      L10n.t('reqSendWhatsapp', 'Send via WhatsApp');

  static String get reqSharePrint => L10n.t('reqSharePrint', 'Share / print');

  static String reqTbcBanner(String items) => L10n.tp(
    'reqTbcBanner',
    'Prices to confirm with the supplier: {items}.',
    {'items': items},
  );

  static String reqTerminalNote(String state) =>
      L10n.tp('reqTerminalNote', 'This order is {state}.', {'state': state});

  static String get reqTodaysOrder => L10n.t("reqTodaysOrder", "Today's order");

  static String get reqWhatsappFailed => L10n.t(
    'reqWhatsappFailed',
    'Could not open WhatsApp. Copy the message from Order details instead.',
  );
  static String get reqSendViaApi =>
      L10n.t('reqSendViaApi', 'Send via WhatsApp');
  static String get reqOpenInWhatsapp =>
      L10n.t('reqOpenInWhatsapp', 'Open in WhatsApp app');
  static String get reqSentViaApi =>
      L10n.t('reqSentViaApi', 'Sent via WhatsApp');
  static String get reqApiSendFailedFallback => L10n.t(
    'reqApiSendFailedFallback',
    'Automatic send failed — use the WhatsApp app instead.',
  );
  // -------------------------------------------------------------------------
  // WhatsApp Business connection (Settings)
  // -------------------------------------------------------------------------

  static String get waSettingsTitle => L10n.t('waSettingsTitle', 'WhatsApp');
  static String get waSettingsSubtitle => L10n.t(
    'waSettingsSubtitle',
    'Connect the business number to send orders automatically',
  );
  static String get waConnected => L10n.t('waConnected', 'Connected');
  static String get waNotConnected => L10n.t('waNotConnected', 'Not connected');
  static String get waConnectionError =>
      L10n.t('waConnectionError', 'Connection error');
  static String get waConnectTitle =>
      L10n.t('waConnectTitle', 'Connect WhatsApp Business');
  static String get waConnectHint => L10n.t(
    'waConnectHint',
    'Paste the sender details from the Meta dashboard (WhatsApp > API Setup). Saving verifies the credentials immediately.',
  );
  static String get waPhoneNumberIdLabel =>
      L10n.t('waPhoneNumberIdLabel', 'Phone number ID');
  static String get waDisplayNumberLabel =>
      L10n.t('waDisplayNumberLabel', 'Business number (optional)');
  static String get waAccessTokenLabel =>
      L10n.t('waAccessTokenLabel', 'Access token');
  static String get waConnectAction => L10n.t('waConnectAction', 'Connect');
  static String get waSaveAction => L10n.t('waSaveAction', 'Save');
  static String get waTestAction => L10n.t('waTestAction', 'Test connection');
  static String get waDisconnectAction =>
      L10n.t('waDisconnectAction', 'Disconnect');
  static String get waConnectedAs =>
      L10n.t('waConnectedAs', 'Connected number');
  static String get waWebhookTitle =>
      L10n.t('waWebhookTitle', 'Delivery reports & replies');
  static String get waWebhookHint => L10n.t(
    'waWebhookHint',
    'Point the Meta dashboard webhook at the URL below and paste the verify token there. Afterwards sent orders report delivered/read automatically and supplier replies appear with a confirm prompt.',
  );
  static String get waWebhookUrlLabel =>
      L10n.t('waWebhookUrlLabel', 'Webhook URL');
  static String get waVerifyTokenLabel =>
      L10n.t('waVerifyTokenLabel', 'Verify token');
  static String get waCopied => L10n.t('waCopied', 'Copied');
  static String get waRequiredField =>
      L10n.t('waRequiredField', 'This field is required');
  static String reqRemoveItem(String item) =>
      L10n.tp('reqRemoveItem', 'Remove {item}', {'item': item});
  static String reqCartCount(int count) => count == 1
      ? '1 item · one order, any suppliers'
      : '$count items · one order, any suppliers';
  static String reqItemsNeedSupplier(int count) =>
      count == 1 ? '1 item needs a supplier' : '$count items need a supplier';
  static String reqAssignAllCount(int count) => count == 1
      ? 'Assign supplier to all items (1 needs one)'
      : 'Assign supplier to all items ($count need one)';
  static String reqDeliverySet(String date) => 'Delivery: $date';
  // -------------------------------------------------------------------------
  // Inventory: groceries & menu items lists
  // -------------------------------------------------------------------------

  static String get groceriesTitle => L10n.t('groceriesTitle', 'Groceries');
  static String get menuItemsTitle => L10n.t('menuItemsTitle', 'Menu items');
  static String groceriesSubtitle(int total, int categories) =>
      '$total raw materials tracked across $categories categories';
  static String menuItemsSubtitle(int total) =>
      '$total items available for sale at the till';
  static String fullyStocked(int count) => '$count fully stocked';
  static String get nothingOutOfStock =>
      L10n.t('nothingOutOfStock', 'Nothing out of stock');
  static String outOfStockTrend(int count) => '$count out of stock';
  static String get allLinesCovered =>
      L10n.t('allLinesCovered', 'All lines covered');
  static String get needsDelivery =>
      L10n.t('needsDelivery', 'Needs a delivery');
  static String get atLastKnownCost =>
      L10n.t('atLastKnownCost', 'At last-known cost');
  static String exportCategories(int count) => '$count categories';
  static String get exportAny => L10n.t('exportAny', 'any');
  static String exportStockRange(String min, String max) => 'stock $min–$max';
  static String exportMatching(String search) =>
      L10n.tp('exportMatching', 'matching "{search}"', {'search': search});
  static String get exportAllGroceries =>
      L10n.t('exportAllGroceries', 'All groceries');
  static String get exportAllMenuItems =>
      L10n.t('exportAllMenuItems', 'All menu items');
  static String exportFiltered(String parts) =>
      L10n.tp('exportFiltered', 'Filtered by {parts}', {'parts': parts});
  static String get allCustomersExport =>
      L10n.t('allCustomersExport', 'All customers');
  static String get allSuppliersExport =>
      L10n.t('allSuppliersExport', 'All suppliers');
  static String get availableAtTill =>
      L10n.t('availableAtTill', 'Available at the till');
  static String get emDash => L10n.t('emDash', '—');
  static String get groceryItemsMetric =>
      L10n.t('groceryItemsMetric', 'Grocery items');
  static String get searchItemsSkuSupplier =>
      L10n.t('searchItemsSkuSupplier', 'Search items, SKU or supplier');
  static String get searchItemsCategory =>
      L10n.t('searchItemsCategory', 'Search items or category');
  static String get nameColumn => L10n.t('nameColumn', 'Name');
  static String get itemColumn => L10n.t('itemColumn', 'Item');
  static String get categoryColumn => L10n.t('categoryColumn', 'Category');
  static String get stockColumn => L10n.t('stockColumn', 'Stock');
  static String get unitColumn => L10n.t('unitColumn', 'Unit');
  static String get reorderAtColumn => L10n.t('reorderAtColumn', 'Reorder at');
  static String get statusColumn => L10n.t('statusColumn', 'Status');
  static String get priceColumn => L10n.t('priceColumn', 'Price');
  static String get activeColumn => L10n.t('activeColumn', 'Active');
  static String get viewDetail => L10n.t('viewDetail', 'View detail');
  static String get editItem => L10n.t('editItem', 'Edit item');
  static String get adjustStock => L10n.t('adjustStock', 'Adjust stock');
  static String get addToOrderCart =>
      L10n.t('addToOrderCart', 'Add to order cart');
  static String addedToOrderCart(String name) =>
      'Added $name to the order cart';
  static String get viewCartAction => L10n.t('viewCartAction', 'View cart');
  static String get logWaste => L10n.t('logWaste', 'Log waste');
  static String get transferStock => L10n.t('transferStock', 'Transfer stock');
  static String get deleteAction => L10n.t('deleteAction', 'Delete');
  static String deleteItemTitle(String name) => 'Delete $name?';
  static String get deleteGroceryBody => L10n.t(
    'deleteGroceryBody',
    'The item and its stock count will be removed from inventory. '
        'This cannot be undone.',
  );
  static String get deleteMenuItemBody => L10n.t(
    'deleteMenuItemBody',
    'The item will be removed from the menu and inventory. '
        'This cannot be undone.',
  );
  static String itemDeleted(String name) => '$name deleted';
  static String deleteFailed(Object e) => 'Could not delete: $e';
  static String get notTracked => L10n.t('notTracked', 'Not tracked');
  static String get archivedBadge => L10n.t('archivedBadge', 'Archived');
  static String get activeBadge => L10n.t('activeBadge', 'Active');
  static String get notForSale => L10n.t('notForSale', 'Not for sale');
  static String get topSeller => L10n.t('topSeller', 'Top seller');
  static String get menuRevenue => L10n.t('menuRevenue', 'Menu revenue');
  static String get addGroceryItem =>
      L10n.t('addGroceryItem', 'Add grocery item');
  static String get addMenuItem => L10n.t('addMenuItem', 'Add menu item');
  static String get addItem => L10n.t('addItem', 'Add item');
  static String get belowThreshold =>
      L10n.t('belowThreshold', 'Below threshold');
  static String get outOfStockMetric =>
      L10n.t('outOfStockMetric', 'Out of stock');
  static String get stockValueMetric =>
      L10n.t('stockValueMetric', 'Stock value');

  // -------------------------------------------------------------------------
  // Inventory: item detail
  // -------------------------------------------------------------------------

  static String get restoreItem => L10n.t('restoreItem', 'Restore item');
  static String get archiveItem => L10n.t('archiveItem', 'Archive item');
  static String get deleteItem => L10n.t('deleteItem', 'Delete item');
  static String get deleteItemBodyFull => L10n.t(
    'deleteItemBodyFull',
    'The item, its stock count and its entire movement history will be '
        'removed. This cannot be undone.',
  );
  static String itemArchived(String name) => '$name archived';
  static String itemRestored(String name) => '$name restored';
  static String get moreActions => L10n.t('moreActions', 'More actions');
  static String get currentStock => L10n.t('currentStock', 'Current stock');
  static String get unitCostLabel => L10n.t('unitCostLabel', 'Unit cost');
  static String get inventoryValue =>
      L10n.t('inventoryValue', 'Inventory value');
  static String get atCost => L10n.t('atCost', 'At cost');
  static String get lowStockAt => L10n.t('lowStockAt', 'Low stock at');
  static String get warnAtOrBelow =>
      L10n.t('warnAtOrBelow', 'Warn at or below');
  static String perUnit(String unit) => 'per $unit';
  static String get notSet => L10n.t('notSet', 'Not set');
  static String get atTheTill => L10n.t('atTheTill', 'At the till');
  static String get setPriceForMargin =>
      L10n.t('setPriceForMargin', 'Set a price to see margin');
  static String get perItemSold => L10n.t('perItemSold', 'Per item sold');
  static String get availableValue => L10n.t('availableValue', 'Available');
  static String get notListed => L10n.t('notListed', 'Not listed');
  static String get showingAtTill =>
      L10n.t('showingAtTill', 'Showing at the till');
  static String get archivedNoPrice =>
      L10n.t('archivedNoPrice', 'Archived or no price set');
  static String movementsCount(int count) => '$count movements';
  static String get noMovementsRecorded =>
      L10n.t('noMovementsRecorded', 'No movements recorded yet');
  static String get aboutThisItem => L10n.t('aboutThisItem', 'About this item');
  static String get noDescription =>
      L10n.t('noDescription', 'No description added yet. Use Edit to add one.');
  static String get itemTypeGrocery => L10n.t('itemTypeGrocery', 'Grocery');
  static String get itemTypeMenuItem => L10n.t('itemTypeMenuItem', 'Menu item');
  static String get itemTypeBoth => L10n.t('itemTypeBoth', 'Bought and sold');
  static String get notForSaleTill =>
      L10n.t('notForSaleTill', 'Not for sale — set a selling price to add it');
  static String availableForSale(String price) => 'Available for sale ($price)';
  static String get sellingPrice => L10n.t('sellingPrice', 'Selling price');
  static String get costBasis => L10n.t('costBasis', 'Cost basis');
  static String get marginLabel => L10n.t('marginLabel', 'Margin');
  static String get posAvailability =>
      L10n.t('posAvailability', 'POS availability');
  static String get editRecipe => L10n.t('editRecipe', 'Edit recipe');
  static String get addRecipe => L10n.t('addRecipe', 'Add recipe');
  static String get recordProduction =>
      L10n.t('recordProduction', 'Record production');
  static String get stockHistory => L10n.t('stockHistory', 'Stock history');
  static String get whenColumn => L10n.t('whenColumn', 'When');
  static String get typeColumn => L10n.t('typeColumn', 'Type');
  static String get changeColumn => L10n.t('changeColumn', 'Change');
  static String get balanceColumn => L10n.t('balanceColumn', 'Balance');
  static String get byColumn => L10n.t('byColumn', 'By');
  static String get noMovementsYet =>
      L10n.t('noMovementsYet', 'No movements recorded yet');
  static String get aboutItem => L10n.t('aboutItem', 'About this item');
  static String get itemTypeLabel => L10n.t('itemTypeLabel', 'Item type');
  static String get groceryType => L10n.t('groceryType', 'Grocery');
  static String get menuItemType => L10n.t('menuItemType', 'Menu item');
  static String get bothType => L10n.t('bothType', 'Bought and sold');
  static String get skuLabel => L10n.t('skuLabel', 'SKU');
  static String get supplierLabel => L10n.t('supplierLabel', 'Supplier');
  static String get countedIn => L10n.t('countedIn', 'Counted in');
  static String get stockTracking => L10n.t('stockTracking', 'Stock tracking');
  static String get onValue => L10n.t('onValue', 'On');
  static String get offValue => L10n.t('offValue', 'Off');
  static String get lastCounted => L10n.t('lastCounted', 'Last counted');
  static String get neverCounted => L10n.t('neverCounted', 'Never');
  static String get posMenu => L10n.t('posMenu', 'POS menu');
  static String itemNotFound(String id) => 'Item $id not found';
  static String get backToInventory =>
      L10n.t('backToInventory', 'Back to inventory');

  // -------------------------------------------------------------------------
  // Inventory: production / waste / transfer / adjust dialogs
  // -------------------------------------------------------------------------

  static String get amountPositive =>
      L10n.t('amountPositive', 'Enter an amount greater than zero');
  static String get confirmedPositive =>
      L10n.t('confirmedPositive', 'Confirmed output must be greater than zero');
  static String productionRecorded(String quantity, String name) =>
      'Recorded $quantity × $name';
  static String productionRecordedAdjusted(
    String quantity,
    String name,
    String suggested,
  ) => 'Recorded $quantity × $name (suggested $suggested)';
  static String recordFailed(String message) => 'Could not record: $message';
  static String get recordProductionTitle =>
      L10n.t('recordProductionTitle', 'Record production');
  static String get howManyNeeded =>
      L10n.t('howManyNeeded', 'How many do you need?');
  static String get howManyNeededHint =>
      L10n.t('howManyNeededHint', 'Enter the number of products to achieve');
  static String get targetQuantity =>
      L10n.t('targetQuantity', 'Target quantity');
  static String get continueToMeasure =>
      L10n.t('continueToMeasure', 'See what to measure');
  static String get measureIngredients =>
      L10n.t('measureIngredients', 'Measure ingredients');
  static String get measureIngredientsHint => L10n.t(
    'measureIngredientsHint',
    'Recommended amounts for your target — adjust anything you measure differently',
  );
  static String get measuredAmount => L10n.t('measuredAmount', 'Measured');
  static String get adjustAllHint =>
      L10n.t('adjustAllHint', 'Every line is adjustable before cooking');
  static String get backToTarget => L10n.t('backToTarget', 'Back');
  static String get continueToConfirm =>
      L10n.t('continueToConfirm', 'Continue to confirm');
  static String get confirmAchieved =>
      L10n.t('confirmAchieved', 'Confirm achieved');
  static String get achievedQuantity =>
      L10n.t('achievedQuantity', 'Amount achieved');
  static String get achievedHint =>
      L10n.t('achievedHint', 'After cooking, enter what you actually got');
  static String get yieldAbove =>
      L10n.t('yieldAbove', 'Above target — over-yield');
  static String get yieldWithin =>
      L10n.t('yieldWithin', 'Within threshold — target met');
  static String get yieldBelow =>
      L10n.t('yieldBelow', 'Below target — under-yield');
  static String yieldVarianceLine(String variance, String percent) =>
      'Variance $variance ($percent)';
  static String get toleranceLabel => L10n.t('toleranceLabel', 'Threshold ±%');
  static String get recipesTab => L10n.t('recipesTab', 'Recipes');
  static String get runsTab => L10n.t('runsTab', 'Runs');
  static String get productionZoneTab =>
      L10n.t('productionZoneTab', 'Production Zone');
  static String get outputTab => L10n.t('outputTab', 'Output');
  static String get newRun => L10n.t('newRun', 'New run');
  static String get planRunTitle => L10n.t('planRunTitle', 'Plan a batch');
  static String get pickRecipe => L10n.t('pickRecipe', 'Recipe');
  static String get runTargetHint =>
      L10n.t('runTargetHint', 'How many to make');
  static String get startRun => L10n.t('startRun', 'Start');
  static String get startRunTitle => L10n.t('startRunTitle', 'Start batch');
  static String get completeRun => L10n.t('completeRun', 'Complete');
  static String get completeRunTitle =>
      L10n.t('completeRunTitle', 'Record output');
  static String get actualYield => L10n.t('actualYield', 'Actual yield');
  static String get actualYieldHint =>
      L10n.t('actualYieldHint', 'What cooking actually produced');
  static String get wasteReasonHint => L10n.t(
    'wasteReasonHint',
    'e.g. spillage, burning, over-portioning (optional)',
  );
  static String get publishAction =>
      L10n.t('publishAction', 'Publish to POS & Inventory');
  static String get cookWizardTitle =>
      L10n.t('cookWizardTitle', 'Cook a batch');
  static String get cookStepRecipe => L10n.t('cookStepRecipe', 'Recipe');
  static String get cookStepPlan => L10n.t('cookStepPlan', 'Plan');
  static String get cookStepWeigh => L10n.t('cookStepWeigh', 'Weigh');
  static String get cookStepCook => L10n.t('cookStepCook', 'Cook');
  static String get cookStepRecord => L10n.t('cookStepRecord', 'Record');
  static String get cookStepReview => L10n.t('cookStepReview', 'Publish');
  static String get chooseRecipeHint =>
      L10n.t('chooseRecipeHint', 'Choose what to cook today');
  static String get recordOutputNow =>
      L10n.t('recordOutputNow', 'Record output');
  static String get illRecordLater =>
      L10n.t('illRecordLater', 'I’ll record later');
  static String get reviewPublishTitle =>
      L10n.t('reviewPublishTitle', 'Review & publish');
  static String get publishedTitle => L10n.t('publishedTitle', 'Published!');
  static String get yieldLabel => L10n.t('yieldLabel', 'Yield');
  static String get wasteLabel => L10n.t('wasteLabel', 'Waste');
  static String get statusLabel => L10n.t('statusLabel', 'Status');
  static String get publishedBadge => L10n.t('publishedBadge', 'Published');
  static String get awaitingPublish =>
      L10n.t('awaitingPublish', 'Awaiting publish');
  static String get pendingBadge => L10n.t('pendingBadge', 'Pending');
  static String get inProgressBadge => L10n.t('inProgressBadge', 'In progress');
  static String get completedBadge => L10n.t('completedBadge', 'Completed');
  static String get allFilter => L10n.t('allFilter', 'All');
  static String get noRunsYetFilter =>
      L10n.t('noRunsYetFilter', 'No runs in this state yet');
  static String get scheduleFirstRun =>
      L10n.t('scheduleFirstRun', 'Plan the first batch from a recipe');
  static String get deleteRunTitle =>
      L10n.t('deleteRunTitle', 'Delete this planned batch?');
  static String deleteRunBody(String recipe, String target) =>
      'The planned batch of $target × $recipe will be removed. Nothing was deducted.';
  static String runScheduled(String target, String recipe) =>
      'Planned $target × $recipe';
  static String runStarted(String recipe) =>
      '$recipe batch started — ingredients deducted';
  static String runCompleted(String actual, String recipe) =>
      'Recorded $actual × $recipe — verify, then publish';
  static String runPublished(String actual, String recipe) =>
      '$actual × $recipe is now on sale';
  static String runDeletedLine(String recipe) =>
      'Planned $recipe batch deleted';
  static String runFailed(Object e) => 'Could not update run: $e';
  static String costPerUnit(String cost) => '$cost / unit';
  static String get costEstimated => L10n.t('costEstimated', 'est.');
  static String batchYieldLine(String qty, String unit) => 'Makes $qty $unit';
  static String get ledgerAction => L10n.t('ledgerAction', 'Full ledger');
  static String get verifyQueueHint => L10n.t(
    'verifyQueueHint',
    'Completed batches awaiting verification and publish',
  );
  static String guidedStepOf(int step, int total) => 'Step $step of $total';
  static String get whatMakingToday =>
      L10n.t('whatMakingToday', 'What are we making today?');
  static String get howManyToday =>
      L10n.t('howManyToday', 'How many do you need today?');
  static String get howManyTodayHint => L10n.t(
    'howManyTodayHint',
    'Just the number — we work out every ingredient for you',
  );
  static String get planSavedTitle => L10n.t('planSavedTitle', 'Plan saved!');
  static String planSavedBody(String target, String recipe) =>
      'Your plan for $target × $recipe is saved. Nothing is deducted yet.';
  static String get whatHappensNext =>
      L10n.t('whatHappensNext', 'What happens next');
  static String get nextWeigh =>
      L10n.t('nextWeigh', '1. Weigh the ingredients and tap Start cooking');
  static String get nextCook =>
      L10n.t('nextCook', '2. Cook — take your time, hours if needed');
  static String get nextRecord =>
      L10n.t('nextRecord', '3. Come back and record what you actually got');
  static String get seeWhatToWeigh =>
      L10n.t('seeWhatToWeigh', 'See what to weigh');
  static String get illCookLater => L10n.t('illCookLater', 'I’ll cook later');
  static String get weighAndStart =>
      L10n.t('weighAndStart', 'Weigh each line, then start');
  static String get startCookingHint => L10n.t(
    'startCookingHint',
    'Adjust anything you measure differently, then start — ingredients leave stock at that moment',
  );
  static String get cookingTitle => L10n.t('cookingTitle', 'You’re cooking!');
  static String get cookingBody => L10n.t(
    'cookingBody',
    'Ingredients are deducted. Come back to the Production Zone when the food is ready and tap Continue, then Record output.',
  );
  static String get welcomeBack => L10n.t('welcomeBack', 'Welcome back!');
  static String get howManyGot =>
      L10n.t('howManyGot', 'How many did you actually get?');
  static String targetWasLine(String target, String recipe) =>
      'Target was $target × $recipe';
  static String get anythingLost =>
      L10n.t('anythingLost', 'Did anything get lost or wasted?');
  static String get anythingLostHint =>
      L10n.t('anythingLostHint', 'Optional — helps track losses');
  static String savedVerify(String actual, String recipe) =>
      'Saved $actual × $recipe. Check the Output tab to verify and publish.';
  static String get finishLater => L10n.t('finishLater', 'I’ll finish later');
  static String get savedCooking => L10n.t(
    'savedCooking',
    'Saved — your batch is cooking. Find it under Runs to record the output later.',
  );
  static String plannedNext(String target, String recipe) =>
      'Planned $target × $recipe · tap Start when you begin cooking';
  static String cookingNext(String time) =>
      'Cooking since $time · tap Record output when done';
  static String runPublishedVerdict(
    String actual,
    String recipe,
    String verdict,
  ) => '$actual × $recipe published — now selling on POS. $verdict';
  static String get gotIt => L10n.t('gotIt', 'Got it');
  static String get toleranceHint =>
      L10n.t('toleranceHint', 'Allowed band around the target (default 5%)');
  static String get measuredIngredient =>
      L10n.t('measuredIngredient', 'Measured ingredient');
  static String get measuredHelper =>
      L10n.t('measuredHelper', 'What you actually put on the scale');
  static String get quantityUsed => L10n.t('quantityUsed', 'Quantity used');
  static String get suggestedOutput =>
      L10n.t('suggestedOutput', 'Suggested output');
  static String get confirmedOutput =>
      L10n.t('confirmedOutput', 'Confirmed output');
  static String get acceptSuggestionHint =>
      L10n.t('acceptSuggestionHint', 'Leave blank to accept the suggestion');
  static String get sameAsSuggested =>
      L10n.t('sameAsSuggested', 'Same as suggested');
  static String get willConsume => L10n.t('willConsume', 'Will consume');
  static String ingredientOption(String name, String unit) => '$name ($unit)';
  static String makesRecipe(String name, String needs) =>
      'Makes $name · per unit needs $needs';
  static String makesBatchRecipe(
    String yieldQty,
    String yieldUnit,
    String needs,
  ) => 'Makes $yieldQty $yieldUnit · needs $needs';
  static String consumptionLine(String needed, String unit, String onHand) =>
      '$needed $unit · $onHand in stock';
  static String get wasteReasonExpired =>
      L10n.t('wasteReasonExpired', 'Expired');
  static String get wasteReasonSpoiled =>
      L10n.t('wasteReasonSpoiled', 'Spoiled');
  static String get wasteReasonPrep => L10n.t('wasteReasonPrep', 'Prep error');
  static String get wasteReasonDropped =>
      L10n.t('wasteReasonDropped', 'Dropped / damaged');
  static String get wasteReasonOther => L10n.t('wasteReasonOther', 'Other');
  static String onlyInStock(String quantity, String unit) =>
      'Only $quantity $unit in stock';
  static String wasteLogged(String amount, String unit, String name) =>
      '$amount $unit of $name logged as waste';
  static String wasteFailed(Object e) => 'Could not log waste: $e';
  static String wastePhotoEvidence(String name) => 'Photo: $name';
  static String get quantityWasted =>
      L10n.t('quantityWasted', 'Quantity wasted');
  static String get remainingAfterWaste =>
      L10n.t('remainingAfterWaste', 'Remaining after waste');
  static String get wasteReasonLabel =>
      L10n.t('wasteReasonLabel', 'Waste reason');
  static String get wasteNotesHint =>
      L10n.t('wasteNotesHint', 'e.g. left out of the chiller overnight');
  static String get photoLabel => L10n.t('photoLabel', 'Photo');
  static String get photoClaimHelper =>
      L10n.t('photoClaimHelper', 'Optional — useful for a supplier claim');
  static String get addPhoto => L10n.t('addPhoto', 'Add photo');
  static String get transferTo => L10n.t('transferTo', 'Transfer to');
  static String get thisStore => L10n.t('thisStore', 'this store');
  static String movingOutOf(String? store) =>
      'Moving out of ${store ?? thisStore}';
  static String get selectLocation =>
      L10n.t('selectLocation', 'Select a location');
  static String get quantityToTransfer =>
      L10n.t('quantityToTransfer', 'Quantity to transfer');
  static String get remainingAtStore =>
      L10n.t('remainingAtStore', 'Remaining at this store');
  static String get transferNotesHint =>
      L10n.t('transferNotesHint', 'e.g. covering their Friday service');
  static String transferNoteTo(String destination) => 'To $destination';
  static String transferNoteToWith(String destination, String note) =>
      'To $destination · $note';
  static String transferDone(
    String amount,
    String unit,
    String item,
    String destination,
  ) => '$amount $unit of $item transferred to $destination';
  static String transferFailed(Object e) => 'Could not transfer stock: $e';
  static String get adjustType => L10n.t('adjustType', 'Adjustment type');
  static String get addStockOption => L10n.t('addStockOption', 'Add stock');
  static String get deliveryOrFound =>
      L10n.t('deliveryOrFound', 'Delivery or found');
  static String get removeStockOption =>
      L10n.t('removeStockOption', 'Remove stock');
  static String get correctionOrLoss =>
      L10n.t('correctionOrLoss', 'Correction or loss');
  static String get newStockLevel => L10n.t('newStockLevel', 'New stock level');
  static String get reasonLabel => L10n.t('reasonLabel', 'Reason');
  static String get adjustReasonAdd => L10n.t('adjustReasonAdd', 'Restock');
  static String get adjustReasonRecount =>
      L10n.t('adjustReasonRecount', 'Recount / correction');
  static String get adjustReasonDamaged =>
      L10n.t('adjustReasonDamaged', 'Damaged');
  static String get adjustReasonOther => L10n.t('adjustReasonOther', 'Other');
  static String get confirmAdjustment =>
      L10n.t('confirmAdjustment', 'Confirm adjustment');
  static String newLevelLabel(String quantity, String unit) =>
      '$quantity $unit';
  static String adjustReasonWith(String label, String note) => '$label · $note';
  static String adjustedTo(String name, String level) =>
      '$name adjusted to $level';
  static String adjustFailed(Object e) => 'Could not adjust stock: $e';
  static String get adjustNotesHint =>
      L10n.t('adjustNotesHint', 'e.g. counted with Marco after close');
  static String get everyIngredientPositive => L10n.t(
    'everyIngredientPositive',
    'Every ingredient needs an amount greater than zero',
  );
  static String get ingredientOnce => L10n.t(
    'ingredientOnce',
    'Each ingredient only once — change the amount instead',
  );
  static String recipeSaved(String name, bool isEdit) =>
      isEdit ? '$name recipe saved' : '$name recipe added';
  static String recipeDeletedLine(String name) => '$name recipe deleted';
  static String deleteRecipeBody(String name, int lines) =>
      'The $name recipe and its $lines ingredient lines will be removed. '
      'Recorded production runs keep their history. This cannot be undone.';
  static String get editRecipeTitle => L10n.t('editRecipeTitle', 'Edit recipe');
  static String get addRecipeTitle => L10n.t('addRecipeTitle', 'Add recipe');
  static String get saveChanges => L10n.t('saveChanges', 'Save changes');
  static String get addRecipeAction => L10n.t('addRecipeAction', 'Add recipe');
  static String get menuItemProduces => L10n.t('menuItemProduces', 'Menu item');
  static String get recipeProducesHelper =>
      L10n.t('recipeProducesHelper', 'What this recipe produces');
  static String get selectHint => L10n.t('selectHint', 'Select');
  static String get recipeName => L10n.t('recipeName', 'Recipe name');
  static String get recipeNameExample =>
      L10n.t('recipeNameExample', 'e.g. Pilau');
  static String get recipeNameHelper =>
      L10n.t('recipeNameHelper', 'Shown on production runs');
  static String get recipeNameDefault =>
      L10n.t('recipeNameDefault', 'Defaults to the menu item\u2019s name');
  static String get recipeCategory => L10n.t('recipeCategory', 'Category');
  static String get recipeCategoryHelper =>
      L10n.t('recipeCategoryHelper', 'Prep, sauce, or finished dish');
  static String recipeCategoryName(String category) => switch (category) {
    'prep' => L10n.t('recipeCategoryPrep', 'Prep'),
    'sauce' => L10n.t('recipeCategorySauce', 'Sauce'),
    'finished' => L10n.t('recipeCategoryFinished', 'Finished dish'),
    _ => category,
  };
  static String get targetYieldQty =>
      L10n.t('targetYieldQty', 'Makes (quantity)');
  static String get targetYieldUnit =>
      L10n.t('targetYieldUnit', 'Makes (unit)');
  static String get targetYieldHelper =>
      L10n.t('targetYieldHelper', 'Batch size below is written for this yield');
  static String get targetPositive =>
      L10n.t('targetPositive', 'Target yield must be greater than zero');
  static String get batchTotalsHint =>
      L10n.t('batchTotalsHint', 'Amounts below are totals for the batch above');
  static String get ingredientsSection =>
      L10n.t('ingredientsSection', 'Ingredients');
  static String get addIngredient => L10n.t('addIngredient', 'Add');
  static String get ingredientHint => L10n.t('ingredientHint', 'Ingredient');
  static String get removeIngredient =>
      L10n.t('removeIngredient', 'Remove ingredient');
  static String get deleteRecipeTitle =>
      L10n.t('deleteRecipeTitle', 'Delete this recipe?');
  static String get keepAction => L10n.t('keepAction', 'Keep');
  static String get stockStatusLabel =>
      L10n.t('stockStatusLabel', 'Stock status');
  static String get stockQuantityLabel =>
      L10n.t('stockQuantityLabel', 'Stock quantity');
  static String get groceriesTab => L10n.t('groceriesTab', 'Groceries');
  static String get menuItemsTab => L10n.t('menuItemsTab', 'Menu items');

  // -------------------------------------------------------------------------
  // Suppliers
  // -------------------------------------------------------------------------

  static String get suppliersTitle => L10n.t('suppliersTitle', 'Suppliers');
  static String get suppliersSubtitle => L10n.t(
    'suppliersSubtitle',
    'Vendors this business orders restock inventory from',
  );
  static String get addSupplier => L10n.t('addSupplier', 'Add supplier');
  static String get totalSuppliers =>
      L10n.t('totalSuppliers', 'Total suppliers');
  static String get activeVendorRecords =>
      L10n.t('activeVendorRecords', 'Active vendor records');
  static String get searchSupplier =>
      L10n.t('searchSupplier', 'Search by name, phone, or email');
  static String get editAction => L10n.t('editAction', 'Edit');
  static String deleteSupplierTitle(String name) => 'Delete $name?';
  static String get deleteSupplierBody => L10n.t(
    'deleteSupplierBody',
    'This supplier record will be removed. Past purchases keep their '
        'attribution. This cannot be undone.',
  );
  static String supplierDeleted(String name) => '$name deleted';
  static String get phoneColumn => L10n.t('phoneColumn', 'Phone');
  static String get emailColumn => L10n.t('emailColumn', 'Email');
  static String get editSupplier => L10n.t('editSupplier', 'Edit supplier');
  static String get addSupplierTitle =>
      L10n.t('addSupplierTitle', 'Add supplier');
  static String get supplierInfo => L10n.t('supplierInfo', 'Supplier info');
  static String get supplierNameHint =>
      L10n.t('supplierNameHint', 'Supplier or company name');
  static String get enterName => L10n.t('enterName', 'Enter a name');
  static String get supplierPhoneExample =>
      L10n.t('supplierPhoneExample', '+1 (555) 123-4567');
  static String get supplierEmailExample =>
      L10n.t('supplierEmailExample', 'orders@supplier.com');
  static String get addressHint =>
      L10n.t('addressHint', 'Street address (optional)');
  static String get notesLabel2 => L10n.t('notesLabel2', 'Notes');
  static String get supplierNotesHint =>
      L10n.t('supplierNotesHint', 'Delivery notes, account number...');
  static String supplierSaved(String name, bool isEdit) =>
      isEdit ? '$name updated' : '$name added';

  // -------------------------------------------------------------------------
  // Item form
  // -------------------------------------------------------------------------

  static String get editItemTitle => L10n.t('editItemTitle', 'Edit item');
  static String get addItemTitle => L10n.t('addItemTitle', 'Add item');
  static String get whatAdding => L10n.t('whatAdding', 'What are you adding?');
  static String get chooserSubtitle => L10n.t(
    'chooserSubtitle',
    'This decides which fields the form leads with — nothing here is final.',
  );
  static String get groceryOption => L10n.t('groceryOption', 'Grocery');
  static String get groceryOptionBlurb =>
      L10n.t('groceryOptionBlurb', 'A raw material you stock and use');
  static String get menuItemOption => L10n.t('menuItemOption', 'Menu item');
  static String get menuItemOptionBlurb =>
      L10n.t('menuItemOptionBlurb', 'Something you sell at the till');
  static String get bothOptionBlurb => L10n.t(
    'bothOptionBlurb',
    'This item is both bought and sold — e.g. a bottled drink',
  );
  static String get changeType => L10n.t('changeType', 'Change');
  static String get basicInfo => L10n.t('basicInfo', 'Basic info');
  static String get pricingStock => L10n.t('pricingStock', 'Pricing & stock');
  static String get pricingSection => L10n.t('pricingSection', 'Pricing');
  static String get stockSection => L10n.t('stockSection', 'Stock');
  static String get statusSection => L10n.t('statusSection', 'Status');
  static String get photoSection => L10n.t('photoSection', 'Photo');
  static String get itemNameLabel => L10n.t('itemNameLabel', 'Item name');
  static String get itemNameExample =>
      L10n.t('itemNameExample', 'e.g. Heirloom Tomatoes');
  static String get categoryLabel => L10n.t('categoryLabel', 'Category');
  static String get selectOption => L10n.t('selectOption', 'Select');
  static String get skuLabel2 => L10n.t('skuLabel2', 'SKU');
  static String get skuHelper => L10n.t('skuHelper', 'Generated if left blank');
  static String get skuExample => L10n.t('skuExample', 'PRD-1001');
  static String get descriptionLabel =>
      L10n.t('descriptionLabel', 'Description');
  static String get descriptionHelper =>
      L10n.t('descriptionHelper', 'Shown on the item\'s detail page');
  static String get descriptionExample =>
      L10n.t('descriptionExample', 'Grade, origin, prep notes…');
  static String get trackStockLabel =>
      L10n.t('trackStockLabel', 'Track stock for this item');
  static String get trackStockOn =>
      L10n.t('trackStockOn', 'Counted against a low-stock threshold');
  static String get trackStockOff =>
      L10n.t('trackStockOff', 'No counts, no low-stock warnings');
  static String get moneyHint => L10n.t('moneyHint', '0.00');
  static String get lowAlertLabel => L10n.t('lowAlertLabel', 'Low stock alert');
  static String get lowAlertHelper =>
      L10n.t('lowAlertHelper', 'Warn at or below this');
  static String get reorderQtyLabel =>
      L10n.t('reorderQtyLabel', 'Reorder quantity');
  static String get reorderQtyHelper =>
      L10n.t('reorderQtyHelper', 'How much to order when restocking');
  static String get allowNegativeLabel =>
      L10n.t('allowNegativeLabel', 'Allow stock to go negative');
  static String get allowNegativeOn => L10n.t(
    'allowNegativeOn',
    'A sale can go through before the count catches up',
  );
  static String get allowNegativeOff =>
      L10n.t('allowNegativeOff', 'A sale is blocked once stock reaches zero');
  static String get priceRequiredTill =>
      L10n.t('priceRequiredTill', 'Required to appear on the POS menu');
  static String get costSourceLabel =>
      L10n.t('costSourceLabel', 'Unit cost source');
  static String get costSourceAuto =>
      L10n.t('costSourceAuto', 'From recipe');
  static String get costSourceManual =>
      L10n.t('costSourceManual', 'Manual');
  static String costAutoHelper(int count) => L10n.tp(
    'costAutoHelper',
    'From {count} ingredients at current grocery prices — updates as prices change',
    {'count': '$count'},
  );
  static String get costAutoEstimated => L10n.t(
    'costAutoEstimated',
    'Some ingredients have no cost yet — this is an estimate',
  );
  static String get costNoRecipeHint => L10n.t(
    'costNoRecipeHint',
    'No recipe for this item yet — the cost stays unknown and the item stays inactive until a recipe prices it.',
  );
  static String get costAutoIncompleteHint => L10n.t(
    'costAutoIncompleteHint',
    'Some ingredients have no cost yet — the recipe cannot price this item until they do.',
  );
  static String get inactiveUntilReadyTitle =>
      L10n.t('inactiveUntilReadyTitle', 'Stays inactive for now');
  static String get inactiveUntilReadyBody => L10n.t(
    'inactiveUntilReadyBody',
    'This item activates once a recipe prices it — until then it stays off the menu.',
  );
  static String menuItemAddedInactive(String name) => L10n.tp(
    'menuItemAddedInactive',
    '{name} added as inactive — add a recipe to activate it',
    {'name': name},
  );
  static String get priceGroceryHint => L10n.t(
    'priceGroceryHint',
    'Not shown for groceries — change type to set a price',
  );
  static String get openingStock => L10n.t('openingStock', 'Opening stock');
  static String get openingStockHelper =>
      L10n.t('openingStockHelper', 'What is on the shelf today');
  static String get unitLabel => L10n.t('unitLabel', 'Unit');
  static String get activeOption => L10n.t('activeOption', 'Active');
  static String get activeOptionBlurb =>
      L10n.t('activeOptionBlurb', 'Counted and reorderable');
  static String get archivedOption => L10n.t('archivedOption', 'Archived');
  static String get archivedOptionBlurb =>
      L10n.t('archivedOptionBlurb', 'Kept for reporting only');
  static String get currentStockReadonly =>
      L10n.t('currentStockReadonly', 'Current stock');
  static String get adjustFlowHint =>
      L10n.t('adjustFlowHint', 'Changes go through Stock Adjust');
  static String stockValue(Object value, Object unit) => '$value $unit';
  static String itemSaved(String name, bool isEdit) =>
      isEdit ? '$name updated' : '$name added to inventory';

  static String get addNewSupplier =>
      L10n.t('addNewSupplier', 'Add new supplier');

  // -------------------------------------------------------------------------
  // Sales
  // -------------------------------------------------------------------------

  static String get salesTitle => L10n.t('salesTitle', 'Sales');
  static String salesSubtitle(String date) => L10n.tp(
    'salesSubtitle',
    'Orders, takings and refunds across {date}',
    {'date': date},
  );
  static String get checkNewOrders =>
      L10n.t('checkNewOrders', 'Check for new orders');
  static String get totalSales => L10n.t('totalSales', 'Total sales');
  static String netOfRefunds(String period) =>
      L10n.tp('netOfRefunds', 'Net of refunds, {period}', {'period': period});
  static String get selectedPeriod =>
      L10n.t('selectedPeriod', 'the selected period');
  static String get ordersMetric => L10n.t('ordersMetric', 'Orders');
  static String itemsSold(int count) =>
      L10n.tp('itemsSold', '{count} items sold', {'count': '$count'});
  static String get averageOrder => L10n.t('averageOrder', 'Average order');
  static String get noRefundsInView =>
      L10n.t('noRefundsInView', 'No refunds in this view');
  static String refundedCount(int count) =>
      L10n.tp('refundedCount', '{count} refunded', {'count': '$count'});
  static String get searchOrders =>
      L10n.t('searchOrders', 'Search order, server, item or payment');
  static String get dateSort => L10n.t('dateSort', 'Date');
  static String get orderSort => L10n.t('orderSort', 'Order');
  static String get itemsSort => L10n.t('itemsSort', 'Items');
  static String get totalSort => L10n.t('totalSort', 'Total');
  static String get paymentSort => L10n.t('paymentSort', 'Payment');
  static String get fulfillmentSort => L10n.t('fulfillmentSort', 'Fulfillment');
  static String get statusSort => L10n.t('statusSort', 'Status');
  static String get viewDetailAction =>
      L10n.t('viewDetailAction', 'View detail');
  static String get assignCourier => L10n.t('assignCourier', 'Assign courier');
  static String get refundOrder => L10n.t('refundOrder', 'Refund order');
  static String get printReceipt => L10n.t('printReceipt', 'Print receipt');
  static String receiptSentWithNumber(String prefix, String suffix) => L10n.tp(
    'receiptSentWithNumber',
    'Receipt {prefix}{suffix} sent to printer',
    {'prefix': prefix, 'suffix': suffix},
  );
  static String refundTitle(String id) =>
      L10n.tp('refundTitle', 'Refund {id}?', {'id': id});
  static String refundBody(String total, String method) => L10n.tp(
    'refundBody',
    '{total} will be returned to {method} and removed from takings.',
    {'total': total, 'method': method},
  );
  static String orderRefunded(String id) =>
      L10n.tp('orderRefunded', '{id} refunded', {'id': id});
  static String get dateRangeFilter => L10n.t('dateRangeFilter', 'Date range');
  static String get paymentMethodFilter =>
      L10n.t('paymentMethodFilter', 'Payment method');
  static String get statusFilter => L10n.t('statusFilter', 'Status');
  static String get selectSalesPeriod =>
      L10n.t('selectSalesPeriod', 'Select a sales period');
  static String get changePeriod => L10n.t('changePeriod', 'Change period');
  static String get customPeriod => L10n.t('customPeriod', 'Custom…');
  static String get customLabel => L10n.t('customLabel', 'Custom');
  static String customRangeLabel(String from, String to) =>
      L10n.tp('customRangeLabel', '{from} – {to}', {'from': from, 'to': to});
  static String relativeToday(String time) =>
      L10n.tp('relativeToday', 'Today, {time}', {'time': time});
  static String relativeYesterday(String time) =>
      L10n.tp('relativeYesterday', 'Yesterday, {time}', {'time': time});
  static String get couriersTitle => L10n.t('couriersTitle', 'Couriers');
  static String get availableMetric => L10n.t('availableMetric', 'Available');
  static String get readyForDelivery =>
      L10n.t('readyForDelivery', 'Ready for delivery');
  static String get unavailableMetric =>
      L10n.t('unavailableMetric', 'Unavailable');
  static String get offlineTrend => L10n.t('offlineTrend', 'Offline');
  static String get totalMetric => L10n.t('totalMetric', 'Total');
  static String get couriersOnTeam =>
      L10n.t('couriersOnTeam', 'Couriers on team');
  static String activeCount(int count) =>
      L10n.tp('activeCount', 'Active ({count})', {'count': '$count'});
  static String inactiveCount(int count) =>
      L10n.tp('inactiveCount', 'Inactive ({count})', {'count': '$count'});
  static String get noCouriers => L10n.t('noCouriers', 'No couriers added');
  static String get addCourier => L10n.t('addCourier', 'Add courier');
  static String get addCourierTitle =>
      L10n.t('addCourierTitle', 'Add courier');
  static String get editCourier => L10n.t('editCourier', 'Edit courier');
  static String get vehicleLabel => L10n.t('vehicleLabel', 'Vehicle');
  static String get vehicleHint =>
      L10n.t('vehicleHint', 'e.g. Motorbike, Bicycle, Car (optional)');
  static String get availableLabel => L10n.t('availableLabel', 'Available');
  static String get availableHelper => L10n.t(
    'availableHelper',
    'Available couriers can be assigned to delivery orders.',
  );
  static String courierSaved(String name, bool isEdit) =>
      isEdit ? '$name updated' : '$name added';
  static String courierDeleted(String name) => '$name deleted';
  static String deleteCourierTitle(String name) => 'Delete $name?';
  static String get deleteCourierBody => L10n.t(
    'deleteCourierBody',
    'This courier will be removed. Assigned deliveries keep their history.',
  );
  static String get recentBadge => L10n.t('recentBadge', 'NEW');
  static String get orderColumn => L10n.t('orderColumn', 'Order');
  static String get dateTimeColumn => L10n.t('dateTimeColumn', 'Date & time');

  // -------------------------------------------------------------------------
  // Finance
  // -------------------------------------------------------------------------

  static String get otherExpensesTitle =>
      L10n.t('otherExpensesTitle', 'Other expenses');
  static String get otherExpensesSubtitle => L10n.t(
    'otherExpensesSubtitle',
    'Ad-hoc costs outside inventory purchases and payroll',
  );
  static String get addExpense => L10n.t('addExpense', 'Add expense');
  static String get totalExpenses => L10n.t('totalExpenses', 'Total expenses');
  static String get inCurrentView => L10n.t('inCurrentView', 'In current view');
  static String get entriesMetric => L10n.t('entriesMetric', 'Entries');
  static String get trackedInView => L10n.t('trackedInView', 'Tracked in view');
  static String get largestCategory =>
      L10n.t('largestCategory', 'Largest category');
  static String get searchExpenses =>
      L10n.t('searchExpenses', 'Search description, payee or category');
  static String get descriptionSort => L10n.t('descriptionSort', 'Description');
  static String get categorySort => L10n.t('categorySort', 'Category');
  static String get amountSort => L10n.t('amountSort', 'Amount');
  static String deleteExpenseTitle(String name) => 'Delete $name?';
  static String get deleteExpenseBody => L10n.t(
    'deleteExpenseBody',
    'This expense will be removed and cannot be recovered.',
  );
  static String expenseDeleted(String name) => '$name deleted';
  static String get allEntries => L10n.t('allEntries', 'All entries');
  static String financeExportBetween(
    String fromMonth,
    String fromDay,
    String toMonth,
    String toDay,
  ) => 'between $fromMonth/$fromDay and $toMonth/$toDay';
  static String get otherIncomesTitle =>
      L10n.t('otherIncomesTitle', 'Other incomes');
  static String get otherIncomesSubtitle => L10n.t(
    'otherIncomesSubtitle',
    'Ad-hoc revenue outside point-of-sale transactions',
  );
  static String get addIncome => L10n.t('addIncome', 'Add income');
  static String get totalOtherIncome =>
      L10n.t('totalOtherIncome', 'Total other income');
  static String get averageEntry => L10n.t('averageEntry', 'Average entry');
  static String get noEntries => L10n.t('noEntries', 'No entries');
  static String entrySources(int count) => '$count sources';
  static String get searchIncomes =>
      L10n.t('searchIncomes', 'Search description, source or category');
  static String deleteIncomeTitle(String name) => 'Delete $name?';
  static String get deleteIncomeBody => L10n.t(
    'deleteIncomeBody',
    'This income entry will be removed and cannot be recovered.',
  );
  static String incomeDeleted(String name) => '$name deleted';
  static String get categoryFilter => L10n.t('categoryFilter', 'Category');
  static String get pickDateRange =>
      L10n.t('pickDateRange', 'Pick a date range');
  static String financeFilterDate(
    String fromMonth,
    String fromDay,
    String toMonth,
    String toDay,
  ) => '$fromMonth/$fromDay – $toMonth/$toDay';
  static String get clearAllFilters => L10n.t('clearAllFilters', 'Clear all');
  static String get financeExpensesTab =>
      L10n.t('financeExpensesTab', 'Other expenses');
  static String get financeIncomesTab =>
      L10n.t('financeIncomesTab', 'Other incomes');
  static String get addExpenseTitle => L10n.t('addExpenseTitle', 'Add expense');
  static String get editExpenseTitle =>
      L10n.t('editExpenseTitle', 'Edit expense');
  static String get addIncomeTitle => L10n.t('addIncomeTitle', 'Add income');
  static String get editIncomeTitle => L10n.t('editIncomeTitle', 'Edit income');
  static String get dateLabel => L10n.t('dateLabel', 'Date');
  static String get amountLabel => L10n.t('amountLabel', 'Amount');
  static String get amountRequired =>
      L10n.t('amountRequired', 'Amount is required');
  static String get validAmount =>
      L10n.t('validAmount', 'Enter a valid amount');
  static String get paymentMethodLabel =>
      L10n.t('paymentMethodLabel', 'Payment Method');
  static String get categoryRequired =>
      L10n.t('categoryRequired', 'Category is required');
  static String get descriptionRequired =>
      L10n.t('descriptionRequired', 'Description is required');
  static String get payeeOptional =>
      L10n.t('payeeOptional', 'Payee (optional)');
  static String get noteOptional => L10n.t('noteOptional', 'Note (optional)');
  static String get sourceOptional =>
      L10n.t('sourceOptional', 'Source (optional)');
  static String get receiptOptional =>
      L10n.t('receiptOptional', 'Receipt (optional)');
  static String get uploadReceipt => L10n.t('uploadReceipt', 'Upload receipt');
  static String get addAction => L10n.t('addAction', 'Add');
  static String get updateAction => L10n.t('updateAction', 'Update');
  static String expenseSaved(bool isEdit) =>
      isEdit ? 'Expense updated' : 'Expense added';
  static String incomeSaved(bool isEdit) =>
      isEdit ? 'Income updated' : 'Income added';
  static String get refundWhyHint =>
      L10n.t('refundWhyHint', 'Why is this being refunded?');
  static String get refundAction => L10n.t('refundAction', 'Refund');
  static String assignCourierTitle(String order) => L10n.tp(
    'assignCourierTitle',
    'Assign courier for {order}',
    {'order': order},
  );
  static String get currentlyAssigned =>
      L10n.t('currentlyAssigned', 'Currently assigned');
  static String get reassignTo => L10n.t('reassignTo', 'Reassign to');
  static String get selectCourier => L10n.t('selectCourier', 'Select courier');
  static String get noCouriersAvailable =>
      L10n.t('noCouriersAvailable', 'No couriers available');
  static String courierAssigned(String name, String order) => L10n.tp(
    'courierAssigned',
    '{name} assigned to {order}',
    {'name': name, 'order': order},
  );

  // -------------------------------------------------------------------------
  // Customers
  // -------------------------------------------------------------------------

  static String get customersTitle => L10n.t('customersTitle', 'Customers');
  static String get customersSubtitle =>
      L10n.t('customersSubtitle', 'All customer profiles and order history');
  static String get addCustomer => L10n.t('addCustomer', 'Add customer');
  static String get totalCustomers =>
      L10n.t('totalCustomers', 'Total customers');
  static String get registeredProfiles =>
      L10n.t('registeredProfiles', 'Registered profiles');
  static String get lifetimeSpend => L10n.t('lifetimeSpend', 'Lifetime spend');
  static String get totalRevenueFromCustomers =>
      L10n.t('totalRevenueFromCustomers', 'Total revenue from customers');
  static String get averageSpend => L10n.t('averageSpend', 'Average spend');
  static String get perCustomer => L10n.t('perCustomer', 'Per customer');
  static String get searchCustomers =>
      L10n.t('searchCustomers', 'Search by name or phone');
  static String get lastOrderSort => L10n.t('lastOrderSort', 'Last order');
  static String get totalSpentSort => L10n.t('totalSpentSort', 'Total spent');
  static String deleteCustomerTitle(String name) => 'Delete $name?';
  static String get deleteCustomerBody => L10n.t(
    'deleteCustomerBody',
    'This customer record will be removed. This cannot be undone.',
  );
  static String customerDeleted(String name) => '$name deleted';
  static String get ordersColumn => L10n.t('ordersColumn', 'Orders');
  static String get lastOrderColumn => L10n.t('lastOrderColumn', 'Last order');
  static String get totalSpentColumn =>
      L10n.t('totalSpentColumn', 'Total spent');
  static String get contactInfo => L10n.t('contactInfo', 'Contact info');
  static String get fullNameExample =>
      L10n.t('fullNameExample', 'Amina Hassan');
  static String get fullNameHint => L10n.t('fullNameHint', 'Full name');
  static String get enterNameError => L10n.t('enterNameError', 'Enter a name');
  static String get phoneExample2 =>
      L10n.t('phoneExample2', '+1 (555) 123-4567');
  static String get enterPhoneError =>
      L10n.t('enterPhoneError', 'Enter a phone number');
  static String get emailExample2 =>
      L10n.t('emailExample2', 'email@example.com');
  static String get addressExample2 =>
      L10n.t('addressExample2', 'Street address (optional)');
  static String get editCustomer => L10n.t('editCustomer', 'Edit customer');
  static String get addCustomerTitle =>
      L10n.t('addCustomerTitle', 'Add customer');
  static String customerSaved(String name, bool isEdit) =>
      isEdit ? '$name updated' : '$name added';
  static String get ordersPlaced => L10n.t('ordersPlaced', 'Orders placed');
  static String get totalTransactions =>
      L10n.t('totalTransactions', 'Total transactions');
  static String get totalSpentMetric =>
      L10n.t('totalSpentMetric', 'Total spent');
  static String get lifetimeValue => L10n.t('lifetimeValue', 'Lifetime value');
  static String get averageOrderMetric =>
      L10n.t('averageOrderMetric', 'Average order');
  static String get perOrder => L10n.t('perOrder', 'Per order');
  static String get profilePanel => L10n.t('profilePanel', 'Profile');
  static String get emailField => L10n.t('emailField', 'Email');
  static String get addressField => L10n.t('addressField', 'Address');
  static String get joinedField => L10n.t('joinedField', 'Joined');
  static String get lastOrderField => L10n.t('lastOrderField', 'Last order');
  static String get orderHistory => L10n.t('orderHistory', 'Order history');
  static String orderHistoryCount(int count) => '$count orders';
  static String get noOrdersYet => L10n.t('noOrdersYet', 'No orders yet');
  static String get customerNotFound =>
      L10n.t('customerNotFound', 'Customer not found');
  static String customerMissing(String id) => '$id doesn\'t exist';
  static String get backToCustomers =>
      L10n.t('backToCustomers', 'Back to customers');

  // -------------------------------------------------------------------------
  // Staff
  // -------------------------------------------------------------------------

  static String get staffTitle => L10n.t('staffTitle', 'Staff');
  static String staffSubtitle(int total, int roles, int active) =>
      '$total people across $roles roles · $active active';
  static String get rolesAction => L10n.t('rolesAction', 'Roles');
  static String get inviteStaff => L10n.t('inviteStaff', 'Invite staff');
  static String get totalStaff => L10n.t('totalStaff', 'Total staff');
  static String rolesInUse(int count) => '$count roles in use';
  static String get activeMetric => L10n.t('activeMetric', 'Active');
  static String get everyoneActive =>
      L10n.t('everyoneActive', 'Everyone active');
  static String deactivatedCount(int count) => '$count deactivated';
  static String get pendingInvites =>
      L10n.t('pendingInvites', 'Pending invites');
  static String get nothingOutstanding =>
      L10n.t('nothingOutstanding', 'Nothing outstanding');
  static String get awaitingSignIn =>
      L10n.t('awaitingSignIn', 'Awaiting first sign-in');
  static String get searchStaff =>
      L10n.t('searchStaff', 'Search name, email or role');
  static String get nameSort => L10n.t('nameSort', 'Name');
  static String get roleSort => L10n.t('roleSort', 'Role');
  static String get lastActiveSort => L10n.t('lastActiveSort', 'Last active');
  static String get removeFromTeam =>
      L10n.t('removeFromTeam', 'Remove from team');
  static String removeMemberTitle(String name) => 'Remove $name?';
  static String revokeRolesBody(int count) => count == 1
      ? 'This revokes their role at this business.'
      : 'This revokes all $count of their roles at this business.';
  static String get removeAction => L10n.t('removeAction', 'Remove');
  static String memberRemoved(String name) => '$name removed from the team';
  static String removeRolesFailed(String name) =>
      "Couldn't remove all of $name's roles — try again";
  static String get allStaffExport => L10n.t('allStaffExport', 'All staff');
  static String get nameCol => L10n.t('nameCol', 'Name');
  static String get roleCol => L10n.t('roleCol', 'Role');
  static String get emailCol => L10n.t('emailCol', 'Email');
  static String get lastActiveCol => L10n.t('lastActiveCol', 'Last active');
  static String get statusCol => L10n.t('statusCol', 'Status');
  static String get neverActive => L10n.t('neverActive', 'Never');
  static String get recentActivity =>
      L10n.t('recentActivity', 'Recent activity');
  static String get addRole => L10n.t('addRole', 'Add role');
  static String get contactPanel => L10n.t('contactPanel', 'Contact');
  static String get invitedValue => L10n.t('invitedValue', 'Invited');
  static String get joinedValue => L10n.t('joinedValue', 'Joined');
  static String get lastActiveField => L10n.t('lastActiveField', 'Last active');
  static String get neverSignedIn => L10n.t('neverSignedIn', 'Never signed in');
  static String get accessPanel => L10n.t('accessPanel', 'Access');
  static String get noRolesHere =>
      L10n.t('noRolesHere', 'No roles at this business.');
  static String get inviteMessage => L10n.t('inviteMessage', 'Invite message');
  static String roleRemovedFrom(String role, String member) =>
      '$role removed from $member';
  static String get couldNotRemoveRole =>
      L10n.t('couldNotRemoveRole', 'Could not remove that role');
  static String get roleGone =>
      L10n.t('roleGone', 'This role no longer exists.');
  static String get removeRoleTooltip =>
      L10n.t('removeRoleTooltip', 'Remove this role');
  static String get ordersToday => L10n.t('ordersToday', 'Orders today');
  static String get notOnShift => L10n.t('notOnShift', 'Not on shift');
  static String get onTheTill => L10n.t('onTheTill', 'On the till');
  static String get ordersThisWeek =>
      L10n.t('ordersThisWeek', 'Orders this week');
  static String get last7Days => L10n.t('last7Days', 'Last 7 days');
  static String get salesHandled => L10n.t('salesHandled', 'Sales handled');
  static String get noInviteActivity => L10n.t(
    'noInviteActivity',
    'Nothing yet — this invite has not been accepted',
  );
  static String get noActivityRecorded =>
      L10n.t('noActivityRecorded', 'No activity recorded');
  static String staffNotFound(String id) => 'Staff member $id not found';
  static String get backToStaff => L10n.t('backToStaff', 'Back to staff');

  // -------------------------------------------------------------------------
  // Notifications
  // -------------------------------------------------------------------------

  static String get notificationsTitle =>
      L10n.t('notificationsTitle', 'Notifications');
  static String get markAllRead => L10n.t('markAllRead', 'Mark all read');
  static String get noNotificationsYet =>
      L10n.t('noNotificationsYet', 'No notifications yet');
  static String get notificationsEmptyHint => L10n.t(
    'notificationsEmptyHint',
    'Orders, low stock alerts and insights will appear here',
  );
  static String get markAsRead => L10n.t('markAsRead', 'Mark as read');
  static String get newOrderType => L10n.t('newOrderType', 'New Order');
  static String get lowStockType => L10n.t('lowStockType', 'Low Stock');
  static String get aiInsightType => L10n.t('aiInsightType', 'AI Insight');
  static String get deliveryUpdateType =>
      L10n.t('deliveryUpdateType', 'Delivery Update');

  // -------------------------------------------------------------------------
  // Enum display labels (badges, dropdowns, timelines)
  // -------------------------------------------------------------------------

  static String get cashLabel => L10n.t('cashLabel', 'Cash');
  static String get cardLabel => L10n.t('cardLabel', 'Card');
  static String get qrisLabel => L10n.t('qrisLabel', 'QRIS');
  static String get mobilePayLabel => L10n.t('mobilePayLabel', 'Mobile Pay');
  static String get giftCardLabel => L10n.t('giftCardLabel', 'Gift Card');
  static String get paidStatus => L10n.t('paidStatus', 'Paid');
  static String get refundedStatus => L10n.t('refundedStatus', 'Refunded');
  static String get voidedStatus => L10n.t('voidedStatus', 'Voided');
  static String get pendingStatus => L10n.t('pendingStatus', 'Pending');
  static String get newStatus => L10n.t('newStatus', 'New');
  static String get preparingStatus => L10n.t('preparingStatus', 'Preparing');
  static String get readyStatus => L10n.t('readyStatus', 'Ready');
  static String get outForDeliveryStatus =>
      L10n.t('outForDeliveryStatus', 'Out for Delivery');
  static String get completedStatus => L10n.t('completedStatus', 'Completed');
  static String get dineInType => L10n.t('dineInType', 'Dine-in');
  static String get takeawayType => L10n.t('takeawayType', 'Takeaway');
  static String get deliveryType => L10n.t('deliveryType', 'Delivery');
  static String get inStockStatus => L10n.t('inStockStatus', 'In stock');
  static String get lowStockStatus => L10n.t('lowStockStatus', 'Low stock');
  static String get outOfStockStatus =>
      L10n.t('outOfStockStatus', 'Out of stock');
  static String get activeStatus => L10n.t('activeStatus', 'Active');
  static String get inactiveStatus => L10n.t('inactiveStatus', 'Inactive');
  static String get pendingInviteStatus =>
      L10n.t('pendingInviteStatus', 'Pending invite');
  static String get courierAvailable =>
      L10n.t('courierAvailable', 'Available for deliveries');
  static String get courierUnavailable =>
      L10n.t('courierUnavailable', 'Not available');
  static String get headOfficeType => L10n.t('headOfficeType', 'Head Office');
  static String get restaurantBranchType =>
      L10n.t('restaurantBranchType', 'Restaurant Branch');
  static String get kitchenType => L10n.t('kitchenType', 'Kitchen');
  static String get warehouseType => L10n.t('warehouseType', 'Warehouse');
  static String get farmType => L10n.t('farmType', 'Farm');
  static String get depotType => L10n.t('depotType', 'Depot');
  static String get todayRange => L10n.t('todayRange', 'Today');
  static String get weekRange => L10n.t('weekRange', 'This week');
  static String get monthRange => L10n.t('monthRange', 'This month');
  static String get allTimeRange => L10n.t('allTimeRange', 'All time');
  static String get customRange => L10n.t('customRange', 'Custom');
  static String get restockMovement => L10n.t('restockMovement', 'Restock');
  static String get saleMovement => L10n.t('saleMovement', 'Sale');
  static String get wasteMovement => L10n.t('wasteMovement', 'Waste');
  static String get adjustmentMovement =>
      L10n.t('adjustmentMovement', 'Adjustment');
  static String get transferMovement => L10n.t('transferMovement', 'Transfer');
  static String get restaurantType => L10n.t('restaurantType', 'Restaurant');
  static String get supplierType => L10n.t('supplierType', 'Supplier');
  static String get farmerType => L10n.t('farmerType', 'Farmer');
  static String get distributorType => L10n.t('distributorType', 'Distributor');
  static String get platformOperatorType =>
      L10n.t('platformOperatorType', 'Platform Operator');
  static String get otherType => L10n.t('otherType', 'Other');
  static String get comfortableDensity =>
      L10n.t('comfortableDensity', 'Comfortable');
  static String get comfortableBlurb =>
      L10n.t('comfortableBlurb', 'Roomier rows, easier to tap');
  static String get compactDensity => L10n.t('compactDensity', 'Compact');
  static String get compactBlurb =>
      L10n.t('compactBlurb', 'More rows on screen at once');
  static String get englishLanguage => L10n.t('englishLanguage', 'English');

  // -------------------------------------------------------------------------
  // Order detail
  // -------------------------------------------------------------------------

  static String get orderTypeLabel => L10n.t('orderTypeLabel', 'Order type');
  static String get seatedAt => L10n.t('seatedAt', 'Seated at');
  static String get serverLabel => L10n.t('serverLabel', 'Server');
  static String get placedLabel => L10n.t('placedLabel', 'Placed');
  static String get detailsPanel => L10n.t('detailsPanel', 'Details');
  static String itemCountTitle(int count) => '$count items';
  static String quantityPrice(String quantity, String price) =>
      '$quantity × $price';
  static String get paymentPanel => L10n.t('paymentPanel', 'Payment');
  static String get subtotalRow => L10n.t('subtotalRow', 'Subtotal');
  static String discountRow(String percent) => 'Discount ($percent)';
  static String discountAmount(String amount) => '−$amount';
  static String taxRow(String percent) => 'Tax ($percent)';
  static String get totalRow => L10n.t('totalRow', 'Total');
  static String refundedTo(String method) => 'Refunded to $method';
  static String paidBy(String method) => 'Paid by $method';
  static String receiptSent(String id) => 'Receipt for $id sent to printer';
  static String get changeCourier => L10n.t('changeCourier', 'Change courier');
  static String get assignCourierAction =>
      L10n.t('assignCourierAction', 'Assign courier');
  static String get alreadyRefunded =>
      L10n.t('alreadyRefunded', 'Already refunded');
  static String get refundOrderAction =>
      L10n.t('refundOrderAction', 'Refund order');
  static String statusChanged(String label) => 'Status changed to $label';
  static String refundDialogTitle(String id) => 'Refund $id?';
  static String refundDialogBody(String total, String method) =>
      '$total will be returned to $method and removed from today\'s takings.';
  static String orderRefunded2(String id) => '$id refunded';
  static String orderNotFound(String id) => 'Order $id not found';
  static String get backToSales => L10n.t('backToSales', 'Back to sales');

  // -------------------------------------------------------------------------
  // AI insights
  // -------------------------------------------------------------------------

  static String get insightsTitle => L10n.t('insightsTitle', 'Insights');
  static String get insightsSubtitle => L10n.t(
    'insightsSubtitle',
    'Generated from your live stock, sales and waste data',
  );
  static String get askNotConnected => L10n.t(
    'askNotConnected',
    'Ask is not connected to a model yet — the cards on the left are '
        'generated locally from your data.',
  );
  static String get askAboutBusiness =>
      L10n.t('askAboutBusiness', 'Ask about your business');
  static String get askExample =>
      L10n.t('askExample', 'e.g. which supplier costs me the most?');
  static String get askAction => L10n.t('askAction', 'Ask');
  static String get tryAsking => L10n.t('tryAsking', 'TRY ASKING');

  // -------------------------------------------------------------------------
  // Dashboard
  // -------------------------------------------------------------------------

  static String get goodMorning => L10n.t('goodMorning', 'Good morning');
  static String get goodAfternoon => L10n.t('goodAfternoon', 'Good afternoon');
  static String get goodEvening => L10n.t('goodEvening', 'Good evening');
  static String greetingFor(String greeting, String firstName) => L10n.tp(
    'greetingFor',
    '{greeting}, {firstName}',
    {'greeting': greeting, 'firstName': firstName},
  );
  static String get openTill => L10n.t('openTill', 'Open till');
  static String get todaySales => L10n.t('todaySales', "Today's sales");
  static String vsYesterday(String amount) =>
      L10n.tp('vsYesterday', 'vs {amount} yesterday', {'amount': amount});
  static String yesterdayCount(String count) =>
      L10n.tp('yesterdayCount', '{count} yesterday', {'count': count});
  static String get avgOrderValue => L10n.t('avgOrderValue', 'Avg order value');
  static String get perTicket => L10n.t('perTicket', 'per ticket');
  static String get staffOnShift => L10n.t('staffOnShift', 'Staff on shift');
  static String ofActive(String total) =>
      L10n.tp('ofActive', 'of {total} active', {'total': total});
  static String get netProfitToday =>
      L10n.t('netProfitToday', 'Net profit today');
  static String get netLossToday => L10n.t('netLossToday', 'Net loss today');
  static String get revenueCard => L10n.t('revenueCard', 'Revenue');
  static String get last7DaysLabel => L10n.t('last7DaysLabel', 'Last 7 days');
  static String get salesByCategory =>
      L10n.t('salesByCategory', 'Sales by category');
  static String get topSellingItems =>
      L10n.t('topSellingItems', 'Top selling items');
  static String get recentActivityCard =>
      L10n.t('recentActivityCard', 'Recent activity');
  static String get noSales7Days =>
      L10n.t('noSales7Days', 'No sales in the last 7 days.');
  static String unitsSold(Object units) =>
      L10n.tp('unitsSold', '{units} sold', {'units': '$units'});
  static String dateSuffix(String date) =>
      L10n.tp('dateSuffix', ' · {date}', {'date': date});
  static String orderPaid(String id) =>
      L10n.tp('orderPaid', 'Order {id} paid', {'id': id});
  static String orderRefundedFeed(String id) =>
      L10n.tp('orderRefundedFeed', 'Order {id} refunded', {'id': id});
  static String orderFeedDetail(int items, String server, String method) =>
      L10n.tp('orderFeedDetail', '{items} items · {server} · {method}', {
        'items': '$items',
        'server': server,
        'method': method,
      });
  static String stockOutFeed(String name) =>
      L10n.tp('stockOutFeed', '{name} is out of stock', {'name': name});
  static String stockLowFeed(String name) =>
      L10n.tp('stockLowFeed', '{name} is running low', {'name': name});
  static String stockRemaining(Object stock, Object level, String unit) =>
      L10n.tp('stockRemaining', '{stock} of {level} {unit} remaining', {
        'stock': '$stock',
        'level': '$level',
        'unit': unit,
      });

  // -------------------------------------------------------------------------
  // Dashboard widgets
  // -------------------------------------------------------------------------

  static String get lookAtToday =>
      L10n.t('lookAtToday', 'What to look at today');
  static String get seeAll => L10n.t('seeAll', 'See all');
  static String get noSalesThisPeriod =>
      L10n.t('noSalesThisPeriod', 'No sales in this period');
  static String get noSalesBreakdown =>
      L10n.t('noSalesBreakdown', 'No sales to break down yet');
  static String get totalFallback => L10n.t('totalFallback', 'Total');
  static String sharePercent(double share) => '${(share * 100).round()}%';
  static String stockAlertHeadline(int out, int low) => L10n.tp(
    'stockAlertHeadline',
    '{out} out of stock, {low} running low',
    {'out': '$out', 'low': '$low'},
  );
  static String reorderNeeded(int count) => count == 1
      ? L10n.tp('reorderNeededOne', '{count} line needs reordering', {
          'count': '$count',
        })
      : L10n.tp('reorderNeededMany', '{count} lines need reordering', {
          'count': '$count',
        });
  static String namesAndMore(String names, int extra) => L10n.tp(
    'namesAndMore',
    '{names} and {extra} more',
    {'names': names, 'extra': '$extra'},
  );
  static String rankBadge(int rank) => '$rank';
  static String trendPercent(double percent) =>
      '${percent < 10 ? percent.toStringAsFixed(1) : percent.round()}%';

  // -------------------------------------------------------------------------
  // Insights (warnings & recommendations) — generated sentences, so every
  // dynamic part goes through L10n.tp with a dedicated key.
  // -------------------------------------------------------------------------

  static String get insightPriorityUrgent =>
      L10n.t('insightPriorityUrgent', 'Act now');
  static String get insightPriorityAdvisory =>
      L10n.t('insightPriorityAdvisory', 'Worth a look');
  static String get insightPriorityInfo => L10n.t('insightPriorityInfo', 'FYI');

  static String get insightCategoryStock =>
      L10n.t('insightCategoryStock', 'Stock');
  static String get insightCategoryWaste =>
      L10n.t('insightCategoryWaste', 'Waste');
  static String get insightCategorySales =>
      L10n.t('insightCategorySales', 'Sales');
  static String get insightCategoryStaffing =>
      L10n.t('insightCategoryStaffing', 'Staffing');

  static String get insightStockHealthyTitle => L10n.t(
    'insightStockHealthyTitle',
    'Every line is above its reorder threshold',
  );
  static String get insightStockHealthyBody => L10n.t(
    'insightStockHealthyBody',
    'Nothing needs ordering today. The next thing worth watching is '
        'whichever line moves fastest over the weekend.',
  );

  static String insightStockOutTitle(int count, String plural) => L10n.tp(
    'insightStockOutTitle',
    '{count} {lines} out of stock',
    {'count': '$count', 'lines': plural},
  );
  static String get insightStockOutOne =>
      L10n.t('insightStockOutOne', 'line is');
  static String get insightStockOutMany =>
      L10n.t('insightStockOutMany', 'lines are');
  static String insightStockOutBody(String names, String more) => L10n.tp(
    'insightStockOutBody',
    'These cannot be sold or prepped until a delivery lands. {names}{more}.',
    {'names': names, 'more': more},
  );
  static String insightStockOutMore(int extra) =>
      L10n.tp('insightStockOutMore', ' and {extra} more', {'extra': '$extra'});

  static String insightReorderTitle(String name) => L10n.tp(
    'insightReorderTitle',
    '{name} is the most urgent reorder',
    {'name': name},
  );
  static String insightReorderBody(
    String stock,
    String unit,
    String level,
    String cost,
  ) => L10n.tp(
    'insightReorderBody',
    'It is at {stock} {unit} against a threshold of {level}. Restocking to '
        'threshold costs about {cost} at cost.',
    {'stock': stock, 'unit': unit, 'level': level, 'cost': cost},
  );

  static String get insightWasteNoneTitle =>
      L10n.t('insightWasteNoneTitle', 'No waste logged in the last 30 days');
  static String get insightWasteNoneBody => L10n.t(
    'insightWasteNoneBody',
    'Either the kitchen is running very tight, or waste is not being '
        'recorded. Worth confirming which — untracked waste hides a real cost.',
  );

  static String insightWasteTopTitle(String name) => L10n.tp(
    'insightWasteTopTitle',
    '{name} is your costliest waste',
    {'name': name},
  );
  static String get insightWasteFallbackName =>
      L10n.t('insightWasteFallbackName', 'One line');
  static String insightWasteTopBody(String worst, String total) => L10n.tp(
    'insightWasteTopBody',
    'It accounts for {worst} of the {total} written off in the last 30 days. '
        'Check portioning and delivery frequency before reordering at the same volume.',
    {'worst': worst, 'total': total},
  );

  static String insightSalesUpTitle(String percent) => L10n.tp(
    'insightSalesUpTitle',
    'Takings are up {percent} on yesterday',
    {'percent': percent},
  );
  static String insightSalesDownTitle(String percent) => L10n.tp(
    'insightSalesDownTitle',
    'Takings are down {percent} on yesterday',
    {'percent': percent},
  );
  static String insightSalesUpBody(String takings, int orders) => L10n.tp(
    'insightSalesUpBody',
    'Today is running ahead at {takings} across {orders} orders.',
    {'takings': takings, 'orders': '$orders'},
  );
  static String insightSalesDownBody(String takings, int orders) => L10n.tp(
    'insightSalesDownBody',
    'Today is at {takings} across {orders} orders. One slow day is noise; '
        'two is a pattern worth checking against staffing.',
    {'takings': takings, 'orders': '$orders'},
  );

  static String insightOpenTicketsTitle(int count, String verb) => L10n.tp(
    'insightOpenTicketsTitle',
    '{count} {tickets} still open',
    {'count': '$count', 'tickets': verb},
  );
  static String get insightOpenOne => L10n.t('insightOpenOne', 'ticket is');
  static String get insightOpenMany => L10n.t('insightOpenMany', 'tickets are');
  static String get insightOpenTicketsBody => L10n.t(
    'insightOpenTicketsBody',
    'Unsettled tickets do not count towards takings and are the usual '
        'cause of a till that will not reconcile at close.',
  );

  static String get evidenceOutOfStock =>
      L10n.t('evidenceOutOfStock', 'Out of stock');
  static String get evidenceValueAtRisk =>
      L10n.t('evidenceValueAtRisk', 'Value at risk');
  static String get evidenceOnHand => L10n.t('evidenceOnHand', 'On hand');
  static String get evidenceThreshold =>
      L10n.t('evidenceThreshold', 'Threshold');
  static String get evidenceUnitCost => L10n.t('evidenceUnitCost', 'Unit cost');
  static String get evidenceThisLine => L10n.t('evidenceThisLine', 'This line');
  static String get evidenceAllWaste =>
      L10n.t('evidenceAllWaste', 'All waste, 30d');
  static String get evidenceUnitsLost =>
      L10n.t('evidenceUnitsLost', 'Units lost');
  static String get evidenceToday => L10n.t('evidenceToday', 'Today');
  static String get evidenceYesterday =>
      L10n.t('evidenceYesterday', 'Yesterday');
  static String get evidenceAvgTicket =>
      L10n.t('evidenceAvgTicket', 'Avg ticket');
  static String get evidenceOpen => L10n.t('evidenceOpen', 'Open');

  static String get actionOpenInventory =>
      L10n.t('actionOpenInventory', 'Open inventory');
  static String get actionViewItem => L10n.t('actionViewItem', 'View item');
  static String get actionOpenSales => L10n.t('actionOpenSales', 'Open sales');

  static String staffClockedIn(String name) =>
      L10n.tp('staffClockedIn', '{name} clocked in', {'name': name});
  static String get staffFallbackRole => L10n.t('staffFallbackRole', 'Staff');

  static String get promptReorderWeekend => L10n.t(
    'promptReorderWeekend',
    'What needs reordering before the weekend?',
  );
  static String get promptWasteMoney =>
      L10n.t('promptWasteMoney', 'Where is my waste money going?');
  static String get promptTodayVsYesterday =>
      L10n.t('promptTodayVsYesterday', 'How did today compare with yesterday?');
  static String get promptDeadStock =>
      L10n.t('promptDeadStock', 'Which items have not moved in a month?');
  static String get promptTopServer =>
      L10n.t('promptTopServer', 'Who processed the most orders this week?');
  static String roleSaved(String name, bool isEdit) =>
      isEdit ? '"$name" updated' : '"$name" created';
  static String get roleSaveFailed =>
      L10n.t('roleSaveFailed', 'Something went wrong saving this role.');
  static String get editRole => L10n.t('editRole', 'Edit role');
  static String get createRole => L10n.t('createRole', 'Create role');
  static String get saveRole => L10n.t('saveRole', 'Save role');
  static String get basicInfoSection =>
      L10n.t('basicInfoSection', 'Basic info');
  static String get roleNameLabel => L10n.t('roleNameLabel', 'Role name');
  static String get roleNameExample =>
      L10n.t('roleNameExample', 'e.g. Shift supervisor');
  static String get nameRequired =>
      L10n.t('nameRequired', 'Give the role a name');
  static String get descriptionLabel2 =>
      L10n.t('descriptionLabel2', 'Description');
  static String get roleDescriptionHelper =>
      L10n.t('roleDescriptionHelper', 'One line on what this role is for');
  static String get roleDescriptionExample =>
      L10n.t('roleDescriptionExample', 'Runs the floor when a manager is off');
  static String get pickPermissionWarning => L10n.t(
    'pickPermissionWarning',
    'Pick at least one permission — a role that grants nothing cannot '
        'be assigned usefully.',
  );
  static String get builtinNameLocked => L10n.t(
    'builtinNameLocked',
    'Built-in roles keep their name and description. You can still change '
        'what this role is allowed to do.',
  );
  static String get permissionsSection =>
      L10n.t('permissionsSection', 'Permissions');
  static String permissionsSelected(int on, int total) =>
      '$on of $total selected';
  static String get selectAll => L10n.t('selectAll', 'Select all');
  static String groupSelected(int on, int total) => '$on of $total';
  static String get clearGroup => L10n.t('clearGroup', 'Clear');
  static String get allGroup => L10n.t('allGroup', 'All');
  static String get roleFilter => L10n.t('roleFilter', 'Role');
  static String inviteSentTo(String name) => 'Invite sent to $name';
  static String inviteSentToStore(String name, String store) =>
      'Invite sent to $name for $store';
  static String get staffTypeLabel => L10n.t('staffTypeLabel', 'Staff type');
  static String get staffTypeHelper => L10n.t(
    'staffTypeHelper',
    'Business staff work everywhere; store staff belong to one location',
  );
  static String get businessStaffOption =>
      L10n.t('businessStaffOption', 'Business');
  static String get businessStaffHelper =>
      L10n.t('businessStaffHelper', 'Works across all locations');
  static String get storeStaffOption => L10n.t('storeStaffOption', 'Store');
  static String get storeStaffHelper =>
      L10n.t('storeStaffHelper', 'Assigned to one location');
  static String get inviteStoreLabel => L10n.t('inviteStoreLabel', 'Store');
  static String get inviteStoreRequired =>
      L10n.t('inviteStoreRequired', 'Pick the store they will work at');
  static String get selectStoreHint =>
      L10n.t('selectStoreHint', 'Select a store');
  static String get inviteStoresSyncing =>
      L10n.t('inviteStoresSyncing', 'Syncing locations…');
  static String get inviteStoresEmpty => L10n.t(
    'inviteStoresEmpty',
    'No locations found — check Store Management',
  );
  static String get staffNeedsInternet => L10n.t(
    'staffNeedsInternet',
    'Staff management requires an internet connection.',
  );
  static String get inviteFailed =>
      L10n.t('inviteFailed', 'Something went wrong sending the invite.');
  static String get inviteStaffTitle =>
      L10n.t('inviteStaffTitle', 'Invite staff');
  static String get sendInvite => L10n.t('sendInvite', 'Send invite');
  static String get fullNameLabel => L10n.t('fullNameLabel', 'Full name');
  static String get teammateExample =>
      L10n.t('teammateExample', 'e.g. Tomas Alvarez');
  static String get invitePhoneHelper => L10n.t(
    'invitePhoneHelper',
    "Their invite is sent to this number — it's how the backend finds "
        'or creates their account',
  );
  static String get addRoleTitle => L10n.t('addRoleTitle', 'Add a role');
  static String get roleFallbackName => L10n.t('roleFallbackName', 'the role');
  static String get addRoleButton => L10n.t('addRoleButton', 'Add role');
  static String get holdsAllRoles =>
      L10n.t('holdsAllRoles', 'They already hold every role at this business.');
  static String memberHasRole(String member, String role) =>
      '$member now has $role';
  static String get addRoleFailed =>
      L10n.t('addRoleFailed', 'Something went wrong adding the role.');
  static String get roleLabel2 => L10n.t('roleLabel2', 'Role');
  static String get selectRoleHint => L10n.t('selectRoleHint', 'Select a role');
  static String get pickRole => L10n.t('pickRole', 'Pick a role');
  static String get roleWithoutPermissions =>
      L10n.t('roleWithoutPermissions', 'This role grants no permissions yet.');
  static String extraRoles(int count) => '+$count more';
  static String get enterFullName =>
      L10n.t('enterFullName', 'Enter their full name');
  static String get rolesPermissionsTitle =>
      L10n.t('rolesPermissionsTitle', 'Roles & permissions');
  static String rolesSubtitle(int roles, int assigned) =>
      '$roles roles · $assigned staff assigned';
  static String get backToStaffButton =>
      L10n.t('backToStaffButton', 'Back to staff');
  static String get createRoleButton =>
      L10n.t('createRoleButton', 'Create role');
  static String get totalRoles => L10n.t('totalRoles', 'Total roles');
  static String builtInCount(int count) => '$count built in';
  static String get customRoles => L10n.t('customRoles', 'Custom roles');
  static String get noneCreatedYet =>
      L10n.t('noneCreatedYet', 'None created yet');
  static String get createdForBusiness =>
      L10n.t('createdForBusiness', 'Created for this business');
  static String get staffAssigned => L10n.t('staffAssigned', 'Staff assigned');
  static String get acrossAllRoles =>
      L10n.t('acrossAllRoles', 'Across all roles');
  static String get editRoleAction => L10n.t('editRoleAction', 'Edit role');
  static String get duplicateAction => L10n.t('duplicateAction', 'Duplicate');
  static String get deleteRoleAction => L10n.t('deleteRoleAction', 'Delete');
  static String roleDuplicated(String name) => 'Created "$name"';
  static String deleteRoleTitle(String name) => 'Delete "$name"?';
  static String get deleteRoleBody => L10n.t(
    'deleteRoleBody',
    'This role is not assigned to anyone and will be removed permanently.',
  );
  static String roleDeleted(String name) => '"$name" deleted';
  static String get builtinCaption => L10n.t(
    'builtinCaption',
    'Built-in roles can be edited but not renamed or deleted.',
  );
  static String get roleColumn => L10n.t('roleColumn', 'Role');
  static String get staffColumn => L10n.t('staffColumn', 'Staff');
  static String get permissionsColumn =>
      L10n.t('permissionsColumn', 'Permissions');
  static String get typeColumn2 => L10n.t('typeColumn2', 'Type');
  static String get builtInBadge => L10n.t('builtInBadge', 'Built in');
  static String get customBadge => L10n.t('customBadge', 'Custom');
  static String get builtinLockedTooltip => L10n.t(
    'builtinLockedTooltip',
    'Built-in roles cannot be renamed or deleted',
  );

  // -------------------------------------------------------------------------
  // Settings hub
  // -------------------------------------------------------------------------

  static String get businessProfileEntry =>
      L10n.t('businessProfileEntry', 'Business profile');
  static String get businessProfileBlurb => L10n.t(
    'businessProfileBlurb',
    'Name, logo, brand colour and contact details',
  );
  static String get loadingEllipsis => L10n.t('loadingEllipsis', 'Loading...');
  static String get storeSettingsEntry =>
      L10n.t('storeSettingsEntry', 'Store settings');
  static String get storeSettingsBlurb =>
      L10n.t('storeSettingsBlurb', 'Tax, currency, receipts and trading hours');
  static String get taxInclusive => L10n.t('taxInclusive', 'inclusive');
  static String get taxOnTop => L10n.t('taxOnTop', 'on top');
  static String get storeLocationsEntry =>
      L10n.t('storeLocationsEntry', 'Store locations');
  static String get storeLocationsBlurb =>
      L10n.t('storeLocationsBlurb', 'Sites this business trades from');
  static String locationCount(int total) => '$total locations';
  static String locationsActive(int active, int total) =>
      '$active of $total active';
  static String get staffRolesEntry =>
      L10n.t('staffRolesEntry', 'Staff & roles');
  static String get staffRolesBlurb =>
      L10n.t('staffRolesBlurb', 'Who works here and what they can do');
  static String staffRolesValue(int staff, int roles) =>
      '$staff staff · $roles roles';
  static String get accountEntry => L10n.t('accountEntry', 'Account');
  static String get accountBlurb =>
      L10n.t('accountBlurb', 'Your own profile, PIN and sign-in security');
  static String get notSignedIn => L10n.t('notSignedIn', 'Not signed in');
  static String get appPrefsEntry => L10n.t('appPrefsEntry', 'App preferences');
  static String get appPrefsBlurb => L10n.t(
    'appPrefsBlurb',
    'Theme, notifications and table density on this device',
  );
  static String get themeSystem => L10n.t('themeSystem', 'System');
  static String get themeLight => L10n.t('themeLight', 'Light');
  static String get themeDark => L10n.t('themeDark', 'Dark');
  static String get devicesEntry =>
      L10n.t('devicesEntry', 'Devices & printers');
  static String get devicesBlurb =>
      L10n.t('devicesBlurb', 'Terminals, receipt printers and cash drawers');
  static String get notConfigured => L10n.t('notConfigured', 'Not configured');
  static String get settingsTitle => L10n.t('settingsTitle', 'Settings');
  static String get settingsSubtitle => L10n.t(
    'settingsSubtitle',
    'How this business and this terminal are configured',
  );
  static String get comingSoon => L10n.t('comingSoon', 'Coming soon');

  // -------------------------------------------------------------------------
  // Store settings
  // -------------------------------------------------------------------------

  static String get storeSettingsSaved =>
      L10n.t('storeSettingsSaved', 'Store settings saved');
  static String get storeSettingsTitle =>
      L10n.t('storeSettingsTitle', 'Store settings');
  static String get storeSettingsSubtitle => L10n.t(
    'storeSettingsSubtitle',
    'Tax, receipts and trading hours for this store',
  );
  static String get saveChangesAction =>
      L10n.t('saveChangesAction', 'Save changes');
  static String get taxPricingPanel =>
      L10n.t('taxPricingPanel', 'Tax & pricing');
  static String get taxRateField => L10n.t('taxRateField', 'Tax rate');
  static String get newTicketHelper =>
      L10n.t('newTicketHelper', 'Applied to every new ticket');
  static String get percentRangeError =>
      L10n.t('percentRangeError', 'Must be between 0 and 100');
  static String get serviceChargeField =>
      L10n.t('serviceChargeField', 'Service charge');
  static String get serviceChargeHelper =>
      L10n.t('serviceChargeHelper', 'Leave at 0 if not applied');
  static String get pricesIncludeTax =>
      L10n.t('pricesIncludeTax', 'Prices include tax');
  static String get taxInclusivePrices => L10n.t(
    'taxInclusivePrices',
    'Menu prices are tax-inclusive; receipts show the tax within',
  );
  static String get taxAddedAtCheckout =>
      L10n.t('taxAddedAtCheckout', 'Tax is added to the subtotal at checkout');
  static String get currencyField => L10n.t('currencyField', 'Currency');
  static String get currencyShownHelper =>
      L10n.t('currencyShownHelper', 'Formats every amount shown in the app');
  static String currencyPreview(String sample) => 'Prices will read as $sample';
  static String get orderReceiptPanel =>
      L10n.t('orderReceiptPanel', 'Order & receipt');
  static String get defaultOrderTypeField =>
      L10n.t('defaultOrderTypeField', 'Default order type');
  static String get preselectedPosHelper =>
      L10n.t('preselectedPosHelper', 'Pre-selected on the POS panel');
  static String get receiptPrefixField =>
      L10n.t('receiptPrefixField', 'Receipt number prefix');
  static String get receiptPrefixExample =>
      L10n.t('receiptPrefixExample', 'e.g. INV-1042');
  static String get receiptPrefixHint => L10n.t('receiptPrefixHint', 'INV-');
  static String get receiptPrefixLengthError =>
      L10n.t('receiptPrefixLengthError', 'Keep it under 8 characters');
  static String get receiptPrefixLength =>
      L10n.t('receiptPrefixLength', 'Keep it under 8 characters');
  static String get autoPrintReceipt =>
      L10n.t('autoPrintReceipt', 'Auto-print receipt');
  static String get autoPrintOn =>
      L10n.t('autoPrintOn', 'A receipt prints as soon as payment settles');
  static String get autoPrintOff =>
      L10n.t('autoPrintOff', 'Receipts print only when asked for');
  static String get operatingHours =>
      L10n.t('operatingHours', 'Operating hours');
  static String get opensAt => L10n.t('opensAt', 'Opens at');
  static String get closesAt => L10n.t('closesAt', 'Closes at');
  static String get openValue => L10n.t('openValue', 'Open');
  static String get closedValue => L10n.t('closedValue', 'Closed');
  static String get closesNextMorning =>
      L10n.t('closesNextMorning', 'Closes the next morning');
  static String get openEveryDay => L10n.t('openEveryDay', 'Open every day');
  static String get closedAllWeek => L10n.t('closedAllWeek', 'Closed all week');
  static String closedDays(String days) => 'Closed $days';
  static const weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const weekdayShortNames = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // -------------------------------------------------------------------------
  // Business profile
  // -------------------------------------------------------------------------

  static String get noProfileLoaded =>
      L10n.t('noProfileLoaded', 'No business profile loaded');
  static String get businessProfileSaved =>
      L10n.t('businessProfileSaved', 'Business profile saved');
  static String profileSaveFailed(Object e) => 'Error saving profile: $e';
  static String get businessProfileTitle =>
      L10n.t('businessProfileTitle', 'Business profile');
  static String get businessProfileSubtitle => L10n.t(
    'businessProfileSubtitle',
    'Identity and contact details synced with backend',
  );
  static String get savingEllipsis => L10n.t('savingEllipsis', 'Saving...');
  static String get brandingPanel => L10n.t('brandingPanel', 'Branding');
  static String get addLogoAction => L10n.t('addLogoAction', 'Add logo');
  static String get logoPreviewHint =>
      L10n.t('logoPreviewHint', 'Preview only — not yet saved');
  static String get logoReceiptHint =>
      L10n.t('logoReceiptHint', 'Square PNG or JPG reads best on a receipt');
  static String get accentColour => L10n.t('accentColour', 'Accent colour');
  static String get businessDetails =>
      L10n.t('businessDetails', 'Business details');
  static String get businessNameField =>
      L10n.t('businessNameField', 'Business name');
  static String get businessNameHelper =>
      L10n.t('businessNameHelper', 'Displayed in the app and on receipts');
  static String get businessNameHint2 =>
      L10n.t('businessNameHint2', 'My Restaurant');
  static String get businessNameRequired =>
      L10n.t('businessNameRequired', 'Business name is required');
  static String get businessTypeField =>
      L10n.t('businessTypeField', 'Business type');
  static String get cuisineField => L10n.t('cuisineField', 'Cuisine type');
  static String get optionalField => L10n.t('optionalField', 'Optional');
  static String get cuisineExample2 =>
      L10n.t('cuisineExample2', 'e.g., Italian, Thai');
  static String get registrationPanel =>
      L10n.t('registrationPanel', 'Registration & compliance');
  static String get taxIdField => L10n.t('taxIdField', 'Tax ID');
  static String get taxIdHelper2 => L10n.t('taxIdHelper2', 'VAT/GST number');
  static String get registrationField =>
      L10n.t('registrationField', 'Registration number');
  static String get registrationHelper =>
      L10n.t('registrationHelper', 'Business license / registration ID');
  static String get licenseDocField =>
      L10n.t('licenseDocField', 'License / registration document');
  static String get licenseDocHelper2 => L10n.t(
    'licenseDocHelper2',
    "Optional — paste a link to where it's hosted",
  );
  static String get contactPanel2 =>
      L10n.t('contactPanel2', 'Contact information');
  static String get emailField2 => L10n.t('emailField2', 'Email');
  static String get emailHelper2 =>
      L10n.t('emailHelper2', 'Business contact email');
  static String get emailHint2 => L10n.t('emailHint2', 'contact@business.com');
  static String get phoneField2 => L10n.t('phoneField2', 'Phone');
  static String get phoneHelper2 => L10n.t('phoneHelper2', 'Contact number');
  static String get phoneHint2 => L10n.t('phoneHint2', '+255 ...');
  static String get addressField2 => L10n.t('addressField2', 'Address');
  static String get addressHelper2 =>
      L10n.t('addressHelper2', 'Physical business address');
  static String get addressHint2 => L10n.t('addressHint2', 'Street address');
  static String get cityField => L10n.t('cityField', 'City');
  static String get cityHelper => L10n.t('cityHelper', 'City or locality');
  static String get cityExample => L10n.t('cityExample', 'e.g., Dar es Salaam');

  // -------------------------------------------------------------------------
  // Account
  // -------------------------------------------------------------------------

  static String get accountTitle => L10n.t('accountTitle', 'Account');
  static String get accountSubtitle =>
      L10n.t('accountSubtitle', 'Your own details and how you sign in');
  static String get profilePanel2 => L10n.t('profilePanel2', 'Profile');
  static String get photoUploadLabel => L10n.t('photoUploadLabel', 'Photo');

  // -------------------------------------------------------------------------
  // Locations
  // -------------------------------------------------------------------------

  static String locationSaved(String name, bool isEdit) => isEdit
      ? '$name updated'
      : '$name added — it can now receive stock transfers';
  static String get locationSaveFallback =>
      L10n.t('locationSaveFallback', 'Could not save location');
  static String locationSaveFailed(Object e) => 'Error saving location: $e';
  static String get editLocation => L10n.t('editLocation', 'Edit location');
  static String get addLocationTitle =>
      L10n.t('addLocationTitle', 'Add location');
  static String get saveLocation => L10n.t('saveLocation', 'Save location');
  static String get locationNameField =>
      L10n.t('locationNameField', 'Location name');
  static String get locationNameExample =>
      L10n.t('locationNameExample', 'Harbour Point');
  static String get locationNameRequired =>
      L10n.t('locationNameRequired', 'Give the location a name');
  static String get locationNameTaken =>
      L10n.t('locationNameTaken', 'That name is already used');
  static String get locationTypeField =>
      L10n.t('locationTypeField', 'Location type');
  static String get addressField3 => L10n.t('addressField3', 'Address');
  static String get addressExample3 =>
      L10n.t('addressExample3', '12 Pier Road, San Francisco');
  static String get phoneField4 => L10n.t('phoneField4', 'Phone');
  static String get phoneExample4 => L10n.t('phoneExample4', '+1 415 555 0142');
  static String get staffBasedHere =>
      L10n.t('staffBasedHere', 'Staff based here');
  static String get staffCountHint => L10n.t('staffCountHint', '0');
  static String get managerField => L10n.t('managerField', 'Manager');
  static String get managerHelper =>
      L10n.t('managerHelper', 'Anyone on the staff list can run a site');
  static String get activeSwitch => L10n.t('activeSwitch', 'Active');
  static String get currentTerminalTrades => L10n.t(
    'currentTerminalTrades',
    'This terminal is installed here, so it always trades',
  );
  static String get tradingTransferDest => L10n.t(
    'tradingTransferDest',
    'Trading, and offered as a stock transfer destination',
  );
  static String get keptForHistory =>
      L10n.t('keptForHistory', 'Kept for history; offered nowhere');
  static String get oneActiveRequired =>
      L10n.t('oneActiveRequired', 'At least one location has to stay active');
  static String managerPending(String name) => '$name (invite pending)';
  static String get unassignedManager =>
      L10n.t('unassignedManager', 'Unassigned');
  static String get storeLocationsTitle =>
      L10n.t('storeLocationsTitle', 'Store locations');
  static String get storeLocationsSubtitle => L10n.t(
    'storeLocationsSubtitle',
    'Sites this business trades from and moves stock between',
  );
  static String get backToSettings =>
      L10n.t('backToSettings', 'Back to settings');
  static String get addLocationAction =>
      L10n.t('addLocationAction', 'Add location');
  static String get totalLocations =>
      L10n.t('totalLocations', 'Total locations');
  static String get singleSite => L10n.t('singleSite', 'Single site');
  static String get acrossBusiness =>
      L10n.t('acrossBusiness', 'Across the business');
  static String get activeLocations =>
      L10n.t('activeLocations', 'Active locations');
  static String get allTrading => L10n.t('allTrading', 'All trading');
  static String inactiveLocations(int count) => '$count inactive';
  static String get totalStaffMetric =>
      L10n.t('totalStaffMetric', 'Total staff');
  static String get basedAllSites =>
      L10n.t('basedAllSites', 'Based across all sites');
  static String get editLocationAction =>
      L10n.t('editLocationAction', 'Edit location');
  static String get toggleActiveAction =>
      L10n.t('toggleActiveAction', 'Activate / deactivate');
  static String locationToggled(String name, bool wasActive) =>
      '$name ${wasActive ? 'deactivated' : 'reactivated'}';
  static String get deleteLocationAction =>
      L10n.t('deleteLocationAction', 'Delete');
  static String deleteLocationTitle(String name) => 'Delete "$name"?';
  static String get deleteLocationEmpty => L10n.t(
    'deleteLocationEmpty',
    'Stock movements recorded against this site keep their history, '
        'but it will no longer be offered as a transfer destination.',
  );
  static String deleteLocationStaffed(int count) =>
      '$count people are based here. They will keep their records, but '
      'the site will no longer be offered as a transfer destination.';
  static String locationDeleted(String name) => '"$name" deleted';

  // -------------------------------------------------------------------------
  // Store Details
  // -------------------------------------------------------------------------

  static String get storeDetailsTitle =>
      L10n.t('storeDetailsTitle', 'Store Details');
  static String get storeDetailsSaved =>
      L10n.t('storeDetailsSaved', 'Store settings saved');
  static String get failedToSaveSettings =>
      L10n.t('failedToSaveSettings', 'Failed to save settings');
  static String get storeLocationSection =>
      L10n.t('storeLocationSection', 'Location');
  static String get latitudeLabel => L10n.t('latitudeLabel', 'Latitude');
  static String get longitudeLabel => L10n.t('longitudeLabel', 'Longitude');
  static String get storeContactSection =>
      L10n.t('storeContactSection', 'Contact');
  static String get storeEmailLabel => L10n.t('storeEmailLabel', 'Email');
  static String get storePhoneLabel => L10n.t('storePhoneLabel', 'Phone');
  static String get storeSalesChannelsSection =>
      L10n.t('storeSalesChannelsSection', 'Sales Channels');
  static String get storePricingSection =>
      L10n.t('storePricingSection', 'Pricing');
  static String get storeCurrencyLabel =>
      L10n.t('storeCurrencyLabel', 'Currency');
  static String get tzShilling =>
      L10n.t('tzShilling', 'TZS - Tanzanian Shilling');
  static String get usDollar => L10n.t('usDollar', 'USD - US Dollar');
  static String get euroLabel => L10n.t('euroLabel', 'EUR - Euro');
  static String get storeCreditTabsSection =>
      L10n.t('storeCreditTabsSection', 'Credit & Tabs');
  static String get creditLimitLabel =>
      L10n.t('creditLimitLabel', 'Credit limit');
  static String get maxPaymentTimeLabel =>
      L10n.t('maxPaymentTimeLabel', 'Max payment time (min)');
  static String get storeOperationalSection =>
      L10n.t('storeOperationalSection', 'Operational');
  static String get storeLogoSection => L10n.t('storeLogoSection', 'Logo');
  static String get logoUrlLabel => L10n.t('logoUrlLabel', 'Logo URL');
  static String get storeHoursReceiptsSection =>
      L10n.t('storeHoursReceiptsSection', 'Hours & Receipts');
  static String get hoursOfOperation =>
      L10n.t('hoursOfOperation', 'Hours of Operation');
  static String get receiptSettings =>
      L10n.t('receiptSettings', 'Receipt Settings');
  static String get addStaffComingSoon =>
      L10n.t('addStaffComingSoon', 'Add staff coming soon');
  static String get lastActiveNoDelete => L10n.t(
    'lastActiveNoDelete',
    'The last active location cannot be deleted',
  );
  static String get lastActiveLocked => L10n.t(
    'lastActiveLocked',
    'The last active location cannot be deactivated or deleted.',
  );
  static String terminalHereLocked(String name) =>
      'This terminal is installed at $name. The last active location '
      'cannot be deactivated or deleted.';
  static String get locationColumn => L10n.t('locationColumn', 'Location');
  static String get addressColumn => L10n.t('addressColumn', 'Address');
  static String get managerColumn => L10n.t('managerColumn', 'Manager');
  static String get locationStaffColumn =>
      L10n.t('locationStaffColumn', 'Staff');
  static String get activeValue => L10n.t('activeValue', 'Active');
  static String get inactiveValue => L10n.t('inactiveValue', 'Inactive');
  static String get thisStoreMarker => L10n.t('thisStoreMarker', 'This store');
  static String get switchStoreAction =>
      L10n.t('switchStoreAction', 'Switch to this store');
  static String switchToStoreTitle(String name) => 'Switch to $name?';
  static String get switchPreflightCart => L10n.t(
    'switchPreflightCart',
    'The open ticket stays behind — it belongs to this store.',
  );
  static String switchPreflightPending(int count) =>
      '$count sale${count == 1 ? '' : 's'} not yet synced from this store.';
  static String get switchPreflightClean => L10n.t(
    'switchPreflightClean',
    'Everything from this store is synced. The new store loads fresh.',
  );
  static String get switchDiscardTitle =>
      L10n.t('switchDiscardTitle', 'Discard the open ticket?');
  static String get switchDiscardBody => L10n.t(
    'switchDiscardBody',
    'A ticket cannot move between stores. Switching throws it away.',
  );
  static String get discardAndSwitch =>
      L10n.t('discardAndSwitch', 'Discard & switch');
  static String get stayHere => L10n.t('stayHere', 'Stay here');
  static String get switchUnsyncedTitle =>
      L10n.t('switchUnsyncedTitle', 'Sales not yet synced');
  static String switchUnsyncedBody(int count) =>
      '$count sale${count == 1 ? '' : 's'} from this store ${count == 1 ? 'has' : 'have'} not reached the server. '
      'Switch anyway and they stay queued for this store, or stay and sync first.';
  static String get switchAnyway => L10n.t('switchAnyway', 'Switch anyway');
  static String get stayAndSync => L10n.t('stayAndSync', 'Stay & sync');
  static String switchingTo(String name) => 'Switching to $name…';
  static String switchedTo(String name) => 'Now trading as $name';
  static String switchFailed(String detail) =>
      'Could not switch store: $detail';
  static String get switchTimedOut => L10n.t(
    'switchTimedOut',
    'Taking too long — check the connection and try again.',
  );
  static String get tokenPendingBanner => L10n.t(
    'tokenPendingBanner',
    'Offline switch — store token not refreshed yet. Showing cached data.',
  );
  static String get tokenRetryAction => L10n.t('tokenRetryAction', 'Retry');
  static String get storeTokenRefreshed => L10n.t(
    'storeTokenRefreshed',
    'Store token refreshed — this terminal is fully online.',
  );

  // -------------------------------------------------------------------------
  // App preferences
  // -------------------------------------------------------------------------

  static String get appPreferencesTitle =>
      L10n.t('appPreferencesTitle', 'App preferences');
  static String get appPreferencesSubtitle => L10n.t(
    'appPreferencesSubtitle',
    'How this app looks and behaves on this device',
  );
  static String get appearancePanel => L10n.t('appearancePanel', 'Appearance');
  static String get followingDeviceTheme => L10n.t(
    'followingDeviceTheme',
    "Following this device's light/dark setting",
  );
  static String get alwaysLight =>
      L10n.t('alwaysLight', 'Always light, whatever the device is set to');
  static String get alwaysDark =>
      L10n.t('alwaysDark', 'Always dark, whatever the device is set to');
  static String get notificationsPanel =>
      L10n.t('notificationsPanel', 'Notifications');
  static String get lowStockAlerts =>
      L10n.t('lowStockAlerts', 'Low stock alerts');
  static String get lowStockAlertsHelper => L10n.t(
    'lowStockAlertsHelper',
    'Warn when a line drops below its reorder level',
  );
  static String get newOrderSounds =>
      L10n.t('newOrderSounds', 'New order sounds');
  static String get newOrderSoundsHelper => L10n.t(
    'newOrderSoundsHelper',
    'Chime when a ticket lands at this terminal',
  );
  static String get dailySummaryEmail =>
      L10n.t('dailySummaryEmail', 'Daily summary email');
  static String get dailySummaryHelper =>
      L10n.t('dailySummaryHelper', "Yesterday's takings, sent each morning");
  static String get displayPanel => L10n.t('displayPanel', 'Display');
  static String get tableDensityLabel =>
      L10n.t('tableDensityLabel', 'Table density');
  static String get languageField => L10n.t('languageField', 'Language');
  static String get moreLanguages =>
      L10n.t('moreLanguages', 'More languages are on the way');
  static String get accountPanel2 => L10n.t('accountPanel2', 'Account');
  static String get logOut => L10n.t('logOut', 'Log out');
  static String get logOutTitle => L10n.t('logOutTitle', 'Log out?');
  static String get logOutGeneric => L10n.t(
    'logOutGeneric',
    'You will need to sign in again to use this terminal.',
  );
  static String logOutNamed(String name) =>
      '$name will be signed out of this terminal. Any open ticket '
      'stays on the till.';
  static String get staySignedIn => L10n.t('staySignedIn', 'Stay signed in');
  static String get signOutPending => L10n.t(
    'signOutPending',
    'Sign-out takes effect once accounts are connected',
  );
  static String get fullNameField => L10n.t('fullNameField', 'Full name');
  static String get emailField3 => L10n.t('emailField3', 'Email');
  static String get phoneField3 => L10n.t('phoneField3', 'Phone');
  static String get profilePhotoSheet =>
      L10n.t('profilePhotoSheet', 'Profile photo');
  static String get choosePhoto => L10n.t('choosePhoto', 'Choose a photo');
  static String get securityPanel => L10n.t('securityPanel', 'Security');
  static String get unlockPin => L10n.t('unlockPin', 'Unlock PIN');
  static String get pinSetHint =>
      L10n.t('pinSetHint', 'Six digits, used to unlock this terminal');
  static String get noPinYet => L10n.t('noPinYet', 'No PIN set yet');
  static String get changePin => L10n.t('changePin', 'Change PIN');
  static String get setPinAction => L10n.t('setPinAction', 'Set PIN');
  static String get twoFactorOtp =>
      L10n.t('twoFactorOtp', 'Two-factor via OTP');
  static String get twoFactorOn =>
      L10n.t('twoFactorOn', 'A code is texted to you on top of your PIN');
  static String get twoFactorOff =>
      L10n.t('twoFactorOff', 'Your PIN alone unlocks this terminal');
  static String get dangerZone => L10n.t('dangerZone', 'DANGER ZONE');
  static String get deactivateExplainer => L10n.t(
    'deactivateExplainer',
    'Deactivating closes your own access to this business. It is not '
        'the same as an owner deactivating someone else from the Staff '
        'screen — only you can do this to your own account, and you will '
        'need an owner to let you back in.',
  );
  static String get deactivateAccount =>
      L10n.t('deactivateAccount', 'Deactivate my account');
  static String get deactivateTitle =>
      L10n.t('deactivateTitle', 'Deactivate your account?');
  static String deactivateBody(String name) =>
      '$name will lose access to this business immediately and be signed '
      'out of every terminal. Sales already recorded stay on the ledger. '
      'Only an owner can reactivate the account.';
  static String get yourAccountFallback =>
      L10n.t('yourAccountFallback', 'your account');
  static String get keepMyAccount => L10n.t('keepMyAccount', 'Keep my account');
  static String get deactivateConfirm =>
      L10n.t('deactivateConfirm', 'Deactivate');

  // -------------------------------------------------------------------------
  // Reports
  // -------------------------------------------------------------------------

  static String get reportsTitle => L10n.t('reportsTitle', 'Reports');
  static String get dateColumn => L10n.t('dateColumn', 'Date');
  static String get revenueColumn => L10n.t('revenueColumn', 'Revenue');
  static String get avgTicketColumn => L10n.t('avgTicketColumn', 'Avg ticket');
  static String get revenueMetric => L10n.t('revenueMetric', 'Revenue');
  static String ordersTrend(int count) => '$count orders';
  static String get avgTicketMetric => L10n.t('avgTicketMetric', 'Avg ticket');
  static String get perOrderTrend => L10n.t('perOrderTrend', 'Per order');
  static String get dailyTakingsSection =>
      L10n.t('dailyTakingsSection', 'Daily takings');
  static String get noSalesInWindow =>
      L10n.t('noSalesInWindow', 'No sales in this window');
  static String takingsRow(String money, int orders) =>
      '$money · $orders orders';
  static String get qtyColumn => L10n.t('qtyColumn', 'Qty');
  static String get itemMixSection => L10n.t('itemMixSection', 'Item mix');
  static String get nothingSold =>
      L10n.t('nothingSold', 'Nothing sold in this window');
  static String itemMixRow(String quantity, String money) =>
      '$quantity · $money';
  static String get salesColumn => L10n.t('salesColumn', 'Sales');
  static String get voidRefundColumn =>
      L10n.t('voidRefundColumn', 'Void/refund');
  static String get staffPerformanceSection =>
      L10n.t('staffPerformanceSection', 'Staff performance');
  static String get noStaffSales =>
      L10n.t('noStaffSales', 'No staff sales in this window');
  static String staffRow(int sales, String money) => '$sales sales · $money';
  static String get netMetric => L10n.t('netMetric', 'Net');
  static String get netTrend => L10n.t('netTrend', 'Sales + income − expenses');
  static String get expensesMetric => L10n.t('expensesMetric', 'Expenses');
  static String get adhocSpend => L10n.t('adhocSpend', 'Ad-hoc spend');
  static String get spendByCategory =>
      L10n.t('spendByCategory', 'Spend by category');
  static String get noExpenses =>
      L10n.t('noExpenses', 'No expenses in this window');
  static String get wastedColumn => L10n.t('wastedColumn', 'Wasted');
  static String get costColumn => L10n.t('costColumn', 'Cost');
  static String get wasteSection => L10n.t('wasteSection', 'Waste');
  static String get noWaste =>
      L10n.t('noWaste', 'No waste recorded in this window');
  static String costWasted(String money) => 'Cost wasted: $money';
  static String wasteRow(String quantity, String unit, String money) =>
      '$quantity $unit · $money';
  static String consumedRow(String quantity, String unit) => '$quantity $unit';
  static String overPortionedValue(double over, String formatted) =>
      '${over > 0 ? '+' : ''}$formatted';
  static String get ingredientColumn =>
      L10n.t('ingredientColumn', 'Ingredient');
  static String get consumedColumn => L10n.t('consumedColumn', 'Consumed');
  static String get productionRunsTrend =>
      L10n.t('productionRunsTrend', 'Production runs');
  static String get overPortioned => L10n.t('overPortioned', 'Over-portioned');
  static String get actualVsSuggested =>
      L10n.t('actualVsSuggested', 'Actual vs suggested');
  static String get ingredientsConsumed =>
      L10n.t('ingredientsConsumed', 'Ingredients consumed');
  static String get noProduction =>
      L10n.t('noProduction', 'No production in this window');
  static String get linesColumn => L10n.t('linesColumn', 'Lines');
  static String get valueColumn => L10n.t('valueColumn', 'Value');
  static String get uncategorized => L10n.t('uncategorized', 'Uncategorized');
  static String get inventoryValueMetric =>
      L10n.t('inventoryValueMetric', 'Inventory value');
  static String get onHandAtCost =>
      L10n.t('onHandAtCost', 'On hand at cost, right now');
  static String get valueByCategory =>
      L10n.t('valueByCategory', 'Value by category');
  static String get inventoryValuation =>
      L10n.t('inventoryValuation', 'Inventory valuation');
  static String get nothingOnHand => L10n.t('nothingOnHand', 'Nothing on hand');
  static String valuationRow(int lines, String money) =>
      '$lines lines · $money';

  // -------------------------------------------------------------------------
  // Validators
  // -------------------------------------------------------------------------

  static String get tanzanianPhoneError => L10n.t(
    'tanzanianPhoneError',
    'Enter a valid Tanzanian phone number (6 or 7XXXXXXXX)',
  );
  static String get giveItemName =>
      L10n.t('giveItemName', 'Give the item a name');
  static String get pickCategory => L10n.t('pickCategory', 'Pick a category');
  static String get enterUnitCost =>
      L10n.t('enterUnitCost', 'Enter a unit cost');
  static String get enterNumberError =>
      L10n.t('enterNumberError', 'Enter a number');
  static String get negativeCost =>
      L10n.t('negativeCost', 'Cost cannot be negative');
  static String get negativeNumber =>
      L10n.t('negativeNumber', 'Cannot be negative');
  static String get sellingPriceRequired => L10n.t(
    'sellingPriceRequired',
    'Enter a selling price to sell this at the till',
  );
  static String get describeExpense =>
      L10n.t('describeExpense', 'Describe the expense');
  static String get describeIncome =>
      L10n.t('describeIncome', 'Describe the income');
  static String get enterAmount => L10n.t('enterAmount', 'Enter an amount');
  static String get amountPositiveError =>
      L10n.t('amountPositiveError', 'Amount must be greater than zero');
}
