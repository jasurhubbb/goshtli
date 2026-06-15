// Card — one saved payment card. Mirrors backend apps/payments/Card.
//
// PCI-clean by design: this model NEVER holds a full PAN or CVC. The only PAN substring it sees is the
// last 4 digits (display-only). The full PAN + CVC live ONLY in the AddCardSheet's local state for the
// duration of the POST request, then are discarded. Server returns this read shape only.
import 'package:json_annotation/json_annotation.dart';

part 'card_model.g.dart';


/// Closed set matching backend Card.Brand. UNKNOWN is the fallback when the BIN doesn't match any of the
/// recognized prefixes — UI shows a generic card icon for it.
enum CardBrand {
  @JsonValue('HUMO') humo,
  @JsonValue('UZCARD') uzcard,
  @JsonValue('VISA') visa,
  @JsonValue('MASTERCARD') mastercard,
  @JsonValue('UNKNOWN') unknown,
}


@JsonSerializable()
class PaymentCard {
  final int id;
  @JsonKey(name: 'last_4') final String last4;
  final CardBrand brand;
  @JsonKey(name: 'expires_month') final int expiresMonth;
  @JsonKey(name: 'expires_year') final int expiresYear;
  @JsonKey(name: 'holder_name', defaultValue: '') final String holderName;
  @JsonKey(name: 'phone_for_sms', defaultValue: '') final String phoneForSms;
  @JsonKey(name: 'is_default', defaultValue: false) final bool isDefault;
  @JsonKey(name: 'created_at', defaultValue: '') final String createdAt;

  const PaymentCard({required this.id, required this.last4, required this.brand,
                     required this.expiresMonth, required this.expiresYear,
                     this.holderName = '', this.phoneForSms = '',
                     this.isDefault = false, this.createdAt = ''});

  factory PaymentCard.fromJson(Map<String, dynamic> json) => _$PaymentCardFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentCardToJson(this);

  /// "•••• 4242" — the standard masked display. Picker rows, profile rows, breakdown lines all use this.
  String get maskedDisplay => '•••• $last4';

  /// "12/30" — formatted expiry string. Used on the picker row + profile list.
  String get expiryDisplay => '${expiresMonth.toString().padLeft(2, '0')}/${expiresYear % 100}';

  /// Client-side check mirroring backend `is_expired`. We do this on the mobile too so the picker can
  /// grey out the row without a round-trip.
  bool get isExpired {
    final now = DateTime.now();
    return (expiresYear, expiresMonth).compareTo((now.year, now.month)) < 0;
  }
}


/// Helper that lets us compare (year, month) tuples lexicographically in `isExpired`.
extension on (int, int) {
  int compareTo((int, int) other) {
    final a = $1.compareTo(other.$1);
    return a != 0 ? a : $2.compareTo(other.$2);
  }
}
