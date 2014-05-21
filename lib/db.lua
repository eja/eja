-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaDbPath(name,id)
 local path=eja.path..'/var/'
 if name and name:match('^/') then
  path=path..name:gsub('/([^/]*)$','/eja.%1')
 else
  path=path..'db/eja.'..name
 end
 path=path:gsub('//','/')
 if not ejaFileStat(path) then 
  ejaDirCreatePath(path:gsub('[^/]-$','')) 
 end
 if id then path=path..'.'..id end
 return path
end


function ejaDbPut(name,id,...)
 local o=''
 local a=table.pack(...)
 for i=1,#a do
  o=o..tostring(a[i]):gsub('\t','eJaTaB')..'\t'
 end
 return ejaFileWrite(ejaDbPath(name,id),o)
end


function ejaDbDel(name,id)
 return ejaFileRemove(ejaDbPath(name,id))
end


function ejaDbNew(name,data)
 local last=ejaDbLast(name)+1
 ejaFileWrite(ejaDbPath(name,last),data)
 return last
end


function ejaDbGet(name,id,luaMatch)
 local data=ejaFileRead(ejaDbPath(name,id))
 if data then
  if luaMatch then
   return data:match(luaMatch)
  else
   local i=0
   local a={}
   for v in data:gmatch('([^\t]*)\t?') do
    if v then a[#a+1]=v:gsub('eJaTaB','\t') end
   end
   return table.unpack(a)
  end
 else 
  return false
 end
end


function ejaDbLast(name)
 local last=0
 local path=ejaDbPath(name):match('(.+)/') or ''
 local file=name:match('([^/]-)$') or '' or ''
 local d=ejaDirList(path) or {}
 for k,v in next,d do
  local id=v:match('eja.'..file..'.([0-9]+)')
  if id and gt(id,last) then last=id end
 end
 return last
end


