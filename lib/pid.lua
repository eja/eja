-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaPidWrite(name,pid)
 if not pid then
  pid=ejaPid()
 end
 ejaFileWrite(eja.pathLock..'eja.pid.'..name,pid)
end


function ejaPidKill(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  if ejaKill(pid,9) == 0 then
   ejaFileRemove(eja.pathLock..'eja.pid.'..name)
   ejaTrace('[kill] %d %s',pid,name)
  end
 end
end


function ejaPidKillTree(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  local pidTable=ejaProcPidChildren(pid)
  if ejaKill(pid,9) == 0 then
   for k,v in next,pidTable do 
    ejaTrace('[ejaPidKillTree] kill %d',v)
    ejaKill(v,9) 
   end
   ejaFileRemove(eja.pathLock..'eja.pid.'..name)
   ejaTrace('[ejaPidKillTree] %d %s',pid,name)
  end
 end
end


function ejaPidKillTreeSub(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  local pidTable=ejaProcPidChildren(pid)
  for k,v in next,pidTable do 
   ejaTrace('[ejaPidKillTreeSub] kill %d',v)
   ejaKill(v,9) 
  end
 end
end


