-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


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
 ejaExecute('rm -f "'..f..'"')
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
