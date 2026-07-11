#!/bin/bash
# attest-ledger.sh — 生成 SHA-256 哈希，保护 ledger 不被篡改
# 继承自 long-task-manager/scripts/attest-ledger.sh
# Usage: bash scripts/attest-ledger.sh docs/spm/ledger.md

set -e

LEDGER="${1:-docs/spm/ledger.md}"

if [[ ! -f "$LEDGER" ]]; then
  echo "❌ Ledger not found: $LEDGER"
  exit 1
fi

HASH_FILE="${LEDGER}.sha256"

# 生成 SHA-256 哈希
if command -v sha256sum &> /dev/null; then
  sha256sum "$LEDGER" > "$HASH_FILE"
elif command -v shasum &> /dev/null; then
  shasum -a 256 "$LEDGER" > "$HASH_FILE"
else
  echo "⚠️  No SHA-256 tool found (sha256sum/shasum). Skipping attestation."
  exit 0
fi

echo "✅ Hash attestation written: $HASH_FILE"
echo "   $(cat "$HASH_FILE")"