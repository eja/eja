-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaTable(t)
 if t and type(t) == "table" then 
  return t
 else
  return {}
 end
end


function ejaTableGet(array, index)
 local b=getmetatable(array)
 if index and index>0 then index=index-1 else index=0 end
 if index < 1 then index=nil end
 local _,key=next(b,index)
 return key,array[key]
end


function ejaTablePut(array, key, value, index)
 if not array then array={} end
 local b=getmetatable(array) or {}
 if key then
  if not array[key] then 
   if tonumber(index) then
    b[tonumber(index)]=key
   else 
    b[#b+1]=key 
   end
  end
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


function ejaTableMerge(old, new)
 if old and new and #new > 1 then
  for i=1,ejaTableLen(old) do
   k,v=ejaTableGet(old,i)
   ejaTablePut(old,k,new[i])
  end
  return true
 else
  return false
 end
end


function ejaTableSort(t)
 a={}
 for k,v in next,t do
  table.insert(a,k)
 end
 table.sort(a)
 setmetatable(t,a)
 return t
end


function ejaTableValues(t)
 local a={}
 for k,v in next,getmetatable(t) do
  a[#a+1]=t[v]
 end
 return a
end


function ejaTableKeys(t)
 local a={}
 for k,v in next,getmetatable(t) do
  a[#a+1]=v
 end
 return a
end

function ejaTableUnpack(a)
 return table.unpack(a)
end


function ejaTablePack(...)
 local a=table.pack(...)
 a['n']=nil
 return a
end
