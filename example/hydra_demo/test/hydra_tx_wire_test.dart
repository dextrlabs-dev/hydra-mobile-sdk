import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydra_demo/services/hydra_tx_wire.dart';

void main() {
  test('cborRootArray4ItemSpans splits minimal tx', () {
    // [0, {}, true, null]  →  84 00 a0 f5 f6
    final tx = Uint8List.fromList([0x84, 0x00, 0xa0, 0xf5, 0xf6]);
    final spans = cborRootArray4ItemSpans(tx);
    expect(spans.length, 4);
    expect(spans[0], (1, 2));
    expect(spans[1], (2, 3));
    expect(spans[2], (3, 4));
    expect(spans[3], (4, 5));
    expect(hydraTxBodyBytesForSigning(tx), Uint8List.fromList([0x00]));
  });

  test('assembleWitnessedTxPreservingSlices round-trips layout', () {
    final body = Uint8List.fromList([0x00]);
    const wit = <int>[0xa0];
    final valid = Uint8List.fromList([0xf5]);
    final aux = Uint8List.fromList([0xf6]);
    final out = assembleWitnessedTxPreservingSlices(
      bodySlice: body,
      witnessEncoded: wit,
      isValidSlice: valid,
      auxiliarySlice: aux,
    );
    expect(out, Uint8List.fromList([0x84, 0x00, 0xa0, 0xf5, 0xf6]));
  });
}
