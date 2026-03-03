class ParcelStopInput {
  final String addressLine1;
  final String city;
  final double latitude;
  final double longitude;
  final String contactName;
  final String contactPhone;
  final String? addressLine2;
  final String? state;
  final String? postalCode;
  final String? notes;

  const ParcelStopInput({
    required this.addressLine1,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.contactName,
    required this.contactPhone,
    this.addressLine2,
    this.state,
    this.postalCode,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'addressLine1': addressLine1,
    if (addressLine2 != null && addressLine2!.isNotEmpty)
      'addressLine2': addressLine2,
    'city': city,
    if (state != null && state!.isNotEmpty) 'state': state,
    if (postalCode != null && postalCode!.isNotEmpty) 'postalCode': postalCode,
    'latitude': latitude,
    'longitude': longitude,
    'contactName': contactName,
    'contactPhone': contactPhone,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

class ParcelQuoteRequest {
  final ParcelStopInput pickup;
  final ParcelStopInput dropoff;
  final double declaredValueGhs;
  final double weightKg;
  final String sizeTier;
  final String paymentMethod;
  final String scheduleType;
  final bool prohibitedItemsAccepted;
  final bool containsHazardous;
  final bool containsLiquid;
  final bool isPerishable;
  final bool isFragile;
  final String? packageCategory;
  final String? packageDescription;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final String? notes;
  final DateTime? scheduledPickupAt;

  const ParcelQuoteRequest({
    required this.pickup,
    required this.dropoff,
    required this.declaredValueGhs,
    required this.weightKg,
    this.sizeTier = 'medium',
    this.paymentMethod = 'paystack',
    this.scheduleType = 'on_demand',
    this.prohibitedItemsAccepted = true,
    this.containsHazardous = false,
    this.containsLiquid = false,
    this.isPerishable = false,
    this.isFragile = false,
    this.packageCategory,
    this.packageDescription,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.notes,
    this.scheduledPickupAt,
  });

  Map<String, dynamic> toJson() => {
    'pickup': pickup.toJson(),
    'dropoff': dropoff.toJson(),
    'declaredValueGhs': declaredValueGhs,
    'weightKg': weightKg,
    'sizeTier': sizeTier,
    'paymentMethod': paymentMethod,
    'scheduleType': scheduleType,
    'prohibitedItemsAccepted': prohibitedItemsAccepted,
    'containsHazardous': containsHazardous,
    'containsLiquid': containsLiquid,
    'isPerishable': isPerishable,
    'isFragile': isFragile,
    if (packageCategory != null && packageCategory!.isNotEmpty)
      'packageCategory': packageCategory,
    if (packageDescription != null && packageDescription!.isNotEmpty)
      'packageDescription': packageDescription,
    if (lengthCm != null) 'lengthCm': lengthCm,
    if (widthCm != null) 'widthCm': widthCm,
    if (heightCm != null) 'heightCm': heightCm,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (scheduledPickupAt != null)
      'scheduledPickupAt': scheduledPickupAt!.toIso8601String(),
  };
}

class ParcelCreateOrderRequest extends ParcelQuoteRequest {
  final bool acceptParcelTerms;
  final String? termsVersion;

  const ParcelCreateOrderRequest({
    required super.pickup,
    required super.dropoff,
    required super.declaredValueGhs,
    required super.weightKg,
    super.sizeTier,
    super.paymentMethod,
    super.scheduleType,
    super.prohibitedItemsAccepted,
    super.containsHazardous,
    super.containsLiquid,
    super.isPerishable,
    super.isFragile,
    super.packageCategory,
    super.packageDescription,
    super.lengthCm,
    super.widthCm,
    super.heightCm,
    super.notes,
    super.scheduledPickupAt,
    this.acceptParcelTerms = true,
    this.termsVersion,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'acceptParcelTerms': acceptParcelTerms,
    if (termsVersion != null && termsVersion!.isNotEmpty)
      'termsVersion': termsVersion,
  };
}

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return fallback;
}

String _asString(dynamic value, [String fallback = '']) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return fallback;
  return text.trim();
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => _asString(e)).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

Map<String, String> _asStringMap(dynamic value) {
  if (value is Map) {
    final output = <String, String>{};
    for (final entry in value.entries) {
      final key = _asString(entry.key);
      final mapValue = _asString(entry.value);
      if (key.isNotEmpty && mapValue.isNotEmpty) {
        output[key] = mapValue;
      }
    }
    return output;
  }
  return const {};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}

class ParcelPaymentMethodsContract {
  final List<String> apiAccepted;
  final List<String> acceptedInputValues;
  final List<String> storageValues;
  final Map<String, String> aliases;
  final String onlinePaymentProvider;

  const ParcelPaymentMethodsContract({
    required this.apiAccepted,
    required this.acceptedInputValues,
    required this.storageValues,
    required this.aliases,
    required this.onlinePaymentProvider,
  });

  factory ParcelPaymentMethodsContract.fromJson(Map<String, dynamic> json) {
    return ParcelPaymentMethodsContract(
      apiAccepted: _asStringList(json['apiAccepted']),
      acceptedInputValues: _asStringList(json['acceptedInputValues']),
      storageValues: _asStringList(json['storageValues']),
      aliases: _asStringMap(json['aliases']),
      onlinePaymentProvider: _asString(
        json['onlinePaymentProvider'],
        'paystack',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'apiAccepted': apiAccepted,
    'acceptedInputValues': acceptedInputValues,
    'storageValues': storageValues,
    'aliases': aliases,
    'onlinePaymentProvider': onlinePaymentProvider,
  };
}

class ParcelConfigModel {
  final bool enabled;
  final bool scheduledEnabled;
  final bool returnToSenderEnabled;
  final bool insuranceEnabled;
  final bool noInsuranceEnabled;
  final double maxDeclaredValueGhs;
  final double liabilityCapGhs;
  final String liabilityFormula;
  final String liabilityDisclaimer;
  final String termsVersion;
  final int scheduleToleranceMinutes;
  final ParcelPaymentMethodsContract paymentMethods;

  const ParcelConfigModel({
    required this.enabled,
    required this.scheduledEnabled,
    required this.returnToSenderEnabled,
    required this.insuranceEnabled,
    required this.noInsuranceEnabled,
    required this.maxDeclaredValueGhs,
    required this.liabilityCapGhs,
    required this.liabilityFormula,
    required this.liabilityDisclaimer,
    required this.termsVersion,
    required this.scheduleToleranceMinutes,
    required this.paymentMethods,
  });

  factory ParcelConfigModel.fromJson(Map<String, dynamic> json) {
    return ParcelConfigModel(
      enabled: _asBool(json['enabled']),
      scheduledEnabled: _asBool(json['scheduledEnabled']),
      returnToSenderEnabled: _asBool(json['returnToSenderEnabled']),
      insuranceEnabled: _asBool(json['insuranceEnabled']),
      noInsuranceEnabled: _asBool(json['noInsuranceEnabled']),
      maxDeclaredValueGhs: _asDouble(json['maxDeclaredValueGhs']),
      liabilityCapGhs: _asDouble(json['liabilityCapGhs']),
      liabilityFormula: _asString(json['liabilityFormula']),
      liabilityDisclaimer: _asString(json['liabilityDisclaimer']),
      termsVersion: _asString(json['termsVersion'], 'parcel-v1'),
      scheduleToleranceMinutes: _asInt(json['scheduleToleranceMinutes']),
      paymentMethods: ParcelPaymentMethodsContract.fromJson(
        json['paymentMethods'] is Map<String, dynamic>
            ? json['paymentMethods'] as Map<String, dynamic>
            : const {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'scheduledEnabled': scheduledEnabled,
    'returnToSenderEnabled': returnToSenderEnabled,
    'insuranceEnabled': insuranceEnabled,
    'noInsuranceEnabled': noInsuranceEnabled,
    'maxDeclaredValueGhs': maxDeclaredValueGhs,
    'liabilityCapGhs': liabilityCapGhs,
    'liabilityFormula': liabilityFormula,
    'liabilityDisclaimer': liabilityDisclaimer,
    'termsVersion': termsVersion,
    'scheduleToleranceMinutes': scheduleToleranceMinutes,
    'paymentMethods': paymentMethods.toJson(),
  };
}

class ParcelQuoteBreakdown {
  final double baseFee;
  final double distanceFee;
  final double timeFee;
  final double sizeFee;
  final double weightFee;
  final double subtotal;

  const ParcelQuoteBreakdown({
    required this.baseFee,
    required this.distanceFee,
    required this.timeFee,
    required this.sizeFee,
    required this.weightFee,
    required this.subtotal,
  });

  factory ParcelQuoteBreakdown.fromJson(Map<String, dynamic> json) {
    return ParcelQuoteBreakdown(
      baseFee: _asDouble(json['baseFee']),
      distanceFee: _asDouble(json['distanceFee']),
      timeFee: _asDouble(json['timeFee']),
      sizeFee: _asDouble(json['sizeFee']),
      weightFee: _asDouble(json['weightFee']),
      subtotal: _asDouble(json['subtotal']),
    );
  }
}

class ParcelQuoteSummary {
  final double distanceKm;
  final int estimatedMinutes;
  final double subtotal;
  final double serviceFee;
  final double tax;
  final double total;
  final String currency;
  final ParcelQuoteBreakdown breakdown;

  const ParcelQuoteSummary({
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.subtotal,
    required this.serviceFee,
    required this.tax,
    required this.total,
    required this.currency,
    required this.breakdown,
  });

  factory ParcelQuoteSummary.fromJson(Map<String, dynamic> json) {
    return ParcelQuoteSummary(
      distanceKm: _asDouble(json['distanceKm']),
      estimatedMinutes: _asInt(json['estimatedMinutes']),
      subtotal: _asDouble(json['subtotal']),
      serviceFee: _asDouble(json['serviceFee']),
      tax: _asDouble(json['tax']),
      total: _asDouble(json['total']),
      currency: _asString(json['currency'], 'GHS'),
      breakdown: ParcelQuoteBreakdown.fromJson(
        json['breakdown'] is Map<String, dynamic>
            ? json['breakdown'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}

class ParcelReturnPolicyModel {
  final bool customerChargeEnabled;
  final double returnTripFeeEstimate;

  const ParcelReturnPolicyModel({
    required this.customerChargeEnabled,
    required this.returnTripFeeEstimate,
  });

  factory ParcelReturnPolicyModel.fromJson(Map<String, dynamic> json) {
    return ParcelReturnPolicyModel(
      customerChargeEnabled: _asBool(json['customerChargeEnabled']),
      returnTripFeeEstimate: _asDouble(json['returnTripFeeEstimate']),
    );
  }
}

class ParcelRiderEarningsModel {
  final double originalTripEarning;
  final double returnTripEarning;
  final double totalPotentialEarning;

  const ParcelRiderEarningsModel({
    required this.originalTripEarning,
    required this.returnTripEarning,
    required this.totalPotentialEarning,
  });

  factory ParcelRiderEarningsModel.fromJson(Map<String, dynamic> json) {
    return ParcelRiderEarningsModel(
      originalTripEarning: _asDouble(json['originalTripEarning']),
      returnTripEarning: _asDouble(json['returnTripEarning']),
      totalPotentialEarning: _asDouble(json['totalPotentialEarning']),
    );
  }
}

class ParcelPolicySnapshot {
  final double maxDeclaredValueGhs;
  final double liabilityCapGhs;
  final String liabilityFormula;
  final String liabilityDisclaimer;
  final bool insuranceEnabled;
  final bool noInsuranceEnabled;
  final String termsVersion;

  const ParcelPolicySnapshot({
    required this.maxDeclaredValueGhs,
    required this.liabilityCapGhs,
    required this.liabilityFormula,
    required this.liabilityDisclaimer,
    required this.insuranceEnabled,
    required this.noInsuranceEnabled,
    required this.termsVersion,
  });

  factory ParcelPolicySnapshot.fromJson(Map<String, dynamic> json) {
    return ParcelPolicySnapshot(
      maxDeclaredValueGhs: _asDouble(json['maxDeclaredValueGhs']),
      liabilityCapGhs: _asDouble(json['liabilityCapGhs']),
      liabilityFormula: _asString(json['liabilityFormula']),
      liabilityDisclaimer: _asString(json['liabilityDisclaimer']),
      insuranceEnabled: _asBool(json['insuranceEnabled']),
      noInsuranceEnabled: _asBool(json['noInsuranceEnabled']),
      termsVersion: _asString(json['termsVersion'], 'parcel-v1'),
    );
  }
}

class ParcelQuoteResponseModel {
  final ParcelQuoteSummary quote;
  final ParcelReturnPolicyModel returnPolicy;
  final ParcelRiderEarningsModel riderEarnings;
  final ParcelPolicySnapshot policy;

  const ParcelQuoteResponseModel({
    required this.quote,
    required this.returnPolicy,
    required this.riderEarnings,
    required this.policy,
  });

  factory ParcelQuoteResponseModel.fromJson(Map<String, dynamic> json) {
    return ParcelQuoteResponseModel(
      quote: ParcelQuoteSummary.fromJson(
        json['quote'] is Map<String, dynamic>
            ? json['quote'] as Map<String, dynamic>
            : const {},
      ),
      returnPolicy: ParcelReturnPolicyModel.fromJson(
        json['returnPolicy'] is Map<String, dynamic>
            ? json['returnPolicy'] as Map<String, dynamic>
            : const {},
      ),
      riderEarnings: ParcelRiderEarningsModel.fromJson(
        json['riderEarnings'] is Map<String, dynamic>
            ? json['riderEarnings'] as Map<String, dynamic>
            : const {},
      ),
      policy: ParcelPolicySnapshot.fromJson(
        json['policy'] is Map<String, dynamic>
            ? json['policy'] as Map<String, dynamic>
            : const {},
      ),
    );
  }
}

class ParcelOrderSummary {
  final String id;
  final String parcelNumber;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final double totalAmount;
  final String currency;
  final DateTime? createdAt;

  const ParcelOrderSummary({
    required this.id,
    required this.parcelNumber,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.currency,
    this.paymentMethod,
    this.createdAt,
  });

  factory ParcelOrderSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final createdAtRaw = _asString(json['createdAt']);
    if (createdAtRaw.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw);
    }

    return ParcelOrderSummary(
      id: _asString(json['id']),
      parcelNumber: _asString(json['parcelNumber']),
      status: _asString(json['status']),
      paymentStatus: _asString(json['paymentStatus']),
      paymentMethod: _asString(json['paymentMethod']).isEmpty
          ? null
          : _asString(json['paymentMethod']),
      totalAmount: _asDouble(json['totalAmount']),
      currency: _asString(json['currency'], 'GHS'),
      createdAt: parsedCreatedAt,
    );
  }
}

class ParcelEventModel {
  final String id;
  final String eventType;
  final String? actorRole;
  final String? reason;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  const ParcelEventModel({
    required this.id,
    required this.eventType,
    required this.metadata,
    this.actorRole,
    this.reason,
    this.createdAt,
  });

  factory ParcelEventModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    final createdAtRaw = _asString(json['createdAt']);
    if (createdAtRaw.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw);
    }

    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};

    return ParcelEventModel(
      id: _asString(json['id']),
      eventType: _asString(json['eventType']),
      actorRole: _asString(json['actorRole']).isEmpty
          ? null
          : _asString(json['actorRole']),
      reason: _asString(json['reason']).isEmpty
          ? null
          : _asString(json['reason']),
      createdAt: parsedCreatedAt,
      metadata: metadata,
    );
  }
}

class ParcelOrderDetailModel {
  final String id;
  final String parcelNumber;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? paymentProvider;
  final String? paymentReferenceId;
  final double totalAmount;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String scheduleType;
  final DateTime? scheduledPickupAt;
  final String pickupAddressLine1;
  final String dropoffAddressLine1;
  final String senderName;
  final String senderPhone;
  final String recipientName;
  final String recipientPhone;
  final double declaredValueGhs;
  final double weightKg;
  final String sizeTier;
  final String packageCategory;
  final String? packageDescription;
  final String? notes;
  final String? cancelReason;
  final double returnChargeAmount;
  final String returnChargeStatus;
  final double originalTripEarning;
  final double returnTripEarning;
  final double totalRiderEarning;
  final List<ParcelEventModel> events;

  const ParcelOrderDetailModel({
    required this.id,
    required this.parcelNumber,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.currency,
    required this.scheduleType,
    required this.pickupAddressLine1,
    required this.dropoffAddressLine1,
    required this.senderName,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientPhone,
    required this.declaredValueGhs,
    required this.weightKg,
    required this.sizeTier,
    required this.packageCategory,
    required this.returnChargeAmount,
    required this.returnChargeStatus,
    required this.originalTripEarning,
    required this.returnTripEarning,
    required this.totalRiderEarning,
    required this.events,
    this.paymentMethod,
    this.paymentProvider,
    this.paymentReferenceId,
    this.createdAt,
    this.updatedAt,
    this.scheduledPickupAt,
    this.packageDescription,
    this.notes,
    this.cancelReason,
  });

  factory ParcelOrderDetailModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedAt;
    DateTime? parsedUpdatedAt;
    DateTime? parsedScheduledPickupAt;

    final createdAtRaw = _asString(json['createdAt']);
    final updatedAtRaw = _asString(json['updatedAt']);
    final scheduledPickupAtRaw = _asString(json['scheduledPickupAt']);

    if (createdAtRaw.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw);
    }
    if (updatedAtRaw.isNotEmpty) {
      parsedUpdatedAt = DateTime.tryParse(updatedAtRaw);
    }
    if (scheduledPickupAtRaw.isNotEmpty) {
      parsedScheduledPickupAt = DateTime.tryParse(scheduledPickupAtRaw);
    }

    return ParcelOrderDetailModel(
      id: _asString(json['id']),
      parcelNumber: _asString(json['parcelNumber']),
      status: _asString(json['status']),
      paymentStatus: _asString(json['paymentStatus']),
      paymentMethod: _asString(json['paymentMethod']).isEmpty
          ? null
          : _asString(json['paymentMethod']),
      paymentProvider: _asString(json['paymentProvider']).isEmpty
          ? null
          : _asString(json['paymentProvider']),
      paymentReferenceId: _asString(json['paymentReferenceId']).isEmpty
          ? null
          : _asString(json['paymentReferenceId']),
      totalAmount: _asDouble(json['totalAmount']),
      currency: _asString(json['currency'], 'GHS'),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      scheduleType: _asString(json['scheduleType'], 'on_demand'),
      scheduledPickupAt: parsedScheduledPickupAt,
      pickupAddressLine1: _asString(json['pickupAddressLine1']),
      dropoffAddressLine1: _asString(json['dropoffAddressLine1']),
      senderName: _asString(json['senderName']),
      senderPhone: _asString(json['senderPhone']),
      recipientName: _asString(json['recipientName']),
      recipientPhone: _asString(json['recipientPhone']),
      declaredValueGhs: _asDouble(json['declaredValueGhs']),
      weightKg: _asDouble(json['weightKg']),
      sizeTier: _asString(json['sizeTier']),
      packageCategory: _asString(json['packageCategory']),
      packageDescription: _asString(json['packageDescription']).isEmpty
          ? null
          : _asString(json['packageDescription']),
      notes: _asString(json['notes']).isEmpty ? null : _asString(json['notes']),
      cancelReason: _asString(json['cancelReason']).isEmpty
          ? null
          : _asString(json['cancelReason']),
      returnChargeAmount: _asDouble(json['returnChargeAmount']),
      returnChargeStatus: _asString(json['returnChargeStatus']),
      originalTripEarning: _asDouble(json['originalTripEarning']),
      returnTripEarning: _asDouble(json['returnTripEarning']),
      totalRiderEarning: _asDouble(json['totalRiderEarning']),
      events: _asMapList(
        json['events'],
      ).map(ParcelEventModel.fromJson).toList(),
    );
  }

  ParcelOrderSummary toSummary() {
    return ParcelOrderSummary(
      id: id,
      parcelNumber: parcelNumber,
      status: status,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      currency: currency,
      createdAt: createdAt,
    );
  }
}

class ParcelPaymentInitialization {
  final String authorizationUrl;
  final String reference;
  final String? accessCode;
  final double paymentAmount;

  const ParcelPaymentInitialization({
    required this.authorizationUrl,
    required this.reference,
    required this.paymentAmount,
    this.accessCode,
  });

  factory ParcelPaymentInitialization.fromJson(Map<String, dynamic> json) {
    return ParcelPaymentInitialization(
      authorizationUrl: _asString(json['authorizationUrl']),
      reference: _asString(json['reference']),
      accessCode: _asString(json['accessCode']).isEmpty
          ? null
          : _asString(json['accessCode']),
      paymentAmount: _asDouble(json['paymentAmount']),
    );
  }
}

class ParcelPaymentConfirmation {
  final bool alreadyPaid;
  final String parcelId;
  final String status;
  final String paymentStatus;

  const ParcelPaymentConfirmation({
    required this.alreadyPaid,
    required this.parcelId,
    required this.status,
    required this.paymentStatus,
  });

  factory ParcelPaymentConfirmation.fromJson(Map<String, dynamic> json) {
    return ParcelPaymentConfirmation(
      alreadyPaid: _asBool(json['alreadyPaid']),
      parcelId: _asString(json['parcelId']),
      status: _asString(json['status']),
      paymentStatus: _asString(json['paymentStatus']),
    );
  }
}
