-- Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaLog(value,...)
 print("LOG",string.format(value,...))
end


function ejaDebug(value,...)
 print("DBG",string.format(value,...))
end


function ejaWarn(msg)
end


function ejaInfo(msg)
end


function ejaSprintf(value,...)  
 local r="";
 local y=0; 
 local k,v="","";
 local a={};
 for k in string.gmatch(value,"%%[diouxXeEdfFgGaAcs]") do
  y=y+1;
  v=arg[y];
  if string.find("cdEefgGiouXx",string.sub(k,2),1,true) then
   if type(v) ~= "number" then v=tonumber(v); end
   if not v then v=0; end
  else
   if not v then v=""; end
   v=tostring(v);
  end
  arg[y]=v;
 end 

 return string.format(value,...);
end


function ejaPrintf(value,...)
 print(ejaSprintf(value,...))
end


function ejaPidWrite(name)
 local pid=ejaFileRead('/proc/self/stat'):match('([%d]+) ')
 ejaFileWrite(eja.path..'/var/tmp/'..name..'.pid',pid)
end


function ejaPidKill(name) 
 local pid=ejaFileRead(eja.path..'/var/tmp/'..name..'.pid')
 if pid and tonumber(pid) > 0 then execute('kill -9 %d',pid) end
end


function ejaXmlEncode(str) 
 if str then 
  return string.gsub(str, "([^%w%s])", function(c) return string.format("&#x%02X;", string.byte(c)) end)
 else 
  return ""
 end
end


function ejaTableSort(t)	--return array and sorted indexed array
 a={}
 for k,v in pairs(t) do
  table.insert(a,k)
 end
 table.sort(a)
 setmetatable(t,a)
 return t
end


function ejaUrlEscape(url)
 return url:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end )
end





-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

function ejaBase64Encode(data)
    b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function ejaBase64Decode(data)
    b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
