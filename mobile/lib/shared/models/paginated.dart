// Paginated<T> — wraps DRF's PageNumberPagination response shape so any list endpoint produces the same wrapper.
class Paginated<T> {
  final int count;             // total rows across all pages
  final String? next;          // next-page URL or null on the last page
  final String? previous;
  final List<T> results;

  const Paginated({required this.count, required this.results, this.next, this.previous});

  /// itemFromJson is supplied by the caller because we cannot decode generics from JSON alone in Dart.
  factory Paginated.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) itemFromJson) =>
      Paginated(count: json['count'] as int,
                next: json['next'] as String?,
                previous: json['previous'] as String?,
                results: (json['results'] as List).cast<Map<String, dynamic>>().map(itemFromJson).toList());
}
