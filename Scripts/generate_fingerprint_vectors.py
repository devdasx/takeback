"""Public fixtures only. Reference: bip32==5.0.0 (python-bip32), Python hashlib.
Run in an isolated environment with bip32==5.0.0 installed. Never supply real secrets.
"""
import hashlib
import json
import unicodedata
from pathlib import Path
from bip32 import BIP32

mnemonic = 'abandon ' * 11 + 'about'
phrases = ['', 'TREZOR', ' TREZOR', 'TREZOR ', ' TREZOR ', 'trezor', ' ', 'café', 'cafe\u0301', '秘密🔑', 'a\x00b']
vectors = []
for phrase in phrases:
    seed = hashlib.pbkdf2_hmac('sha512', unicodedata.normalize('NFKD', mnemonic).encode(),
                               ('mnemonic' + unicodedata.normalize('NFKD', phrase)).encode(), 2048)
    root = BIP32.from_seed(seed)
    fp = hashlib.new('ripemd160', hashlib.sha256(root.pubkey).digest()).digest()[:4].hex().upper()
    vectors.append({'passphrase': phrase, 'fingerprint': fp})
output = {'reference': 'bip32 5.0.0; Python hashlib.pbkdf2_hmac, sha256, ripemd160; Unicode NFKD',
          'mnemonic': mnemonic, 'vectors': vectors}
Path('TakebackTests/Fixtures/FingerprintVectors.json').write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(vectors, ensure_ascii=False, indent=2))
