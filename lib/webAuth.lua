-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaWebAuthHashCheck(key, path, ip, hash)
 local auth=-1;
 local path=path or "";
 local hash=hash or "";
 local key=key or "";
 local ip=ip or "";
 for i=10,5,-1 do
  timeN=ejaString(os.time()):sub(0, i);
  timeA=ejaNumber(timeN)-1;
  timeZ=ejaNumber(timeN)+1;
  if ejaSha256(key..ip..timeN..path) == hash or ejaSha256(key..ip..timeA..path) == hash or ejaSha256(key..ip..timeZ..path) == hash then
   auth=i-4;
   break;
  end
 end
 if auth < 1 and ejaSha256(key..ip..path) == hash then
  auth=1;
 end
 return auth;
end


function ejaWebAuthHashCreate(key, path, ip, power)
 local path=path or "";
 local key=key or "";
 local ip=ip or "";
 return ejaSha256(key..ip..ejaString(os.time()):sub(1, ejaNumber(power))..path);
end


function ejaWebAuth(web)
 local auth,path=web.path:match('^/('..string.rep('%x',64)..')(/.*)$');
 if auth and path then
  web.auth=-1;
  web.path=path;
  local powerMax=5;
  local authData=ejaFileRead(eja.pathEtc..'eja.web');
  local ip=web.remoteIp;
  if authData then
   for k,v in authData:gmatch('([%x]+) ?([0-9]*)\n?') do
    if ejaNumber(v) > powerMax then powerMax=v; end
    local value=ejaWebAuthHashCheck(k, path, ip, auth);
    if value > 0 then
     web.auth=value*v;
     web.authKey=k;
     break;
    end
   end
  end
 end
 return web
end

