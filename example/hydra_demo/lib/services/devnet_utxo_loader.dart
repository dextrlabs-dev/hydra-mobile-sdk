import 'dart:convert';
import 'dart:io';

import 'package:catalyst_cardano_serialization/catalyst_cardano_serialization.dart';
import 'package:catalyst_key_derivation/catalyst_key_derivation.dart' as kd;

import 'catalyst_init_once.dart';

/// Loads Cardano L1 UTxOs for the payment address derived from a BIP39 mnemonic.
///
/// This is **demo-only** and intended for the local Hydra `demo/` devnet where
/// `cardano-cli` is available inside the `cardano-node` docker compose service.
class DevnetUtxoLoader {
  DevnetUtxoLoader._();

  static const paymentPath = "m/1852'/1815'/0'/0/0";
  static const stakePath = "m/1852'/1815'/0'/2/0";
  static const testnetMagic = 42;

  /// Default location for the upstream Hydra repo `demo/` compose file.
  static const defaultComposeFile = '/root/hydra/demo/docker-compose.yaml';

  static Future<String> deriveBaseTestnetAddressFromMnemonic(
    String mnemonic, {
    String paymentDerivationPath = paymentPath,
    String stakeDerivationPath = stakePath,
  }) async {
    await CatalystInitOnce.ensureInitialized();
    const derivation = kd.CatalystKeyDerivation();
    final master = await derivation.deriveMasterKey(mnemonic: mnemonic.trim());
    final paySk = await master.derivePrivateKey(path: paymentDerivationPath);
    final payVk = await paySk.derivePublicKey();
    final stakeSk = await master.derivePrivateKey(path: stakeDerivationPath);
    final stakeVk = await stakeSk.derivePublicKey();

    final payHash = Ed25519PublicKeyHash.fromPublicKey(payVk.toPublicKey());
    final stakeHash = Ed25519PublicKeyHash.fromPublicKey(stakeVk.toPublicKey());
    // CIP-19: testnet base address header 0x00 (type base + network testnet).
    final addrBytes = <int>[0x00, ...payHash.bytes, ...stakeHash.bytes];
    return ShelleyAddress(addrBytes).toBech32();
  }

  /// Queries `cardano-cli query utxo --output-json` for [address] using docker compose.
  ///
  /// Returns the decoded JSON object (txHash#ix -> output).
  static Future<Map<String, dynamic>> queryUtxoJson({
    required String address,
    String composeFile = defaultComposeFile,
    bool conway = true,
  }) async {
    final args = <String>[
      'compose',
      '-f',
      composeFile,
      'exec',
      '-T',
      'cardano-node',
      'cardano-cli',
      if (conway) 'conway',
      'query',
      'utxo',
      '--socket-path',
      '/devnet/node.socket',
      '--testnet-magic',
      '$testnetMagic',
      '--address',
      address,
      '--output-json',
    ];

    final res = await Process.run(
      'docker',
      args,
      stdoutEncoding: const Utf8Codec(),
      stderrEncoding: const Utf8Codec(),
    );
    if (res.exitCode != 0) {
      throw StateError('docker ${args.join(' ')}\n${res.stderr}');
    }
    final raw = (res.stdout as String).trim();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw StateError('Expected UTxO JSON object, got: ${decoded.runtimeType}');
  }

  /// Best-effort: tries Conway-era CLI first, then falls back.
  static Future<Map<String, dynamic>> queryUtxoJsonBestEffort({
    required String address,
    String composeFile = defaultComposeFile,
  }) async {
    try {
      return await queryUtxoJson(
        address: address,
        composeFile: composeFile,
        conway: true,
      );
    } catch (_) {
      return await queryUtxoJson(
        address: address,
        composeFile: composeFile,
        conway: false,
      );
    }
  }
}
