/// Request/response models for the Identity Service auth endpoints.
///
/// Decoupled from backend schemas so the app can evolve independently.
/// All shapes verified against the live identity-service backend.
library;

/// Request body for POST /auth/otp/request.
class OtpRequestInput {
  final String phone;

  OtpRequestInput({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

/// Request body for POST /auth/otp/verify.
class OtpVerifyInput {
  final String phone;
  final String code;

  OtpVerifyInput({
    required this.phone,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'code': code,
      };
}

/// Response from POST /auth/otp/verify, POST /auth/refresh, POST /auth/context/switch.
/// All three endpoints return the same shape (bearer tokens, no expiry/user_id in response).
/// Expiry and user_id are decoded from the JWT's `exp`/`sub` claims.
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}

/// Response from GET /users/me/onboarding-status.
class OnboardingStatusOutput {
  final bool needsOnboarding;
  final String? businessId;
  final String? businessName;
  final String fullName;
  final String? email;

  OnboardingStatusOutput({
    required this.needsOnboarding,
    this.businessId,
    this.businessName,
    this.fullName = '',
    this.email,
  });

  /// True when the account was created through the phone-first (OTP-only)
  /// path, which never asks for a name — /auth/register is the only path
  /// that populates it up front.
  bool get needsProfile => fullName.trim().isEmpty;

  factory OnboardingStatusOutput.fromJson(Map<String, dynamic> json) {
    return OnboardingStatusOutput(
      needsOnboarding: json['needs_onboarding'] as bool? ?? false,
      businessId: json['business_id'] as String?,
      businessName: json['business_name'] as String?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

/// Request body for PATCH /users/me.
class UpdateProfileInput {
  final String fullName;
  final String? email;

  UpdateProfileInput({required this.fullName, this.email});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'full_name': fullName};
    if (email != null) map['email'] = email;
    return map;
  }
}

/// Response from PATCH /users/me.
class UpdateProfileOutput {
  final String fullName;
  final String? email;

  UpdateProfileOutput({required this.fullName, this.email});

  factory UpdateProfileOutput.fromJson(Map<String, dynamic> json) {
    return UpdateProfileOutput(
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

/// Request body for POST /auth/context/switch.
class ContextSwitchInput {
  final String businessId;

  ContextSwitchInput({required this.businessId});

  Map<String, dynamic> toJson() => {'business_id': businessId};
}

/// Request body for POST /auth/context/switch-store.
class StoreSwitchInput {
  final String storeId;

  StoreSwitchInput({required this.storeId});

  Map<String, dynamic> toJson() => {'store_id': storeId};
}

/// Request body for POST /auth/refresh.
class TokenRefreshInput {
  final String refreshToken;

  TokenRefreshInput({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

/// Request body for POST /auth/logout.
class LogoutInput {
  final String refreshToken;

  LogoutInput({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

/// Request body for POST /api/v1/businesses (business creation / onboarding).
class BusinessCreateInput {
  final String name;
  final String businessType;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? countryCode;
  final String? timezone;
  final String? taxId;
  final String? registrationNumber;
  final String? cuisineType;
  final String? licenseDocumentUrl;

  BusinessCreateInput({
    required this.name,
    required this.businessType,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.countryCode,
    this.timezone,
    this.taxId,
    this.registrationNumber,
    this.cuisineType,
    this.licenseDocumentUrl,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'business_type': businessType,
    };
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (city != null) map['city'] = city;
    if (countryCode != null) map['country_code'] = countryCode;
    if (timezone != null) map['timezone'] = timezone;
    if (taxId != null && taxId!.isNotEmpty) map['tax_id'] = taxId;
    if (registrationNumber != null && registrationNumber!.isNotEmpty) {
      map['registration_number'] = registrationNumber;
    }
    if (cuisineType != null && cuisineType!.isNotEmpty) map['cuisine_type'] = cuisineType;
    if (licenseDocumentUrl != null && licenseDocumentUrl!.isNotEmpty) {
      map['license_document_url'] = licenseDocumentUrl;
    }
    return map;
  }
}

/// Request body for PATCH /api/v1/businesses/{id} (partial update).
/// Mirrors backend BusinessUpdate — every field optional; toJson() emits
/// only the fields that were actually set, so unset fields are left alone.
class BusinessUpdateInput {
  final String? name;
  final String? businessType;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? countryCode;
  final String? timezone;
  final String? taxId;
  final String? registrationNumber;
  final String? cuisineType;
  final String? logo;
  final String? licenseDocumentUrl;
  final String? status;

  BusinessUpdateInput({
    this.name,
    this.businessType,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.countryCode,
    this.timezone,
    this.taxId,
    this.registrationNumber,
    this.cuisineType,
    this.logo,
    this.licenseDocumentUrl,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (businessType != null) 'business_type': businessType,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (countryCode != null) 'country_code': countryCode,
        if (timezone != null) 'timezone': timezone,
        if (taxId != null) 'tax_id': taxId,
        if (registrationNumber != null) 'registration_number': registrationNumber,
        if (cuisineType != null) 'cuisine_type': cuisineType,
        if (logo != null) 'logo': logo,
        if (licenseDocumentUrl != null) 'license_document_url': licenseDocumentUrl,
        if (status != null) 'status': status,
      };
}

/// Full business data from GET /businesses/{id}.
class BusinessReadDto {
  final String id;
  final String name;
  final String businessType;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String countryCode;
  final String timezone;
  final String? taxId;
  final String? registrationNumber;
  final String? cuisineType;
  final String? logo;
  final String? licenseDocumentUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessReadDto({
    required this.id,
    required this.name,
    required this.businessType,
    this.email,
    this.phone,
    this.address,
    this.city,
    required this.countryCode,
    required this.timezone,
    this.taxId,
    this.registrationNumber,
    this.cuisineType,
    this.logo,
    this.licenseDocumentUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessReadDto.fromJson(Map<String, dynamic> json) {
    return BusinessReadDto(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: json['business_type'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      countryCode: json['country_code'] as String? ?? 'TZ',
      timezone: json['timezone'] as String? ?? 'Africa/Dar_es_Salaam',
      taxId: json['tax_id'] as String?,
      registrationNumber: json['registration_number'] as String?,
      cuisineType: json['cuisine_type'] as String?,
      logo: json['logo'] as String?,
      licenseDocumentUrl: json['license_document_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Response from POST /api/v1/businesses.
/// The full response body has nested `business`, `roles_created`, `owner_role_name`, `note`.
/// We extract the key fields we need for app flow.
class BusinessCreateOutput {
  final String businessId;
  final String ownerRoleName;
  final BusinessReadDto business;

  BusinessCreateOutput({
    required this.businessId,
    required this.ownerRoleName,
    required this.business,
  });

  factory BusinessCreateOutput.fromJson(Map<String, dynamic> json) {
    final business = json['business'] as Map<String, dynamic>;
    return BusinessCreateOutput(
      businessId: business['id'] as String,
      ownerRoleName: json['owner_role_name'] as String? ?? 'Owner',
      business: BusinessReadDto.fromJson(business),
    );
  }
}

/// Full store data from GET /api/v1/businesses/{id}/stores/{store_id}.
class StoreReadDto {
  final String id;
  final String businessId;
  final String name;
  final String token;
  final String locationType;
  final String status;
  final String countryCode;
  final String? city;
  final String? address;
  final String timezone;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreReadDto({
    required this.id,
    required this.businessId,
    required this.name,
    required this.token,
    required this.locationType,
    required this.status,
    required this.countryCode,
    this.city,
    this.address,
    required this.timezone,
    required this.isPrimary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreReadDto.fromJson(Map<String, dynamic> json) {
    return StoreReadDto(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      token: json['token'] as String,
      locationType: json['location_type'] as String,
      status: json['status'] as String? ?? 'active',
      countryCode: json['country_code'] as String? ?? 'TZ',
      city: json['city'] as String?,
      address: json['address'] as String?,
      timezone: json['timezone'] as String? ?? 'Africa/Dar_es_Salaam',
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Store settings data from GET /api/v1/businesses/{id}/stores/{store_id}/settings.
class StoreSettingReadDto {
  final String id;
  final String storeId;
  final bool active;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? email;
  final String? phone;
  final String preferredCurrency;
  final double? amount;
  final int? maxPaymentTimeMinutes;
  final String? logo;
  final bool offerRetail;
  final bool offerWholesale;
  final bool displayPricesInclusiveOfTax;
  final bool taxEnabled;
  final double taxRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreSettingReadDto({
    required this.id,
    required this.storeId,
    required this.active,
    this.address,
    this.latitude,
    this.longitude,
    this.email,
    this.phone,
    required this.preferredCurrency,
    this.amount,
    this.maxPaymentTimeMinutes,
    this.logo,
    required this.offerRetail,
    required this.offerWholesale,
    required this.displayPricesInclusiveOfTax,
    this.taxEnabled = false,
    this.taxRate = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreSettingReadDto.fromJson(Map<String, dynamic> json) {
    return StoreSettingReadDto(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      active: json['active'] as bool? ?? true,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      preferredCurrency: json['preferred_currency'] as String? ?? 'TZS',
      amount: (json['amount'] as num?)?.toDouble(),
      maxPaymentTimeMinutes: json['max_payment_time_minutes'] as int?,
      logo: json['logo'] as String?,
      offerRetail: json['offer_retail'] as bool? ?? true,
      offerWholesale: json['offer_wholesale'] as bool? ?? false,
      displayPricesInclusiveOfTax: json['display_prices_inclusive_of_tax'] as bool? ?? false,
      taxEnabled: json['tax_enabled'] as bool? ?? false,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// One store returned from GET /api/v1/businesses/{id}/stores (list).
class StoreDto {
  final String id;
  final bool isPrimary;
  final String name;

  StoreDto({
    required this.id,
    required this.isPrimary,
    required this.name,
  });

  factory StoreDto.fromJson(Map<String, dynamic> json) {
    return StoreDto(
      id: json['id'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      name: json['name'] as String,
    );
  }
}
