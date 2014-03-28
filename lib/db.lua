-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaDbPath(name,id)
 local path=eja.path..'/var/'
 if name:match('^/') then
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


function ejaDbPut(name,data,id)
 return ejaFileWrite(ejaDbPath(name,id),data)
end


function ejaDbDel(name,id)
 return ejaFileRemove(ejaDbPath(name,id))
end


function ejaDbNew(name,data)
 local last=ejaDbLast(name)+1
 ejaFileWrite(ejaDbPath(name,last),data)
 return last
end


function ejaDbGet(name,id,search)
 local data=ejaFileRead(ejaDbPath(name,id))
 if data and search then
  return data:match(search)
 else 
  return false
 end
end


function ejaDbLast(name)
 local dir='./'
 local last=0
 local d=ejaDirList(dir)
 for k,v in next,d do
  local id=v:match('eja.'..name..'.([0-9]+)')
  if id and gt(id,last) then last=id end
 end
 return last
end


