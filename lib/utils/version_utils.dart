/// Semantic-version helpers.
abstract final class VersionUtils {
  /// Compares two dotted versions (`1.2.10` vs `1.2.9`). Build metadata after
  /// `+` and pre-release tags after `-` are ignored.
  /// Returns a negative number when [a] < [b], zero when equal, positive otherwise.
  static int compare(String a, String b) {
    final List<int> pa = _parts(a);
    final List<int> pb = _parts(b);
    final int length = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < length; i++) {
      final int x = i < pa.length ? pa[i] : 0;
      final int y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static List<int> _parts(String version) {
    final String core = version.trim().split('+').first.split('-').first;
    if (core.isEmpty) return const <int>[0];
    return core
        .split('.')
        .map((String p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList(growable: false);
  }
}
