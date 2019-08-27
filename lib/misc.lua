-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaNumber(i) 
 return tonumber(i) or 0
end


function ejaString(v)
 if type(v) == "number" then 
  return tostring(v) 
 elseif type(v) == "string" then 
  return v 
 else 
  return "" 
 end
end


function ejaSprintf(...)
 return string.format(...)
end


function ejaPrintf(...)
 print(string.format(...))
end


function ejaXmlEncode(str) 
 if str then 
  return string.gsub(str, "([^%w%s])", function(c) return string.format("&#x%02X;", string.byte(c)) end)
 else 
  return ""
 end
end


function ejaUrlDecode(url)
 return ejaString(url):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end )
end


function ejaCheck(a,b)    
 if a then
  if b then
   if tonumber(b) then
    return tonumber(a) == tonumber(b)
   else 
    return tostring(a) == tostring(b)
   end
  else --b doesn't exist   
   if type(a) == "table" then
    local i=0;
    for k,v in next,a do i=i+1 end
    if i > 0 then 
     return true 
    else 
     return false
    end
   else
    if tonumber(a) then
     return tonumber(a) > 0
    else
     return a ~= ""
    end
   end 
  end  
 else  
  return false
 end
end 


function ejaOct2Dec(s)
 local z=0;
 for i=#s,1,-1 do
  z=z+tonumber(s:sub(i,i))*8^(#s-i)
 end
 return z;
end


function ejaReadLine(value,...)
 if value then 
  io.write(string.format(value,...)) 
 end
 return io.read('*l')
end


function ejaTime()
 local fd=io.popen('date +%N')
 local tm=ejaNumber(fd:read('*l'))
 fd:close()
 return os.time()+(tm/1000000000)
end
