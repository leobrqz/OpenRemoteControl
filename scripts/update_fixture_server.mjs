// Local source for managed Windows end-to-end tests; never used by production.
import { createServer } from 'node:http';
import { readFileSync, createReadStream, statSync } from 'node:fs';
import { resolve, basename } from 'node:path';
const [directory,configFile]=process.argv.slice(2);
createServer((request,response)=>{
  const config=JSON.parse(readFileSync(configFile,'utf8').replace(/^\uFEFF/,''));
  const filename=basename(new URL(request.url,'http://127.0.0.1').pathname);
  if(config.mode==='offline'||config.mode==='rateLimit'){
    response.writeHead(config.mode==='offline'?503:429);response.end('Fixture failure');return;
  }
  if(filename==='releases.win-x64.json'){
    if(config.mode==='missingFeed'){response.writeHead(404);response.end();return;}
    if(config.mode==='invalid'){response.end('{invalid json');return;}
    const feed=JSON.parse(readFileSync(resolve(directory,filename),'utf8').replace(/^\uFEFF/,''));
    if(config.mode==='space')feed.Assets[0].Size=2**60;
    response.setHeader('Content-Type','application/json');response.end(JSON.stringify(feed));return;
  }
  if(config.mode==='missingPackage'){response.writeHead(404);response.end();return;}
  const path=resolve(directory,filename);
  try{
    const size=statSync(path).size;
    response.setHeader('Content-Length',size);
    const stream=createReadStream(path,{highWaterMark:64*1024});
    if(config.mode==='truncated'){stream.once('data',chunk=>{response.write(chunk);stream.destroy();response.socket.destroy();});return;}
    if(config.mode==='corrupt'){response.end(Buffer.alloc(size,42));return;}
    if(config.mode==='slow'){
      stream.on('data',chunk=>{stream.pause();response.write(chunk);setTimeout(()=>stream.resume(),10);});stream.on('end',()=>response.end());
    }else stream.pipe(response);
  }catch{response.writeHead(404);response.end();}
}).listen(48790,'127.0.0.1');
