-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.web='ejaWeb'
eja.lib.webStart='ejaWebStart'
eja.lib.webStop='ejaWebStop'
eja.help.webStart='web server start'
eja.help.webStop='web server stop'
eja.help.webPort='web server port {35248}'
eja.help.webHost='web server ip {0.0.0.0}'
eja.help.webPath='web server path'
eja.help.webSize='web buffer size {8192}'
eja.help.webList='directory list mode [y/n] {n}'
eja.help.web='web server start in foreground {current path, directory list}'


function ejaWeb()
 eja.web={}
 eja.web.count=0
 eja.web.timeout=100
 eja.web.list=eja.opt.webList or nil
 eja.web.host=eja.opt.webHost or '0.0.0.0'
 eja.web.port=eja.opt.webPort or 35248
 eja.web.path=eja.opt.webPath or eja.pathVar..'/web/'

 if ejaString(eja.opt.webList) ~= "y" then 
  eja.web.list=false; 
 else 
  eja.web.list=true;
 end

 if eja.opt.web then
  if not eja.opt.webPath then eja.web.path="./"; end
  if ejaString(eja.opt.webList) ~= "n" then eja.web.list=true; end
 end

 ejaInfo("[web] daemon on port %d and path %s",eja.web.port, eja.web.path);
 ejaDebug("[web] host: %s, directory list: %s", eja.web.host, eja.web.list);

 local client=nil  
 local s=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
 ejaSocketOptionSet(s,SOL_SOCKET,SO_REUSEADDR,1) 
 ejaSocketBind(s,{ family=AF_INET, addr=eja.web.host, port=eja.web.port },0)
 ejaSocketListen(s,5) 
 while s do
  client,t=ejaSocketAccept(s)
  if client then
   eja.web.count=eja.web.count+1
   local forkPid=ejaFork()
   if forkPid and forkPid == 0 then 
    ejaSocketClose(s)
    while client do
     ejaSocketOptionSet(client,SOL_SOCKET,SO_RCVTIMEO,eja.web.timeout,0)
     if ejaWebThread(client,t.addr,t.port) < 1 then 
      break 
     end
    end
    ejaSocketClose(client)
    break
   else
    ejaSocketClose(client)
    ejaForkClean()
   end
  end
 end

end


function ejaWebStart(...)
 ejaWebStop()
 eja.pid.web=ejaFork()
 if eja.pid.web and eja.pid.web == 0 then
  ejaWeb(...)
 else
  ejaPidWrite(ejaSprintf('web_%d',eja.opt.webPort or 35248),eja.pid.web)
 end
end


function ejaWebStop()
 ejaPidKill(ejaSprintf('web_%d',tonumber(eja.opt.webStop) or eja.opt.webPort or 35248))
end


function ejaWebThread(client,ip,port)
 local web={}
 web.bufferSize=8192
 web.timeStart=os.time()
 web.socket=client
 web.remoteIp=ip or 'null'
 web.remotePort=tonumber(port) or 0
 web.method=''
 web.request=''
 web.postFile=''
 web.response=''
 web.auth=0
 web.data=''
 web.file=''
 web.query=''
 web.opt={}
 web.status='200 OK' 
 web.range=-1
 web.protocolOut='HTTP/1.1'
 web.headerIn={}
 web.headerOut={}
 web.headerOut['Content-Type']='text/html'
 web.headerOut['Connection']='Close'
 web.headerSent=false

 if ejaNumber(eja.opt.webSize) > 0 then web.bufferSize=ejaNumber(eja.opt.webSize) end
 
 local body=''
 local data=ejaSocketRead(client,web.bufferSize)
 if data then
  body=data:match('\r\n\r\n(.+)') or data:match('\n\n(.+)') or ''
  web.request=data:match('(.-)\r\n\r\n') or data:match('(.-)\n\n') or data
 end
 if web.request and web.request ~= '' then
  web.request=web.request:gsub('\r','')
  web.method,web.uri,web.protocolIn=web.request:match('(%w+) (.-) (.+)[\n]?')
  if web.uri then web.uri=web.uri:gsub('/+','/') end
  if web.method then
   web.method=web.method:lower()
   if web.request:match('\n.+') then
    for k,v in web.request:match('\n(.+)'):gmatch('(.-)%: ([^\n]+)') do
     local key=k:lower():gsub('\n','')
     local value=v:gsub('\n','')
     web.headerIn[key]=value
    end
   end
  end
 end
 if web.headerIn['connection'] and web.headerIn['connection']:lower() == 'keep-alive' then 
  if web.headerIn['user-agent'] and not web.headerIn['user-agent']:find('%(iP') then	--avoid iOS Keep-Alive bug
   web.headerOut['Connection']='Keep-Alive'
  end
 end
 
 if web.headerIn['range'] then 
  web.range=tonumber( web.headerIn['range']:match("=([0-9]+)") )
 end
 
 if web.uri then 
  web.path=web.uri:gsub("\\.\\.",""):match('([^?|#]+)')
  web.query=web.uri:match('%?([^#]+)') 
 end

 if web.method == 'post' and ejaNumber(web.headerIn['content-length']) > 0 then
  if web.headerIn['content-type']:match('application/x%-www%-form%-urlencoded') then 
   if ejaNumber(web.headerIn['content-length']) < web.bufferSize then
    while ejaNumber(web.headerIn['content-length']) > #body do
     local data=ejaSocketRead(client,web.bufferSize)
     if data then 
      body=body..data
     else
      break
     end     
    end
    web.query=body
   else
    web.status='413 Request Entity Too Large'
   end
  else
   web.postFile=eja.pathTmp..'eja.postFile-'..web.remoteIp:gsub('.','')..web.remotePort
   local fileLength=tonumber(web.headerIn['content-length'])
   local fd=io.open(web.postFile,'w')
   if body ~= '' then 
    fd:write(body) 
    fileLength=fileLength-#body
   end
   while fileLength > 0 do
    local data=ejaSocketRead(client,web.bufferSize)
    if data then
     fd:write(data)
     fileLength=fileLength-#data
    else
     break 
    end   
   end
   fd:close()
  end
 end
 
 --web query options
 if web.query and web.query ~= '' then
  web.query=web.query:gsub("&amp;", "&")
  web.query=web.query:gsub("&lt;", "<")
  web.query=web.query:gsub("&gt;", ">")
  web.query=web.query:gsub("+", " ")
  for k,v in web.query:gmatch('([^&=]+)=([^&=]*)&?') do
   web.opt[k]=ejaUrlDecode(v)
  end
 end
 
 --web path
 if web.path and web.path ~= '' then
  web=ejaWebAuth(web)
  if web.auth < 0 then
   web.status='401 Unauthorized'
  else
   if web.path:sub(-1) == "/" then 
    if ejaFileCheck(eja.web.path..web.path..'index.eja') then
     web.path = web.path.."index.eja" 
    elseif ejaFileCheck(eja.web.path..web.path..'index.lua') then
     web.path = web.path.."index.lua"
    else
     web.path = web.path.."index.html" 
    end
   end
   local ext=web.path:match("([^.]+)$")
   web.headerOut['Content-Type']=eja.mime[ext]
   if ext == "eja" then web.headerOut['Content-Type']="application/eja" end
   if ext == "lua" then web.headerOut['Content-Type']="application/lua" end
   if not web.headerOut['Content-Type'] then web.headerOut['Content-Type']="application/octet-stream" end
   if web.headerOut['Content-Type']=="application/eja" or web.headerOut['Content-Type']=="application/lua" then
    local run=nil
    local file=ejaSprintf("%s%s",eja.web.path,web.path:sub(2))
    if ejaFileCheck(file) then
     local data=ejaFileRead(file)
     if data then
      if web.headerOut['Content-Type']=="application/lua" then
       load(data)(web)
      else
       load(ejaVmImport(data))(web)
      end
     end
     web.headerOut['Content-Type']="text/html"
    else
     web.status='500 Internal Server Error'
    end
   elseif eja.mimeApp[web.headerOut['Content-Type']] then
    web=_G[eja.mimeApp[web.headerOut['Content-Type']]](web)
   else
    if eja.opt.webCns then web=ejaWebCns(web) end
    if not web.cns then
     web.file=ejaSprintf('%s/%s',eja.web.path,web.path)
     local stat=ejaFileStat(web.file)
     if stat then
      if ejaSprintf('%o',stat.mode):sub(-5,1)=='4' then 
       web.file=ejaSprintf('%s/%s/index.html',eja.web.path,web.path)
       if not ejaFileStat(web.file) then 
        web.file=nil
       else
        web.headerOut['Content-Type']="text/html"
       end
      end
     end
     if not stat or not web.file then
      if eja.web.list and (stat or web.file:match('index.html$')) then
	web.data=ejaWebList(eja.web.path, web.path);       
      else
       web.status='404 Not Found'
      end
      web.file=''  
     else
      web.headerOut['Cache-Control']='max-age=3600'
     end
    end
   end
      
  end
 else
  web.status='501 Not Implemented'  
  if os.time()-web.timeStart >= eja.web.timeout then
   web.status='408 Request Timeout'  
  end
 end

 --4XX
 if web.status:sub(1,1) == '4' then
  local status=web.status:sub(1,3)
  local file4xxPath=ejaSprintf('%s/%s',eja.web.path,status)
  if ejaFileStat(file4xxPath..'.eja') then
   load(ejaVmImport(ejaFileRead(file4xxPath..'.eja')))(web)
  elseif ejaFileStat(file4xxPath..'.lua') then
   loadfile(file4xxPath..'.lua')(web)
  elseif ejaFileCheck(ejaSprintf('%s/%s.html',eja.web.path,status)) then 
   web.status='301 Moved Permanently'
   web.headerOut['Location']=ejaSprintf('/%s.html',status)
  end
 end
 
 if web.file ~= '' then 
  web.headerOut['Content-Length'] = ejaFileSize(web.file)
  if web.headerOut['Content-Length'] < 1 then web.file='' end
 end
  
 if web.file == '' and web.data and #web.data then 
  web.headerOut['Content-Length'] = #web.data 
 end
 
 if web.range > 0 then
  web.headerOut['Content-Range']=ejaSprintf("bytes %d-%d/%d",web.range,web.headerOut['Content-Length']-1,web.headerOut['Content-Length'])
  web.headerOut['Content-Length']=web.headerOut['Content-Length']-web.range
  web.status='206 Partial Content'
 end
 
 if not web.headerOut['Content-Length'] or web.headerOut['Content-Length'] < 1 then
  web.headerOut['Content-Length']=nil
  web.headerOut['Content-Type']=nil
 end
 
 if web.status:sub(1,1) ~= '2' then web.headerOut['Connection']='Close' end
 
 if not web.headerSent then
  ejaSocketWrite(client,ejaWebHeader(web.headerOut,web.status,web.protocolOut))
 end

 if ejaString(web.file) ~= '' then
  local fd=io.open(web.file,'r')
  if fd then
   if web.range > 0 then 
    fd:seek('set',web.range) 
   end
   local data=''
   while data do
    data=fd:read(web.bufferSize)
    if data then 
     ejaSocketWrite(client,data)
    else
     break
    end
   end
   fd:close()
  end
 elseif ejaString(web.data) ~= '' then
  ejaSocketWrite(client,web.data)  
 end

 ejaDebug('[web] %s\t%s\t%s\t%s\t%s\t%s',web.remoteIp,web.status:match("[^ ]+"),os.time()-web.timeStart,web.headerOut['Content-Length'],web.auth,web.uri)
 ejaTrace('\n<--\n%s\n-->\n%s\n',web.request,web.response)
 
 if web.headerOut['Connection']=='Keep-Alive' then 
  return 1
 else 
  return 0
 end
end


function ejaWebOpen(host,port,timeout)
 timeout=timeout or 5
 if ejaNumber(port) < 1 then port=80 end
 local res,err=ejaSocketGetAddrInfo(host, port, {family=AF_INET, socktype=SOCK_STREAM})    
 if res then
  local fd=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
  if fd and ejaSocketConnect(fd,res[1]) then
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_RCVTIMEO,timeout,0)
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_SNDTIMEO,timeout,0)
   return fd
  end
 end
 return nil;
end


function ejaWebWrite(fd,value)
 return ejaSocketWrite(fd,value)
end


function ejaWebRead(fd,size)
 return ejaSocketRead(fd,size)
end


function ejaWebClose(fd)
 return ejaSocketClose(fd)
end


function ejaWebGetOpen(value,...)
 url=string.format(value,...)
 local protocol,host,port,path=url:match('(.-)://([^/:]+):?([^/]*)/?(.*)')
 if ejaNumber(port) < 1 then port=80 end
 local fd=ejaWebOpen(host,port)
 if fd then
  ejaWebWrite(fd,ejaSprintf('GET /%s HTTP/1.0\r\nHost: %s\r\nUser-Agent: eja %s\r\nAccept: */*\r\nConnection: Close\r\n\r\n',path,host,eja.version))
  return fd
 else
  return nil
 end 
end


function ejaWebGet(value,...)
 local url=string.format(value,...)
 local data=nil
 local header=nil
 if url:match('^https') then
  local file=ejaFileTmp()
  ejaExecute([[curl -s "%s" > %s]],url,file);
  data=ejaFileRead(file);
  if data then
   header="console: curl"
  else
   ejaExecute([[wget -qO %s "%s"]],file,url);
   data=ejaFileRead(file);
   if data then
    header="console: wget"
   end
  end
  if data then 
   ejaFileRemove(file)
  end
 else 
  local t={}
  local fd=ejaWebGetOpen(url)
  if fd then
   while true do
    local buf=ejaWebRead(fd,1024)
    if not buf or #buf == 0 then break end
    t[#t+1]=buf
   end
   ejaWebClose(fd)
   header,data=table.concat(t):match('(.-)\r?\n\r?\n(.*)')
  end
 end
 return data,header
end


function ejaWebHeader(header,status,protocol)
 local protocol=protocol or 'HTTP/1.1'
 local status=status or '200 OK'
 local header=header or {}
 local out=ejaSprintf('%s %s\r\nDate: %s\r\nServer: eja %s\r\n',protocol,status,os.date(),eja.version)
 header['Content-Type']= header['Content-Type'] or 'text/html'
 header['Connection']=header['Connection'] or 'Close'
 for k,v in next,header do
  out=out..k..': '..v..'\r\n'
 end
 return out..'\r\n'
end


function ejaWebSocketProxy(lHost, lPort, rHost, rPort, inMode, outMode, lTimeout, rTimeout)
 local bSize=8192 
 local lTimeout=lTimeout or 5
 local rTimeout=rTimeout or 100
 local inMode=inMode or '' or 'b64' or 'hex'
 local outMode=outMode or '' or 'b64' or 'hex'
 local lSocket=nil
 local rSocket=nil
 if lHost and lPort and rHost and rPort then
  local res,err=ejaSocketGetAddrInfo(rHost, rPort, {family=AF_INET, socktype=SOCK_STREAM})    
  if res then
   local rSocket=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
   if rSocket and ejaSocketConnect(rSocket,res[1]) then
    ejaSocketOptionSet(rSocket,SOL_SOCKET,SO_RCVTIMEO,lTimeout,0)
    ejaSocketOptionSet(rSocket,SOL_SOCKET,SO_SNDTIMEO,lTimeout,0)
    local s=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
    ejaSocketOptionSet(s,SOL_SOCKET,SO_REUSEADDR,1) 
    ejaSocketBind(s,{ family=AF_INET, addr=lHost, port=lPort },0)
    ejaSocketListen(s,lTimeout) 
    if s then
     while true do
      lSocket,t=ejaSocketAccept(s)
      if lSocket then
       ejaSocketOptionSet(lSocket,SOL_SOCKET,SO_RCVTIMEO,lTimeout,0)
       ejaSocketOptionSet(lSocket,SOL_SOCKET,SO_SNDTIMEO,lTimeout,0)
       local dataIn=ejaSocketRead(lSocket,bSize)
       if dataIn then 
        local query=dataIn:match("^GET /%?([^ ]+) ") 
        if query then
         if inMode=='b64' then 
          local tmp=ejaBase64Decode(query); query=tmp;
         end
         if inMode=='hex' then
          local tmp,_=query:gsub("..",function(x)return string.char(tonumber(x,16)) end); query=tmp; 
         end
         ejaSocketWrite(rSocket,query) 
        end
       end
       local dataOut=ejaSocketRead(rSocket,bSize) or ""
       if outMode=='b64' then local tmp=ejaBase64Encode(dataOut); dataOut=tmp; end
       if outMode=='hex' then local tmp=dataOut:gsub(".",function(x)return string.format("%02X",string.byte(x)) end); dataOut=tmp; end
       ejaSocketWrite(lSocket,'HTTP/1.0 200 OK\r\nDate: '..os.date()..'\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: '..#dataOut..'\r\nConnection: close\r\n\r\n'..dataOut) 
      end
      ejaSocketClose(lSocket)
     end
    end
    ejaSocketClose(rSocket)
   end
  end
 end
end


function ejaWebList(pathLocal, pathWeb)
 local a={}
 local path=pathLocal..ejaString(pathWeb):gsub("index.html$","")..("/"):gsub("//","");
 
 a[#a+1]='<html><body><ul>\n';
 for k,v in next,ejaDirTableSort(path) do
  local file=(path.."/"..v):gsub("//","/"):gsub("//","/"):gsub("//","/"); 
  if ejaDirCheck(file) then v=v..'/'; end
  a[#a+1]=ejaSprintf('<li><a href="%s">%s</a></li>\n',v,v);
 end
 a[#a+1]='</ul></body></html>';

 return table.concat(a);
end
