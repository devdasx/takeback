"""Generate public synthetic key vectors only. Never use any fixture with funds."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parents[1]
words=(root/'Takeback/Resources/BIP39/english.txt').read_text().split()
alphabet='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
order=int('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',16)
def check(payload):
 raw=payload+hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
 n=int.from_bytes(raw,'big'); out=''
 while n: n,d=divmod(n,58);out=alphabet[d]+out
 return '1'*(len(raw)-len(raw.lstrip(b'\0')))+out
def wif(n=1,compressed=True,version=128,flag=1):return check(bytes([version])+n.to_bytes(32,'big')+(bytes([flag]) if compressed else b''))
def extended(version=0x0488ade4,depth=0,n=1,fingerprint=0,child=0,marker=0):
 return check(version.to_bytes(4,'big')+bytes([depth])+fingerprint.to_bytes(4,'big')+child.to_bytes(4,'big')+bytes(range(32))+bytes([marker])+n.to_bytes(32,'big'))
def phrase(count):
 entropy=bytes(count*4//3);cs=count//3
 bits=''.join(f'{b:08b}' for b in entropy)+f'{hashlib.sha256(entropy).digest()[0]:08b}'[:cs]
 return ' '.join(words[int(bits[i:i+11],2)] for i in range(0,len(bits),11))
def mini(length):
 for i in range(100000):
  n=i; tail=''
  while n:n,d=divmod(n,58);tail=alphabet[d]+tail
  key='S'+'1'*(length-1-len(tail))+tail
  if hashlib.sha256((key+'?').encode()).digest()[0]==0:return key
 raise RuntimeError('No synthetic mini key')
v=[]
def add(id,input,kind,valid=False):v.append(dict(id=id,input=input,kind=kind,valid=valid))
add('empty','','empty');add('spaces',' \n\t ','empty')
for c in [12,15,18,21,24]:add(f'phrase-{c}',phrase(c),'phrase',True)
add('phrase-whitespace',' \n'+phrase(12).replace(' ',' \t\n')+'\n','phrase',True)
add('phrase-unicode-whitespace','\u3000'+phrase(12).replace(' ','\u00a0')+'\u2009','phrase',True)
add('phrase-uppercase',phrase(12).upper(),'phrase',True)
add('phrase-incomplete','abandon abandon abandon','incomplete')
add('phrase-too-many',' '.join(['abandon']*25),'incomplete')
add('phrase-checksum',' '.join(['abandon']*12),'invalid')
add('prompt-phrase','orbit velvet maple ranch silent ember harbor tiger candle wisdom fossil lunar','invalid')
add('wif-compressed','KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn','compressed',True)
add('wif-uncompressed',wif(compressed=False),'uncompressed',True)
add('wif-L',wif(n=order-1),'compressed',True)
add('wif-bad-checksum',wif()[:-1]+'2','invalid')
add('wif-bad-flag',wif(flag=2),'invalid')
add('wif-zero',wif(n=0),'invalid');add('wif-order',wif(n=order),'invalid')
for l in [22,26,30]:add(f'mini-{l}',mini(l),'mini',True)
add('mini-published','S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy','mini',True)
add('mini-bad-checksum','S'+('1'*21),'invalid')
add('mini-invalid-alphabet','S'+('0'*21),'invalid')
add('mini-bad-length','S'+('1'*22),'invalid')
for id,value in [('one',1),('order-minus-one',order-1)]:add('hex-'+id,f'{value:064x}','hex',True)
add('hex-prefix','0x'+f'{1:064x}','hex',True);add('hex-uppercase',f'{order-1:064X}','hex',True)
for id,text in [('zero','0'*64),('order',f'{order:064x}'),('too-big','f'*64),('short','1'*63),('long','1'*65),('not-hex','g'*64),('internal-space','1'*32+' '+'1'*32)]:add('hex-'+id,text,'invalid')
for prefix,version in [('xprv',0x0488ade4),('yprv',0x049d7878),('zprv',0x04b2430c)]:
 for depth in [0,3]:add(f'{prefix}-{depth}',extended(version,depth,child=0x80000002 if depth else 0),prefix,True)
for depth in [1,2,4,255]:add(f'extended-depth-{depth}',extended(depth=depth,child=1),'invalid')
add('extended-root-parent',extended(fingerprint=1),'invalid');add('extended-root-child',extended(child=1),'invalid')
add('extended-zero',extended(n=0),'invalid');add('extended-order',extended(n=order),'invalid');add('extended-public-marker',extended(marker=2),'invalid')
for prefix,version in [('xpub',0x0488b21e),('ypub',0x049d7cb2),('zpub',0x04b24746)]:add(prefix,extended(version=version,n=int('79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',16),marker=2),'public')
for id,text in [('address','1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'),('p2sh','3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy'),('bech32','BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4'),('descriptor','addr(1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa)'),('public-key','0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798')]:add(id,text,'public')
add('private-descriptor','wpkh('+wif()+')','invalid')
add('private-xprv-descriptor','wpkh('+extended()+'/0/*)','invalid')
add('testnet-c',wif(version=239),'testnet');add('testnet-9',wif(version=239,compressed=False),'testnet');add('testnet-tprv',extended(version=0x04358394),'testnet')
add('unknown','not a valid secret','invalid')
(root/'TakebackTests/Fixtures/KeyVectors.json').write_text(json.dumps(v,indent=2)+'\n')
previewids=['empty','phrase-12','phrase-incomplete','wif-compressed','wif-uncompressed','mini-published','hex-one','xprv-0','yprv-3','zprv-3','xpub','testnet-c','unknown','prompt-phrase']
preview=[next(x for x in v if x['id']==id) for id in previewids]
lines=['#if DEBUG','import SwiftUI','','/// Public synthetic fixtures. Never use these with funds.','enum EnterKeyFixtures {','    static let states: [(name: String, input: String)] = [']
lines += ['        ('+json.dumps(x['id'])+', '+json.dumps(x['input'])+'),' for x in preview]
lines += ['    ]','}','#endif']
(root/'Takeback/PreviewContent/EnterKeyFixtures.swift').write_text('\n'.join(lines)+'\n')
print(f'Generated {len(v)} independent vectors and {len(preview)} preview states.')
