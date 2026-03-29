/// JSON bodies for WebSocket client inputs (Hydra API reference).
abstract class ClientInput {
  static Map<String, dynamic> init() => {'tag': 'Init'};

  static Map<String, dynamic> close() => {'tag': 'Close'};

  static Map<String, dynamic> safeClose() => {'tag': 'SafeClose'};

  static Map<String, dynamic> contest() => {'tag': 'Contest'};

  static Map<String, dynamic> fanout() => {'tag': 'Fanout'};

  /// [transaction] must match Hydra `Transaction` schema (`cborHex`, `type`, `description`, optional `txId`).
  static Map<String, dynamic> newTx(Map<String, dynamic> transaction) => {
        'tag': 'NewTx',
        'transaction': transaction,
      };

  static Map<String, dynamic> recover(String recoverTxId) => {
        'tag': 'Recover',
        'recoverTxId': recoverTxId,
      };

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
