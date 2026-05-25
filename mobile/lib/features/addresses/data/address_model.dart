// Address — mirrors backend apps/buyers/SavedAddress (v3.1).
//
// One named delivery address per row. The user picks one at checkout instead of re-typing. Lat/lng come from the
// map picker; the structured fields (entrance/floor/apartment/notes) are courier hints — couriers use whatever
// is filled in to find the buyer faster.
import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';


/// DRF DecimalField helpers — Decimals arrive as quoted strings ("41.311081"). Nullable for unmapped addresses.
double? _decimalFromString(Object? v) =>
    v == null || v.toString().isEmpty ? null : double.tryParse(v.toString());
String? _decimalToString(double? v) => v?.toStringAsFixed(6);


@JsonSerializable()
class Address {
  final int id;
  final String label;        // "Uy", "Ofis", or whatever the buyer typed
  final String address;      // street line — "Bobur mahalla fuqarolar yig'ini, 6"
  final String entrance;
  final String floor;
  final String apartment;
  final String notes;        // freeform hints the courier sees on the order screen
  @JsonKey(fromJson: _decimalFromString, toJson: _decimalToString) final double? lat;
  @JsonKey(fromJson: _decimalFromString, toJson: _decimalToString) final double? lng;
  @JsonKey(name: 'is_default', defaultValue: false) final bool isDefault;

  const Address({required this.id, required this.label, required this.address,
                 this.entrance = '', this.floor = '', this.apartment = '', this.notes = '',
                 this.lat, this.lng, this.isDefault = false});

  factory Address.fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);

  /// Compact one-line representation for the home pill + cart summary — "Uy · Bobur mahalla, 6".
  String compactDisplay() => "$label · $address";

  /// Full multi-line text the courier sees on the order — includes hints if filled in. Used as the
  /// `delivery_address` payload when placing an order, until we add a proper FK on the Order model.
  String fullCourierText() {
    final hints = <String>[
      if (entrance.isNotEmpty) 'Kirish: $entrance',
      if (floor.isNotEmpty) 'Qavat: $floor',
      if (apartment.isNotEmpty) 'Xonadon: $apartment',
    ];
    return [
      '$label — $address',
      if (hints.isNotEmpty) hints.join(', '),
      if (notes.isNotEmpty) notes,
    ].join('\n');
  }
}
