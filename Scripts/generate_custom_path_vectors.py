"""Public BIP39 fixtures only. Independent reference: embit==0.8.0.
Run from the project root in a disposable Python environment with embit installed.
"""
from embit import bip32, bip39, script
from pathlib import Path
import json

mnemonic = 'abandon ' * 11 + 'about'
paths = ["m/0'", "m/0'/0'", "m/84'/0'/2147483646'", "m/44'/0'/0'/0", "m/1'/2/3'/4/5'/6"]
vectors = []
for phrase in ['', ' TREZOR ']:
    root = bip32.HDKey.from_seed(bip39.mnemonic_to_seed(mnemonic, phrase))
    for path in paths:
        fixed = len(path.split('/')) - 1 >= 4
        for branch in ([0] if fixed else [0, 1]):
            leaf = path + ('/0' if fixed else f'/{branch}/0')
            pub = root.derive(leaf).key.get_public_key()
            for kind, encode in [(86, script.p2tr), (84, script.p2wpkh), (49, lambda p: script.p2sh(script.p2wpkh(p))), (44, script.p2pkh)]:
                output = encode(pub)
                vectors.append(dict(passphrase=phrase, path=path, branch=branch, type=kind, script=output.data.hex(), address=output.address()))
Path('TakebackTests/Fixtures/CustomPathVectors.json').write_text(json.dumps(vectors, indent=2) + '\n')
print(f'{len(vectors)} public vectors generated')
