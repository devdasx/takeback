#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validation_dir=$(mktemp -d /tmp/Takeback-KeyVectors.XXXXXX)
trap 'rm -rf "$validation_dir"' EXIT
cp "$root/Takeback/Resources/BIP39/english.txt" "$validation_dir/english.txt"
xcrun --sdk macosx clang -c "$root/Takeback/Security/SecureMemory.c" -o "$validation_dir/zero.o"
xcrun --sdk macosx swiftc -import-objc-header "$root/Takeback/Takeback-Bridging-Header.h" \
 "$root/Takeback/Security/SecureBytes.swift" \
 "$root/Takeback/Features/EnterKey/KeyValidation.swift" \
 "$root/Takeback/Features/EnterKey/KeyDetection.swift" \
 "$root/Scripts/KeyVectorCheck.swift" "$validation_dir/zero.o" -o "$validation_dir/check"
"$validation_dir/check" "$root/TakebackTests/Fixtures/KeyVectors.json"
