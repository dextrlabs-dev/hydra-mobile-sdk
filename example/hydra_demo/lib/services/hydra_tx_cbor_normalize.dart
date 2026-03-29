import 'package:cbor/cbor.dart';

/// Normalizes transaction CBOR from Hydra `POST /commit` so
/// [Transaction.fromCbor] in catalyst_cardano_serialization can parse it.
///
/// Haskell/cardano-api may use:
/// - `CborInt` map keys where the Dart catalyst code looks up [CborSmallInt] keys
/// - CBOR **maps** for body fields that the ledger encodes as ordered sets (0,1,13,14,18)
/// - **map** `{vkey: sig}` for vkey witnesses instead of a list of `[vkey,sig]` pairs
CborValue normalizeHydraCommitTransactionCbor(CborValue decoded) {
  if (decoded is CborMap) {
    return CborList([
      _normalizeTransactionBodyMap(decoded),
      CborMap({}),
      const CborBool(true),
      const CborNull(),
    ]);
  }
  if (decoded is! CborList || decoded.isEmpty) {
    throw FormatException(
      'Unexpected commit tx CBOR root: ${decoded.runtimeType}',
    );
  }
  final parts = List<CborValue>.from(decoded);
  if (parts[0] is CborMap) {
    parts[0] = _normalizeTransactionBodyMap(parts[0] as CborMap);
  }
  if (parts.length > 1 && parts[1] is CborMap) {
    parts[1] = _normalizeWitnessSetMap(parts[1] as CborMap);
  }
  return CborList(parts);
}

int? _fieldKeyAsInt(CborValue k) {
  if (k is CborSmallInt) return k.value;
  if (k is CborInt) {
    try {
      final v = k.toInt();
      if (v >= 0) return v;
    } catch (_) {}
  }
  return null;
}

CborValue _canonicalFieldKey(CborValue k) {
  final i = _fieldKeyAsInt(k);
  if (i != null && i >= 0 && i < 256) return CborSmallInt(i);
  return k;
}

/// Body fields that catalyst parses via [_extractList] (must be CBOR arrays).
const _bodySetFieldKeys = {0, 1, 13, 14, 18};

CborMap _normalizeTransactionBodyMap(CborMap body) {
  final out = <CborValue, CborValue>{};
  for (final e in body.entries) {
    final k = _canonicalFieldKey(e.key);
    var v = e.value;
    final kn = _fieldKeyAsInt(k);
    if (kn != null && _bodySetFieldKeys.contains(kn) && v is CborMap) {
      v = _mapValuesToSortedList(v);
    }
    out[k] = v;
  }
  return CborMap(out);
}

CborList _mapValuesToSortedList(CborMap m) {
  final entries = m.entries.map((e) {
    final ki = _fieldKeyAsInt(e.key);
    if (ki == null) {
      throw FormatException(
        'Expected integer keys in set-like CBOR map, got ${e.key.runtimeType}',
      );
    }
    return MapEntry(ki, e.value);
  }).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return CborList(entries.map((e) => e.value).toList());
}

CborMap _normalizeWitnessSetMap(CborMap wit) {
  final out = <CborValue, CborValue>{};
  for (final e in wit.entries) {
    final k = _canonicalFieldKey(e.key);
    var v = e.value;
    final kn = _fieldKeyAsInt(k);
    if (kn == 0 && v is CborMap) {
      v = _normalizeVkeyWitnessContainer(v);
    } else if (kn != null && kn >= 1 && kn <= 7 && v is CborMap) {
      // catalyst.TransactionWitnessSet._getWitnesses casts to CborList; the ledger
      // uses CBOR maps for some witness groups (e.g. redeemers in Conway).
      final m = v;
      v = m.isEmpty ? CborList([]) : _mapValuesSortedByEncodedKey(m);
    }
    out[k] = v;
  }
  return CborMap(out);
}

CborList _mapValuesSortedByEncodedKey(CborMap m) {
  final entries = m.entries.toList()
    ..sort((a, b) {
      final ea = cborEncode(a.key);
      final eb = cborEncode(b.key);
      final n = ea.length < eb.length ? ea.length : eb.length;
      for (var i = 0; i < n; i++) {
        final c = ea[i].compareTo(eb[i]);
        if (c != 0) return c;
      }
      return ea.length.compareTo(eb.length);
    });
  return CborList(entries.map((e) => e.value).toList());
}

/// Merges [additionalVkeyWitness] (`[vkey, signature]` list) into Hydra's
/// witness CBOR map without touching other witness buckets (redeemers, etc.).
///
/// Used when splicing a signed tx: only key `0` is updated; other entries keep
/// their decoded CBOR shape for stable re-encoding.
CborMap mergeHydraVkeyWitnessIntoWitnessSet(
  CborValue witnessRoot,
  CborList additionalVkeyWitness,
) {
  if (witnessRoot is! CborMap) {
    throw FormatException(
      'Witness set must be a CBOR map, got ${witnessRoot.runtimeType}',
    );
  }
  final out = <CborValue, CborValue>{};
  for (final e in witnessRoot.entries) {
    out[_canonicalFieldKey(e.key)] = e.value;
  }
  const k0 = CborSmallInt(0);
  final cur = out[k0];
  final List<CborValue> items;
  if (cur == null) {
    items = [additionalVkeyWitness];
  } else if (cur is CborList) {
    items = [...cur, additionalVkeyWitness];
  } else if (cur is CborMap) {
    final norm = _normalizeVkeyWitnessContainer(cur);
    items = [...(norm as CborList), additionalVkeyWitness];
  } else {
    throw FormatException('Witness vkey bucket has unexpected type ${cur.runtimeType}');
  }
  out[k0] = CborList(items);
  return CborMap(out);
}

/// Either `{0: [vk,sig], 1: ...}` style map or `{vk: sig}` map.
CborValue _normalizeVkeyWitnessContainer(CborMap m) {
  if (m.isEmpty) return CborList([]);
  final allIntKeys = m.keys.every((key) => _fieldKeyAsInt(key) != null);
  if (allIntKeys) {
    return _mapValuesToSortedList(m);
  }
  return CborList(
    m.entries.map((e) => CborList([e.key, e.value])).toList(),
  );
}
