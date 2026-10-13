import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';

enum CourierStatus {
  active('activeStatus', 'Active', 'courierAvailable', 'Available for deliveries'),
  inactive('inactiveStatus', 'Inactive', 'courierUnavailable', 'Not available');

  const CourierStatus(
    this.labelKey,
    this.labelDefault,
    this.subtitleKey,
    this.subtitleDefault,
  );
  final String labelKey;
  final String labelDefault;
  final String subtitleKey;
  final String subtitleDefault;

  String get label => L10n.t(labelKey, labelDefault);
  String get subtitle => L10n.t(subtitleKey, subtitleDefault);
}

/// A delivery courier/driver.
@immutable
class Courier {
  const Courier({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.status,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicle;
  final CourierStatus status;

  Courier copyWith({
    String? name,
    String? phone,
    String? vehicle,
    CourierStatus? status,
  }) {
    return Courier(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicle: vehicle ?? this.vehicle,
      status: status ?? this.status,
    );
  }

  /// Maps POS Service `GET /couriers` (`is_active` bool) onto the local
  /// [CourierStatus] enum. `vehicle` is nullable server-side; an absent
  /// value renders as an empty string locally and is sent back as null.
  factory Courier.fromJson(Map<String, dynamic> json) {
    final isActive = json['is_active'] as bool? ?? true;
    final vehicle = json['vehicle'] as String?;
    return Courier(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      vehicle: vehicle ?? '',
      status: isActive ? CourierStatus.active : CourierStatus.inactive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Courier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
