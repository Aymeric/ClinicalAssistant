import 'health_record.dart';

/// Represents structured financial and health plan coverage metadata parsed from
/// an HL7 FHIR Coverage resource or Apple Health Clinical Records coverageRecord.
class CoverageDetails {
  const CoverageDetails({
    required this.payorName,
    this.subscriberId,
    this.beneficiaryName,
    this.relationship,
    this.groupNumber,
    this.groupName,
    this.planNumber,
    this.planName,
    this.planType,
    this.coverageType,
    this.status,
    this.periodStart,
    this.periodEnd,
    this.copays = const [],
    this.network,
  });

  /// Name of the payer organization or underwriting insurer (e.g., 'Blue Cross Blue Shield').
  final String payorName;

  /// Unique subscriber or policyholder identifier (e.g., 'SUB12345678').
  final String? subscriberId;

  /// Beneficiary / patient covered by the policy.
  final String? beneficiaryName;

  /// Beneficiary's relationship to the subscriber (e.g., 'self', 'spouse', 'child').
  final String? relationship;

  /// Group identification number (e.g., 'GRP98765').
  final String? groupNumber;

  /// Group or employer name (e.g., 'Acme Corp Health Benefit').
  final String? groupName;

  /// Plan identification number (e.g., 'PLN4321').
  final String? planName;

  /// Plan name or description (e.g., 'Choice Plus PPO').
  final String? planNumber;

  /// Plan class / level code (e.g., 'PPO', 'HMO', 'HDHP').
  final String? planType;

  /// High-level coverage type coding (e.g., 'Extended healthcare', 'Medical').
  final String? coverageType;

  /// FHIR coverage status (e.g., 'active', 'cancelled', 'draft').
  final String? status;

  /// Start date of coverage period.
  final DateTime? periodStart;

  /// End date of coverage period.
  final DateTime? periodEnd;

  /// Out-of-pocket costs, copayments, coinsurance, and deductibles.
  final List<CoverageCopayItem> copays;

  /// In-network / network provider name if specified.
  final String? network;

  /// Checks if coverage is currently active based on status and period dates.
  bool get isActive {
    if (status != null && status!.toLowerCase() != 'active') {
      return false;
    }
    final now = DateTime.now();
    if (periodStart != null && now.isBefore(periodStart!)) {
      return false;
    }
    if (periodEnd != null && now.isAfter(periodEnd!)) {
      return false;
    }
    return true;
  }

  static final _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      if (_isoDatePattern.hasMatch(trimmed)) {
        final parts = trimmed.split('-').map(int.parse).toList();
        return DateTime.utc(parts[0], parts[1], parts[2]);
      }
      return DateTime.tryParse(trimmed)?.toUtc();
    }
    return null;
  }

  /// Extracts structured [CoverageDetails] from a [HealthRecord]'s `sourceData`.
  static CoverageDetails? fromRecord(HealthRecord record) {
    if (record.category != RecordCategory.coverage) return null;
    final sourceData = record.sourceData;
    if (sourceData == null) {
      return CoverageDetails(payorName: record.name, status: record.status);
    }

    final payor = sourceData['payor'];
    String payorName = '';
    if (payor is List && payor.isNotEmpty) {
      final first = payor.first;
      if (first is Map) {
        payorName = (first['display'] ?? first['reference'] ?? '').toString();
      }
    } else if (payor is Map) {
      payorName = (payor['display'] ?? payor['reference'] ?? '').toString();
    }
    if (payorName.isEmpty) {
      final insurer = sourceData['insurer'];
      if (insurer is Map) {
        payorName = (insurer['display'] ?? insurer['reference'] ?? '')
            .toString();
      }
    }
    if (payorName.isEmpty) {
      payorName = record.name;
    }

    // Subscriber ID
    String? subscriberId;
    final rawSubId = sourceData['subscriberId'];
    if (rawSubId is String && rawSubId.isNotEmpty) {
      subscriberId = rawSubId;
    } else if (rawSubId is Map) {
      subscriberId = rawSubId['value']?.toString();
    } else if (rawSubId is List && rawSubId.isNotEmpty) {
      final first = rawSubId.first;
      if (first is Map) {
        subscriberId = first['value']?.toString();
      } else if (first is String) {
        subscriberId = first;
      }
    }
    if (subscriberId == null) {
      final identifiers = sourceData['identifier'];
      if (identifiers is List) {
        for (final id in identifiers) {
          if (id is Map && id['value'] != null) {
            subscriberId = id['value'].toString();
            break;
          }
        }
      }
    }

    // Beneficiary
    String? beneficiaryName;
    final ben = sourceData['beneficiary'];
    if (ben is Map) {
      beneficiaryName = (ben['display'] ?? ben['reference'])?.toString();
    }

    // Relationship
    String? relationship;
    final rel = sourceData['relationship'];
    if (rel is Map) {
      relationship =
          (rel['text'] ??
                  (rel['coding'] is List && (rel['coding'] as List).isNotEmpty
                      ? (rel['coding'] as List).first['display'] ??
                            (rel['coding'] as List).first['code']
                      : null))
              ?.toString();
    }

    // Classes: group, plan, subplan, class
    String? groupNumber;
    String? groupName;
    String? planNumber;
    String? planName;
    String? planType;
    final classes = sourceData['class'];
    if (classes is List) {
      for (final cls in classes) {
        if (cls is! Map) continue;
        final type = cls['type'];
        String? classCode;
        if (type is Map) {
          final codings = type['coding'];
          if (codings is List && codings.isNotEmpty && codings.first is Map) {
            classCode = codings.first['code']?.toString().toLowerCase();
          }
          classCode ??= type['text']?.toString().toLowerCase();
        }

        final val = cls['value'] is Map
            ? cls['value']['value']?.toString()
            : cls['value']?.toString();
        final name = cls['name']?.toString();

        switch (classCode) {
          case 'group':
            groupNumber = val ?? groupNumber;
            groupName = name ?? groupName;
          case 'plan':
            planNumber = val ?? planNumber;
            planName = name ?? planName;
          case 'subplan':
          case 'class':
            planType ??= name ?? val;
        }
      }
    }

    // Coverage Type
    String? coverageType;
    final covType = sourceData['type'];
    if (covType is Map) {
      coverageType =
          (covType['text'] ??
                  (covType['coding'] is List &&
                          (covType['coding'] as List).isNotEmpty
                      ? (covType['coding'] as List).first['display'] ??
                            (covType['coding'] as List).first['code']
                      : null))
              ?.toString();
    }

    // Period
    DateTime? periodStart;
    DateTime? periodEnd;
    final period = sourceData['period'];
    if (period is Map) {
      periodStart = _parseDate(period['start']);
      periodEnd = _parseDate(period['end']);
    }

    // Network
    final network = sourceData['network']?.toString();

    // Out-of-pocket costs / copays
    final copays = <CoverageCopayItem>[];
    final costList = sourceData['costToBeneficiary'];
    if (costList is List) {
      for (final item in costList) {
        if (item is! Map) continue;
        final costType = item['type'];
        String copayType = 'Copay';
        if (costType is Map) {
          final codings = costType['coding'];
          if (codings is List && codings.isNotEmpty && codings.first is Map) {
            copayType =
                (codings.first['display'] ?? codings.first['code'] ?? 'Copay')
                    .toString();
          } else if (costType['text'] != null) {
            copayType = costType['text'].toString();
          }
        }

        String amount = '';
        final valueMoney = item['valueMoney'];
        if (valueMoney is Map) {
          final val = valueMoney['value'];
          final currency = valueMoney['currency']?.toString() ?? '\$';
          if (val != null) {
            amount = '$currency$val';
          }
        }
        if (amount.isEmpty) {
          final valueQty = item['valueQuantity'];
          if (valueQty is Map) {
            final val = valueQty['value'];
            final unit = valueQty['unit'] ?? valueQty['code'] ?? '';
            if (val != null) {
              amount = '$val $unit'.trim();
            }
          }
        }

        if (copayType.isNotEmpty || amount.isNotEmpty) {
          copays.add(CoverageCopayItem(type: copayType, amount: amount));
        }
      }
    }

    return CoverageDetails(
      payorName: payorName,
      subscriberId: subscriberId,
      beneficiaryName: beneficiaryName,
      relationship: relationship,
      groupNumber: groupNumber,
      groupName: groupName,
      planNumber: planNumber,
      planName: planName,
      planType: planType,
      coverageType: coverageType,
      status: sourceData['status']?.toString() ?? record.status,
      periodStart: periodStart,
      periodEnd: periodEnd,
      copays: copays,
      network: network,
    );
  }
}

/// A specific copay, deductible, or coinsurance entry under a Coverage policy.
class CoverageCopayItem {
  const CoverageCopayItem({required this.type, required this.amount});

  final String type;
  final String amount;
}
