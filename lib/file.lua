-- Copyright (C) 2007-2018 by Ubaldo Porcheddu <ubaldo@eja.it>


-- from eja.c
-- function ejaFileStat(p) end
-- function ejaDirList(d) end
-- function ejaDirCreate(d) end


function ejaFileCheck(f)
 if ejaFileStat(f) then
  return true
 else
  return false
 end
end


function ejaFileRead(f)
 local x=io.open(f,'r') 
 local data=''
 if x then
  data=x:read('*a')
  x:close()
  return data
 else
  return false
 end
end


function ejaFileWrite(f,data)
 local x=io.open(f,'w') 
 if not data then data='' end
 if x then
  x:write(data)
  x:close()
  return true
 else
  return false
 end
end


function ejaFileAppend(f,data)
 local x=io.open(f,'a')
 if x then
  x:write(data or '')
  return x:close()
 else
  return false
 end
end


function ejaFileSize(f)
 local fd=io.open(f,'r')
  if fd and fd:read(1) then
   size=fd:seek('end')
   fd:close()
   return size
  else
   return -1
  end
end


function ejaFileCopy(fileIn,fileOut)
 ejaExecute('cp "'..fileIn..'" "'..fileOut..'"')
end


function ejaFileRemove(f)
 return os.remove(f)
end


function ejaFileMove(old, new)
 ejaExecute('mv "'..old..'" "'..new..'"')
end


function ejaFileLoad(f)
 local ejaScriptRun=assert(loadfile(f))
 if ejaScriptRun then ejaScriptRun() end
end


function ejaDirListSort(d)	--sort alphabetically
 local t=ejaDirList(d)
 if type(t) == 'table' then 
  table.sort(t)
  return t
 else
  return false
 end
end


function ejaDirTable(d)		--return list as array
 local t=ejaDirList(d)
 local tt={}
 if t then 
  for k,v in next,t do
   if not v:match('^%.$') and not v:match('^%.%.$') then 
    tt[#tt+1]=v
   end
  end
 end 
 return tt
end


function ejaDirTableSort(d)	
 local t=ejaDirTable(d)
 table.sort(t)
 return t
end


function ejaDirListSafe(d)	--no hidden files
 local t=ejaDirList(d)
 local tt={}
 if t then 
  for k,v in next,t do
   if v:match('^[^.]') then 
    tt[#tt+1]=v
   end
  end
  return tt
 else
  return false
 end 
end


function ejaDirCreatePath(p)
 local path=''
 local r=false
 if not p:match('^/') then path='.' end
 for k in p:gmatch('[^/]+') do
  path=path..'/'..k
  if not ejaFileStat(path) then
   r=ejaDirCreate(path)
  end
 end
 return r
end


function ejaDirTree(path)
 local out=''
 for k,v in next,ejaDirTable(path) do
  local x=ejaFileStat(path..'/'..v) 
  if x then
   out=out..ejaSprintf('%10s %06o %s %s\n',x.mtime,x.mode,x.size,path..'/'..v)
   if ejaSprintf('%o',x.mode):sub(-5,1)=='4' then out=out..ejaDirTree(path..'/'..v) end
  end
 end
 return out
end
