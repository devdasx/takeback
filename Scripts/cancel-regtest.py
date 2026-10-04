#!/usr/bin/env python3
"""Isolated Bitcoin Core regtest fixture preparation and independent validation; never uses mainnet.
Start a fresh regtest node at /tmp/Takeback-Cancel-Regtest/node, RPC 18477, no peers.
Run prepare, CancelTests/testCoreRegtestSigning, then verify with its exported Signed.json.
Only the universally known test scalar 1 is imported into the disposable node.
"""
import json, pathlib, urllib.request, base64, sys, hashlib
ROOT=pathlib.Path('/tmp/Takeback-Cancel-Regtest')
def rpc(method,*params,wallet=None):
 cookie=(ROOT/'node/regtest/.cookie').read_text().strip()
 req=urllib.request.Request('http://127.0.0.1:18477/'+('wallet/'+wallet if wallet else ''),data=json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),headers={'Authorization':'Basic '+base64.b64encode(cookie.encode()).decode(),'Content-Type':'application/json'})
 try: obj=json.load(urllib.request.urlopen(req))
 except urllib.error.HTTPError as e: raise RuntimeError(e.read().decode()) from e
 if obj.get('error'): raise RuntimeError(obj['error'])
 return obj['result']
def b58(payload):
 b=payload+hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]; n=int.from_bytes(b,'big'); out=''; chars='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
 while n: n,r=divmod(n,58); out=chars[r]+out
 return out
def prepare():
 rpc('createwallet','miner'); rpc('createwallet','fixture',False,True)
 mine=rpc('getnewaddress',wallet='miner'); rpc('generatetoaddress',101,mine)
 key=(1).to_bytes(32,'big'); wif=b58(b'\xef'+key+b'\x01'); uncompressed=b58(b'\xef'+key)
 descriptors=[('taproot',86,f'tr({wif})',True),('native',84,f'wpkh({wif})',True),('nested',49,f'sh(wpkh({wif}))',True),('legacy',44,f'pkh({wif})',True),('legacyUncompressed',44,f'pkh({uncompressed})',False)]
 targets=[]
 for name,purpose,desc,compressed in descriptors:
  info=rpc('getdescriptorinfo',desc); checked=desc+'#'+info['checksum']
  assert rpc('importdescriptors',[{'desc':checked,'timestamp':'now'}],wallet='fixture')[0]['success']
  addr=rpc('deriveaddresses',checked)[0]; script=rpc('validateaddress',addr)['scriptPubKey']
  targets.append(dict(name=name,purpose=purpose,address=addr,script=script,compressed=compressed))
 cases=[]; funded=[]
 for name,selected,linked in [(t['name'],[t],False) for t in targets]+[('mixed',targets[:4],False),('linked',[targets[1]],True)]:
  funding=[]
  for t in selected:
   txid=rpc('sendtoaddress',t['address'],0.1,wallet='miner'); tx=rpc('getrawtransaction',txid,True)
   o=next(o for o in tx['vout'] if o['scriptPubKey']['hex']==t['script'])
   funding.append(dict(txid=txid,index=o['n'],value=10000000,purpose=t['purpose'],script=t['script'],compressed=t['compressed']))
  funded.append((name,funding,linked))
 rpc('generatetoaddress',1,mine)
 for name,funding,linked in funded:
  recipient=rpc('getnewaddress',wallet='miner'); total=len(funding)*10000000; value=total-1000
  raw=rpc('createrawtransaction',[{'txid':i['txid'],'vout':i['index'],'sequence':4294967293} for i in funding],{recipient:value/100000000},0)
  signed=rpc('signrawtransactionwithwallet',raw,wallet='fixture'); assert signed['complete']
  txid=rpc('sendrawtransaction',signed['hex']); tx=rpc('decoderawtransaction',signed['hex'])
  descendants=[]
  if linked:
   childraw=rpc('createrawtransaction',[{'txid':txid,'vout':0,'sequence':4294967293}],{mine:(value-1000)/100000000})
   child=rpc('signrawtransactionwithwallet',childraw,wallet='miner'); assert child['complete']
   childid=rpc('sendrawtransaction',child['hex']);descendants=[{'txid':childid,'fee':1000,'amount':value-1000,'recipient':mine}]
  cases.append(dict(name=name,originalID=txid,originalFee=1000,originalVSize=tx['vsize'],inputs=funding,descendants=descendants,height=rpc('getblockcount')))
 # Public REST-shaped fixture replies let the app exercise the full preparation/auth/sign path offline.
 responses={"blocks/tip/height":str(rpc('getblockcount')),"v1/fees/recommended":json.dumps({'fastestFee':30,'halfHourFee':20,'hourFee':10,'minimumFee':1})}
 def transaction(txid):
  tx=rpc('getrawtransaction',txid,True)
  responses['tx/'+txid+'/hex']=tx['hex']; responses['tx/'+txid+'/status']=json.dumps({'confirmed':False})
  inputs=[]
  for i in tx['vin']:
   if 'coinbase' in i: continue
   parent=rpc('getrawtransaction',i['txid'],True);responses['tx/'+i['txid']+'/hex']=parent['hex']
   prev=parent['vout'][i['vout']]
   inputs.append({'txid':i['txid'],'vout':i['vout'],'sequence':i['sequence'],'prevout':{'scriptpubkey':prev['scriptPubKey']['hex'],'scriptpubkey_address':prev['scriptPubKey'].get('address'),'value':round(prev['value']*100000000)}})
  outputs=[{'scriptpubkey':o['scriptPubKey']['hex'],'scriptpubkey_address':o['scriptPubKey'].get('address'),'value':round(o['value']*100000000)} for o in tx['vout']]
  responses['tx/'+txid]=json.dumps({'txid':txid,'vin':inputs,'vout':outputs,'fee':sum(i['prevout']['value'] for i in inputs)-sum(o['value'] for o in outputs),'weight':tx['weight'],'status':{'confirmed':False}})
  responses['tx/'+txid+'/outspends']=json.dumps([{'spent':False} for _ in outputs])
 for case in cases:
  transaction(case['originalID'])
  for child in case['descendants']:
   transaction(child['txid'])
   responses['tx/'+case['originalID']+'/outspends']=json.dumps([{'spent':True,'txid':child['txid'],'status':{'confirmed':False}}])
 (ROOT/'Responses.json').write_text(json.dumps(responses,indent=2))
 (ROOT/'Input.json').write_text(json.dumps(cases,indent=2))
 print(json.dumps({'regtest':True,'cases':len(cases),'height':rpc('getblockcount')}))
def verify():
 results=[]
 for case in json.loads(pathlib.Path(sys.argv[2] if len(sys.argv)>2 else ROOT/'Signed.json').read_text()):
  result=rpc('testmempoolaccept',[case['raw']])[0]
  results.append({'name':case['name'],'result':result})
  assert result['allowed'], result
 (ROOT/'Result.json').write_text(json.dumps(results,indent=2))
 print(json.dumps({'accepted':len(results),'regtest':True,'broadcastReplacements':False}))
if __name__=='__main__': prepare() if sys.argv[1]=='prepare' else verify()
