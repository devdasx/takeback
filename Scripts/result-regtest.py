#!/usr/bin/env python3
"""Broadcast Prompt 07's signed public-test-key replacements on the isolated regtest node.
Never connects to public Bitcoin networks. Run only against the dedicated fixture node.
"""
import importlib.util, pathlib, json
root = pathlib.Path('/tmp/Takeback-Cancel-Regtest')
spec = importlib.util.spec_from_file_location('fixture', pathlib.Path(__file__).with_name('cancel-regtest.py'))
fixture = importlib.util.module_from_spec(spec); spec.loader.exec_module(fixture)
rpc = fixture.rpc
assert rpc('getblockchaininfo')['chain'] == 'regtest'
assert rpc('getconnectioncount') == 0
signed = json.loads((root/'Signed.json').read_text())
originals = {x['name']: x for x in json.loads((root/'Input.json').read_text())}
results = []
for item in signed:
    result = rpc('sendrawtransaction', item['raw'])
    assert result == item['txid']
    pending = rpc('getrawtransaction', result, True)
    assert pending.get('confirmations', 0) == 0
    assert originals[item['name']]['originalID'] not in rpc('getrawmempool')
    results.append({'name': item['name'], 'txid': result, 'returnedIDMatches': True, 'pendingConfirmations': 0, 'originalReplaced': True})
# The linked child's original was evicted along with its parent.
for child in originals['linked']['descendants']:
    assert child['txid'] not in rpc('getrawmempool')
for name in ['miner']:
    if name not in rpc('listwallets'): rpc('loadwallet', name)
address = rpc('getnewaddress', wallet='miner')
block = rpc('generatetoaddress', 1, address)[0]
for item in results:
    confirmed = rpc('getrawtransaction', item['txid'], True)
    assert confirmed['confirmations'] == 1
    item['confirmedConfirmations'] = confirmed['confirmations']
    item['blockhash'] = confirmed['blockhash']
report = {'network': 'regtest', 'peers': 0, 'coreVersion': rpc('getnetworkinfo')['subversion'], 'results': results, 'linkedChildEvicted': True, 'mainnetBroadcast': False}
pathlib.Path('Verification/Result/Regtest.json').write_text(json.dumps(report, indent=2))
print(json.dumps({'regtestBroadcasts': len(results), 'pendingToConfirmed': len(results), 'linkedChildEvicted': True}))
