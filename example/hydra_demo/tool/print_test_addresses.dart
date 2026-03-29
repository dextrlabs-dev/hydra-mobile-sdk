// ignore_for_file: avoid_print

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:catalyst_key_derivation/catalyst_key_derivation.dart';

/// Prints base addresses for public BIP39 test phrases (demo / zero value only).
Future<void> main() async {
  await CatalystKeyDerivation.init();
  const path = "m/1852'/1815'/0'/0/0";
  const derivation = CatalystKeyDerivation();

  const phrases = [
    (
      name: 'BIP39 vector #1 (12 words)',
      phrase:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    ),
    (
      name: 'BIP39 vector #2 (12 words)',
      phrase:
          'legal winner thank year wave sausage worth useful legal winner thank yellow',
    ),
    (
      name: 'Extra test phrase (12 words)',
      phrase:
          'test test test test test test test test test test test ball',
    ),
  ];

  const stakePath = "m/1852'/1815'/0'/2/0";

  for (final p in phrases) {
    final master = await derivation.deriveMasterKey(mnemonic: p.phrase);
    final paySk = await master.derivePrivateKey(path: path);
    final payVk = await paySk.derivePublicKey();
    final stakeSk = await master.derivePrivateKey(path: stakePath);
    final stakeVk = await stakeSk.derivePublicKey();

    final payHash = Ed25519PublicKeyHash.fromPublicKey(payVk.toPublicKey());
    final stakeHash = Ed25519PublicKeyHash.fromPublicKey(stakeVk.toPublicKey());
    // CIP-19: testnet base address header 0x00 (type base + network testnet).
    final addrBytes = <int>[0x00, ...payHash.bytes, ...stakeHash.bytes];
    final addr = ShelleyAddress(addrBytes);

    print('--- ${p.name} ---');
    print('Mnemonic: ${p.phrase}');
    print('Base addr (pay $path, stake $stakePath): ${addr.toBech32()}');
    print('');
  }
}
