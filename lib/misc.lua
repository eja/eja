-- Copyright (C) 2007-2016 by Ubaldo Porcheddu <ubaldo@eja.it>


--!- deprecated
function n(i) return ejaNumber(i) end						
function s(v) return ejaString(v) end 						
function sf(...) return ejaSprintf(...) end					
function gt(a,b) a=a or 0; b=b or 0; return tostring(a)>tostring(b) end		
function lt(a,b) a=a or 0; b=b or 0; return tostring(a)<tostring(b) end	 	
function eq(a,b) a=a or 0; b=b or 0; return tostring(a)==tostring(b) end		
function ge(a,b) a=a or 0; b=b or 0; return tostring(a)>=tostring(b) end	
function le(a,b) a=a or 0; b=b or 0; return tostring(a)<=tostring(b) end	
--!

function _n(i) return ejaNumber(i) end						
function _s(v) return ejaString(v) end 						
function _f(...) return ejaSprintf(...) end					


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


function ejaTranslate(key,value,language) 			
 if key and value and language then
  if not eja.i18n[language] then eja.i18n[language]={} end
  eja.i18n[language][key]=value
 else
  if not language then language=eja.lang end
  if eja.i18n[language] and eja.i18n[language][key] then
   return eja.i18n[language][key]
  else
   return key
  end
 end
end


function ejaXmlEncode(str) 
 if str then 
  return string.gsub(str, "([^%w%s])", function(c) return string.format("&#x%02X;", string.byte(c)) end)
 else 
  return ""
 end
end


function ejaUrlDecode(url)
 return url:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end )
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


