/// Pluggable Hydra L2 signer.
///
/// Apps supply hardware-backed or wallet-delegated implementations.
/// The core package does not custody keys.
abstract class HydraSigner {
  /// Sign opaque payload bytes prepared for the Hydra L2 workflow.
  Future<List<int>> signPayload(List<int> payload);
}
