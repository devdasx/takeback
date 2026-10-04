"""Local deterministic protocol adversary. No wallet data or broadcast methods."""
import asyncio,json,ssl,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(root/'Regtest/tls/cert.pem',root/'Regtest/tls/key.pem')
async def handle(reader,writer,secondary=False):
 try:
  while line:=await reader.readline():
   value=json.loads(line);batch=isinstance(value,list);calls=value if batch else [value]
   if any(c['method']=='test.echo' for c in calls) and len(calls)>25:
    break
   if any(c['method']=='test.wait' for c in calls):
    await asyncio.sleep(30)
   out=[]
   for c in calls:
    m=c['method'];p=c.get('params',[]);r={'jsonrpc':'2.0','id':c['id']}
    if m=='server.version': r['result']=['Takeback test server','1.4']
    elif m=='server.ping':r['result']=None
    elif m=='blockchain.headers.subscribe':r['result']={'height':100,'hex':'00'*80}
    elif m=='blockchain.scripthash.get_history':r['result']=[]
    elif m=='test.item' and not secondary:r['error']={'code':1,'message':'history too large'}
    elif m.startswith('test.'):r['result']=p[0] if p else None
    else:r['error']={'code':-32601,'message':'method disabled in test server'}
    out.append(r)
   writer.write((json.dumps(list(reversed(out)) if batch else out[0])+'\n').encode());await writer.drain()
 except (ConnectionError,asyncio.CancelledError,ValueError):pass
 finally:writer.close();await writer.wait_closed()
async def main():
 servers=[await asyncio.start_server(lambda r,w:handle(r,w,False),'127.0.0.1',52102,ssl=ctx,limit=5000000),await asyncio.start_server(lambda r,w:handle(r,w,True),'127.0.0.1',52103,ssl=ctx,limit=5000000),await asyncio.start_server(lambda r,w:handle(r,w,False),'127.0.0.1',52104,limit=5000000)]
 await asyncio.gather(*(s.serve_forever() for s in servers))
asyncio.run(main())
