#!/bin/sh
# Starts bitcoind 28 (regtest, -mempoolfullrbf=1) and Fulcrum (TLS on 127.0.0.1:52002 with a self-signed
# certificate) and prepares the funded "funder" wallet used by MasterRegtestTests and MasterRegtestUITests.
# Regtest only: the RPC password and coins are worthless test values.
set -eu
cd "$(dirname "$0")"
compose() { if docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi; }
sh ./generate-test-certificate.sh
compose -f compose.yaml up --build -d
rpc() {
  # Legacy local-only RPC credential retained to keep the existing regtest server and all its clients compatible; not app branding.
  curl -s --user unsend:regtest-only -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"1.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}" "http://127.0.0.1:52443/${3:-}"
}
for _ in $(seq 1 60); do rpc getblockchaininfo | grep -q '"chain":"regtest"' && break; sleep 1; done
rpc listwallets | grep -q '"funder"' || rpc loadwallet '["funder"]' | grep -q '"name"' || rpc createwallet '["funder"]' >/dev/null
balance=$(rpc getbalance '[]' wallet/funder | sed -E 's/.*"result":([0-9.]+).*/\1/')
if [ "${balance%%.*}" -lt 50 ]; then
  address=$(rpc getnewaddress '[]' wallet/funder | sed -E 's/.*"result":"([^"]+)".*/\1/')
  rpc generatetoaddress "[101,\"$address\"]" wallet/funder >/dev/null
fi
echo "regtest ready: $(rpc getblockcount | sed -E 's/.*"result":([0-9]+).*/\1/') blocks, funder balance $(rpc getbalance '[]' wallet/funder | sed -E 's/.*"result":([0-9.]+).*/\1/') BTC"
