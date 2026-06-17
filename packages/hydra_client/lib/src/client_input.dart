/// Builders for the WebSocket client-input JSON bodies in the Hydra API.
///
/// These only construct the request maps; they do **not** validate payloads —
/// validation is performed by `hydra-node` when the input is sent.
abstract class ClientInput {
  /// `Init` — start opening a new head.
  static Map<String, dynamic> init() => {'tag': 'Init'};

  /// `Close` — begin closing the open head.
  static Map<String, dynamic> close() => {'tag': 'Close'};

  /// `SafeClose` — close only if the latest snapshot is confirmed.
  static Map<String, dynamic> safeClose() => {'tag': 'SafeClose'};

  /// `Contest` — contest a close with a newer confirmed snapshot.
  static Map<String, dynamic> contest() => {'tag': 'Contest'};

  /// `Fanout` — distribute the final UTxO set back to L1 after the contest period.
  static Map<String, dynamic> fanout() => {'tag': 'Fanout'};

  /// [transaction] must match Hydra `Transaction` schema (`cborHex`, `type`, `description`, optional `txId`).
  static Map<String, dynamic> newTx(Map<String, dynamic> transaction) => {
        'tag': 'NewTx',
        'transaction': transaction,
      };

  /// `Recover` — reclaim a deposit identified by [recoverTxId].
  static Map<String, dynamic> recover(String recoverTxId) => {
        'tag': 'Recover',
        'recoverTxId': recoverTxId,
      };

  /// `Decommit` — move [decommitTx]'s outputs out of the head back to L1.
  static Map<String, dynamic> decommit(Map<String, dynamic> decommitTx) => {
        'tag': 'Decommit',
        'decommitTx': decommitTx,
      };

  /// [snapshot] must match `ConfirmedSnapshot` schema from the API.
  static Map<String, dynamic> sideLoadSnapshot(Map<String, dynamic> snapshot) => {
        'tag': 'SideLoadSnapshot',
        'snapshot': snapshot,
      };
}
