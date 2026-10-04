# Frequently asked questions

## Can Takeback undo a confirmed Bitcoin payment?

No. It prepares a competing transaction spending the same inputs with a higher fee. Once the original is confirmed, this workflow cannot reverse it. A pending original may also confirm while you are reviewing or broadcasting.

## Is a broadcast replacement guaranteed to confirm?

No. Nodes and miners decide what they accept and include. A successful response means the server accepted or already knew the transaction, not that a miner confirmed it. Follow the result screen and check the public transaction status.

## Is this a wallet or a recovery service?

It is a focused on-chain replacement tool. It has no account service, retained wallet history, or cloud recovery. You must control the necessary signing keys. It cannot obtain someone else's key or replace a transaction your key cannot sign alone.

## What pays the extra fee for Speed up?

Owned change pays it when possible. If there is no change, a supported single-recipient payment can reduce the recipient amount; the review screen identifies that case. A payment with multiple recipients and no suitable change cannot arbitrarily reduce one recipient. Dust change can be absorbed into the fee.

## What are linked payments?

A later unconfirmed transaction may spend an output of the payment being replaced. Replacement must account for descendant fees and can invalidate those later spends. Read the linked-payment warning and review the total fee.

## Why did the search find nothing?

The key may not control an unconfirmed payment, the payment may already be confirmed, or the wallet may use different paths or accounts. Check the BIP39 passphrase exactly, including case and whitespace. Adjust accounts, depth, or custom paths only if you know the wallet's derivation scheme. Scanning is bounded and cannot search every possible path.

## Which address types are supported?

BIP86 Taproot, BIP84 native SegWit, BIP49 nested SegWit, and BIP44 legacy. Available types depend on the imported key. An uncompressed WIF has different constraints from an HD wallet, and an account-level extended key cannot derive hardened sibling accounts.

## Are custom paths saved?

The numeric account/depth defaults persist. Custom path selections belong to the current key session and are cleared with it. The editor checks syntax, depth, component bounds, and duplicate paths, and can preview the first address.

## Does the app upload my recovery phrase?

The networking layer uses public lookup data and signed transactions. Keys and passphrases stay in the app's memory-based workflow. This does not mean every system-owned memory copy can be erased; read [Privacy](PRIVACY.md) and [Security](../SECURITY.md).

## Does Face ID protect a stored wallet?

There is no stored wallet to unlock. Device-owner authentication is requested before signing and broadcasting. The system chooses the available authentication method, including passcode fallback; biometric hardware is not present on every device.

## Can I use Lightning, multisig, or an exchange withdrawal?

This tool targets on-chain transactions signable by the imported key. It does not reverse Lightning payments or control an exchange's withdrawal keys. Payments containing inputs that require other signers are not independently changeable here.

## Where is the App Store download?

This repository provides source. It does not assert an App Store listing or distribute a signed production binary. Follow [Building](BUILDING.md) to run your own build.
