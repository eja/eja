-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaTableGet(array, index)
 local b=getmetatable(array)
 if index and index>0 then index=index-1 else index=0 end
 if index < 1 then index=nil end
 local _,key=next(b,index)
 return key,array[key]
end


function ejaTableAdd(array,key,value)
 if not array then array={} end
 local b=getmetatable(array) or {}
 if key then
  if not array[key] then b[#b+1]=key end
  array[key]=value
 end
 setmetatable(array,b)
 return array
end


function ejaTableLen(array)
 local i=0
 for k,v in next,array do i=i+1 end
 return i
end

