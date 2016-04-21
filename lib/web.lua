-- Copyright (C) 2007-2016 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.web='ejaWeb'
eja.lib.webStart='ejaWebStart'
eja.lib.webStop='ejaWebStop'
eja.help.webStart='web server start'
eja.help.webStop='web server stopt'
eja.help.webPort='web server port {35248}'
eja.help.webHost='web server ip {0.0.0.0}'
eja.help.webPath='web server path {'..eja.pathVar..'/web/}'
eja.help.webSize='web buffer size {8192}'

function ejaWeb()
 eja.web={}
 eja.web.count=0
 eja.web.timeout=100
 eja.web.host=eja.opt.webHost or '0.0.0.0'
 eja.web.port=eja.opt.webPort or 35248
 eja.web.path=eja.opt.webPath or eja.pathVar..'/web/'

 ejaInfo("[web] daemon on port %d and path %s",eja.web.port, eja.web.path)
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
  end
  if web.headerIn['content-type'] and web.headerIn['content-type']:match('multipart%/form%-data') then 
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
    else
     web.path = web.path.."index.html" 
    end
   end
   local ext=web.path:match("([^.]+)$")
   web.headerOut['Content-Type']=eja.mime[ext]
   if ext == "eja" then web.headerOut['Content-Type']="application/eja" end
   if not web.headerOut['Content-Type'] then web.headerOut['Content-Type']="application/octet-stream" end
   if web.headerOut['Content-Type']=="application/eja" then
    local run=nil
    local file=ejaSprintf("%s%s",eja.web.path,web.path:sub(2))
    if ejaFileCheck(file) then
     web.headerOut['Content-Type']="text/html"
     local data=ejaFileRead(file)
     if data then
      loadstring(ejaVmImport(data) or data)(web)
     end
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
      web.file=''
      web.status='404 Not Found'
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
  local data=ejaFileRead(ejaSprintf('%s/%s.eja',eja.web.path,status))
  if data then 
   loadstring(ejaVmImport(data) or data)(web)
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
  
 web.response=web.protocolOut..' '..web.status..'\r\nDate: '..os.date()..'\r\nServer: eja '..eja.version..'\r\n'
 for k,v in next,web.headerOut do
  web.response=web.response..k..': '..v..'\r\n'
 end
 ejaSocketWrite(client,web.response..'\r\n')

 if web.file ~= '' then
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
 else
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


function ejaWebOpen(host,port)
 if ejaNumber(port) < 1 then port=80 end
 local res,err=ejaSocketGetAddrInfo(host, port, {family=AF_INET, socktype=SOCK_STREAM})    
 if res then
  local fd=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
  if fd and ejaSocketConnect(fd,res[1]) then
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_RCVTIMEO,5,0)
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_SNDTIMEO,5,0)
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
  ejaWebWrite(fd,ejaSprintf('GET /%s HTTP/1.1\r\nHost: %s\r\nUser-Agent: eja %s\r\nAccept: */*\r\nConnection: Close\r\n\r\n',path,host,eja.version))
  return fd
 else
  return nil
 end 
end


function ejaWebGet(value,...)
 local url=string.format(value,...)
 local t={}
 local fd=ejaWebGetOpen(url)
 if fd then
  while true do
   local buf=ejaWebRead(fd,1024)
   if not buf or #buf == 0 then break end
   t[#t+1]=buf
  end
  ejaWebClose(fd)
  local header,data=table.concat(t):match('(.-)\r?\n\r?\n(.*)')
  return data,header
 else
  return nil
 end
end


