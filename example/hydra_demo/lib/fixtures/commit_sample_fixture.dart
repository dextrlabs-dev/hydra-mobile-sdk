/// Preview-testnet sample for manual commit flow testing only.
/// UTxO shape matches `cardano-cli query utxo --output-json`.
const kSampleCommitUtxoJson = r'''
{
  "f6c1c63439506b7dbb333a373f8991f0222e40acba7ba853be33dcdc864ac049#0": {
    "address": "addr_test1qq8ac7qqy0vtulyl7wntmsxc6wex80gvcyjy33qffrhm7sh927ysx5sftuw0dlft05dz3c7revpf7jx0xnlcjz3g69mqkt5dmn",
    "datum": null,
    "datumhash": null,
    "inlineDatum": null,
    "inlineDatumRaw": null,
    "referenceScript": null,
    "value": {
      "lovelace": 50000000
    }
  }
}
''';

/// Standard BIP39 test vector (only for local / preview demos).
const kSampleBip39Mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
