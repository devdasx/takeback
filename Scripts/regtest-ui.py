"""Local regtest-only XCUITest coordinator; the public fixture scalar 9 has no real funds."""
import json,base64,urllib.request,hashlib
from http.server import BaseHTTPRequestHandler,HTTPServer
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding,PublicFormat
def rpc(method,params=[]):
 # Legacy local-only RPC credential retained to keep the existing regtest server and all its clients compatible; not app branding.
 req=urllib.request.Request('http://127.0.0.1:52443/wallet/funder',json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),{'Authorization':'Basic '+base64.b64encode(b'unsend:regtest-only').decode()})
 data=json.load(urllib.request.urlopen(req));assert 'error' not in data,data;return data['result']
def mine():return rpc('generatetoaddress',[1,rpc('getnewaddress')])
def prepare():
 assert rpc('getblockchaininfo')['chain']=='regtest'
 mine()
 pub=ec.derive_private_key(9,ec.SECP256K1()).public_key().public_bytes(Encoding.X962,PublicFormat.CompressedPoint)
 script='0014'+hashlib.new('ripemd160',hashlib.sha256(pub).digest()).hexdigest()
 address=rpc('decodescript',[script])['address']
 txid=rpc('sendtoaddress',[address,0.001]);mine()
 tx=rpc('getrawtransaction',[txid,True]);index=next(v['n'] for v in tx['vout'] if v['scriptPubKey']['hex']==script)
 payload=b'\xef'+(9).to_bytes(32,'big')+b'\x01';payload+=hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]
 n=int.from_bytes(payload,'big');wif='';alphabet='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
 while n:n,r=divmod(n,58);wif=alphabet[r]+wif
 raw=rpc('createrawtransaction',[[{'txid':txid,'vout':index,'sequence':4294967293}],{rpc('getnewaddress'):0.000996}])
 signed=rpc('signrawtransactionwithkey',[raw,[wif],[{'txid':txid,'vout':index,'scriptPubKey':script,'amount':0.001}]])
 assert signed['complete'];rpc('sendrawtransaction',[signed['hex']]);return {'ready':True}
class Handler(BaseHTTPRequestHandler):
 def do_POST(self):
  try:
   assert rpc('getblockchaininfo')['chain']=='regtest'
   result=prepare() if self.path=='/prepare' else {'mined':len(mine())} if self.path=='/mine' else {'error':'unknown command'}
   self.send_response(200);self.end_headers();self.wfile.write(json.dumps(result).encode())
  except Exception as e:self.send_response(500);self.end_headers();self.wfile.write(str(e).encode())
 def log_message(self,*args):pass
HTTPServer(('127.0.0.1',52110),Handler).serve_forever()
