-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>

function ejaWebAuth(web)
 local auth=web.path:match('^/(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)/')  
 if auth then
  web.auth=-1
  web.path=web.path:sub(66)
  local authData=ejaFileRead(eja.pathEtc..'eja.web')
  local check=web.uri:sub(66)
  local powerMax=5
  for k,v in authData:gmatch('([%x]+) ?([0-9]*)\n?') do
   if ejaNumber(v) > powerMax then powerMax=ejaNumber(v) end
   if ejaSha256(k..web.remoteIp..check)==auth then 
    web.auth=1*v; 
    web.authKey=k;
    break
   elseif ejaSha256(k..web.remoteIp..(tostring(os.time()):sub(0,6)-1)..check)==auth then
    web.auth=2*v
    web.authKey=k;
    break
   elseif ejaSha256(k..web.remoteIp..(tostring(os.time()):sub(0,6)+1)..check)==auth then
    web.auth=2*v
    web.authKey=k;
    break
   elseif ejaSha256(k..web.remoteIp..(tostring(os.time()):sub(0,6)-0)..check)==auth then
    web.auth=3*v
    web.authKey=k;
    break
   elseif ejaSha256(k..web.remoteIp..(tostring(os.time()):sub(0,7)-0)..check)==auth then
    web.auth=4*v
    web.authKey=k;
    break
   elseif ejaSha256(k..web.remoteIp..(tostring(os.time()):sub(0,8)-0)..check)==auth then
    web.auth=5*v
    web.authKey=k;
    break
   end
  end
  if web.path:sub(-1) == "/" then
   if web.auth >= powerMax then
    ejaRun(web.opt)
    web.headerOut['Connection']='Close'
   else
    web.status='419 Authentication Timeout'
   end
  end
 end
 return web
end
