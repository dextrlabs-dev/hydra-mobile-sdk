#!/usr/bin/env bash
# Fund an arbitrary addr_test on Hydra local devnet (magic 42) from demo/faucet.sk.
#
# Prerequisites:
#   - hydra repo demo/ with docker compose, cardano-node running
#   - ./seed-devnet.sh already run (faucet has ada)
#
# Usage (from hydra/demo):
#   /path/to/fund_addr_from_faucet.sh addr_test1q... [lovelace]
#
# Default amount: 100_000_000 lovelace (100 ada)

set -euo pipefail

TARGET="${1:?Usage: $0 addr_test1... [lovelace]}"
AMOUNT="${2:-100000000}"

if [[ "$TARGET" != addr_test* ]]; then
  echo "Expected a bech32 testnet address (addr_test...)." >&2
  exit 1
fi

# shellcheck disable=SC2153
COMPOSE="${COMPOSE:-docker compose}"

$COMPOSE exec -T cardano-node cardano-cli conway address build \
  --testnet-magic 42 \
  --payment-verification-key-file /devnet/credentials/faucet.vk \
  | tr -d '\r' >/tmp/hydra_faucet_addr.txt
FAUCET_ADDR=$(cat /tmp/hydra_faucet_addr.txt)

$COMPOSE exec -T cardano-node cardano-cli conway query utxo \
  --socket-path /devnet/node.socket \
  --testnet-magic 42 \
  --address "$FAUCET_ADDR" \
  --output-json >/tmp/hydra_faucet_utxo.json

FAUCET_TXIN=$(jq -r 'keys[0] // empty' /tmp/hydra_faucet_utxo.json)
if [[ -z "$FAUCET_TXIN" || "$FAUCET_TXIN" == "null" ]]; then
  echo "Faucet has no UTxO. From hydra/demo run: ./seed-devnet.sh" >&2
  exit 1
fi

echo "Faucet tx-in: $FAUCET_TXIN" >&2
echo "Sending $AMOUNT lovelace to $TARGET" >&2

$COMPOSE exec -T cardano-node cardano-cli conway transaction build \
  --testnet-magic 42 \
  --socket-path /devnet/node.socket \
  --cardano-mode \
  --change-address "$FAUCET_ADDR" \
  --tx-in "$FAUCET_TXIN" \
  --tx-out "${TARGET}+${AMOUNT}" \
  --out-file /devnet/fund-external.draft

$COMPOSE exec -T cardano-node cardano-cli conway transaction sign \
  --testnet-magic 42 \
  --tx-body-file /devnet/fund-external.draft \
  --signing-key-file /devnet/credentials/faucet.sk \
  --out-file /devnet/fund-external.signed

$COMPOSE exec -T cardano-node cardano-cli conway transaction submit \
  --socket-path /devnet/node.socket \
  --testnet-magic 42 \
  --tx-file /devnet/fund-external.signed

echo "Submitted. Wait a few seconds, then query utxo on the target address." >&2
