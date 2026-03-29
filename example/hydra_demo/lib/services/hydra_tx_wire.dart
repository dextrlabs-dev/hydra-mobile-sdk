import 'dart:typed_data';

/// CBOR helpers to splice a Hydra draft tx without re-encoding the body.
///
/// Re-encoding [TransactionBody] via catalyst changes map ordering / value
/// shapes vs cardano-api, which breaks L1 decoding (e.g. multi-asset / asset
/// name errors). The body bytes from `POST /commit` must be preserved for both
/// the Blake2b-256 tx-body hash and the submitted CBOR.

/// End offset (exclusive) after one CBOR value starting at [p].
int skipCborValue(Uint8List b, int p) {
  if (p >= b.length) {
    throw const FormatException('truncated CBOR');
  }
  final ib = b[p++];
  final major = ib >> 5;
  final ai = ib & 0x1f;

  int readUnsignedArg() {
    if (ai < 24) return ai;
    switch (ai) {
      case 24:
        if (p >= b.length) throw const FormatException('truncated CBOR');
        return b[p++];
      case 25:
        if (p + 1 >= b.length) throw const FormatException('truncated CBOR');
        final v = (b[p] << 8) | b[p + 1];
        p += 2;
        return v;
      case 26:
        if (p + 3 >= b.length) throw const FormatException('truncated CBOR');
        final v = ByteData.sublistView(b, p, p + 4).getUint32(0, Endian.big);
        p += 4;
        return v;
      case 27:
        if (p + 7 >= b.length) throw const FormatException('truncated CBOR');
        final bd = ByteData.sublistView(b, p, p + 8);
        p += 8;
        final hi = bd.getUint32(0, Endian.big);
        final lo = bd.getUint32(4, Endian.big);
        return (hi << 32) + lo;
      default:
        throw FormatException('unsupported CBOR additional info: $ai');
    }
  }

  switch (major) {
    case 0: // unsigned int
    case 1: // negative int
      readUnsignedArg();
      return p;
    case 6: // tag
      readUnsignedArg();
      return skipCborValue(b, p);
    case 7: // simple / float
      if (ai < 24) return p;
      if (ai == 25) {
        if (p + 1 >= b.length) throw const FormatException('truncated CBOR');
        return p + 2;
      }
      if (ai == 26) {
        if (p + 3 >= b.length) throw const FormatException('truncated CBOR');
        return p + 4;
      }
      if (ai == 27) {
        if (p + 7 >= b.length) throw const FormatException('truncated CBOR');
        return p + 8;
      }
      readUnsignedArg();
      return p;
    case 2: // byte string
    case 3: // text string
      if (ai == 31) {
        while (p < b.length && b[p] != 0xff) {
          p = skipCborValue(b, p);
        }
        if (p >= b.length) throw const FormatException('unclosed indefinite string');
        return p + 1;
      }
      final len = readUnsignedArg();
      if (p + len > b.length) throw const FormatException('truncated CBOR');
      p += len;
      return p;
    case 4: // array
      if (ai == 31) {
        while (p < b.length && b[p] != 0xff) {
          p = skipCborValue(b, p);
        }
        if (p >= b.length) throw const FormatException('unclosed indefinite array');
        return p + 1;
      }
      final n = readUnsignedArg();
      for (var i = 0; i < n; i++) {
        p = skipCborValue(b, p);
      }
      return p;
    case 5: // map
      if (ai == 31) {
        while (p < b.length && b[p] != 0xff) {
          p = skipCborValue(b, p);
          p = skipCborValue(b, p);
        }
        if (p >= b.length) throw const FormatException('unclosed indefinite map');
        return p + 1;
      }
      final n = readUnsignedArg();
      for (var i = 0; i < 2 * n; i++) {
        p = skipCborValue(b, p);
      }
      return p;
    default:
      throw FormatException('unsupported CBOR major type: $major');
  }
}

/// Inclusive start / exclusive end for each element of a root CBOR array of 4.
List<(int start, int end)> cborRootArray4ItemSpans(Uint8List txBytes) {
  if (txBytes.isEmpty || txBytes[0] != 0x84) {
    throw FormatException(
      'Expected root CBOR array of 4 (0x84), got 0x'
      '${txBytes.isEmpty ? '??' : txBytes[0].toRadixString(16)}',
    );
  }
  var p = 1;
  final spans = <(int, int)>[];
  for (var i = 0; i < 4; i++) {
    final start = p;
    p = skipCborValue(txBytes, p);
    spans.add((start, p));
  }
  if (p != txBytes.length) {
    throw FormatException(
      'Trailing bytes after root tx (${txBytes.length - p} bytes)',
    );
  }
  return spans;
}

/// Exact transaction body CBOR bytes (Hydra draft) for Blake2b-256 signing.
Uint8List hydraTxBodyBytesForSigning(Uint8List txBytes) {
  final spans = cborRootArray4ItemSpans(txBytes);
  final body = spans[0];
  return Uint8List.sublistView(txBytes, body.$1, body.$2);
}

/// `0x84` + [body] + [witness] + [valid] + [aux] (each already CBOR-encoded).
Uint8List assembleWitnessedTxPreservingSlices({
  required Uint8List bodySlice,
  required List<int> witnessEncoded,
  required Uint8List isValidSlice,
  required Uint8List auxiliarySlice,
}) {
  final out = BytesBuilder(copy: false);
  out.addByte(0x84);
  out.add(bodySlice);
  out.add(witnessEncoded);
  out.add(isValidSlice);
  out.add(auxiliarySlice);
  return out.toBytes();
}
