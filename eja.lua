-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>

if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.meta={}
 eja.mime={} 
 eja.mimeApp={}

 eja.path=_eja_path or '/opt/eja.it/'
 if eja.path == '/' or not ejaFileStat(eja.path) then
  eja.path='/'
  eja.pathBin=eja.path..'/usr/bin/'
  eja.pathEtc=eja.path..'/etc/eja/'
  eja.pathLib=eja.path..'/usr/lib/eja/'
  eja.pathVar=eja.path..'/var/eja/'
  eja.pathTmp='/tmp/'
  eja.pathLock='/var/lock/'
 else
  eja.pathBin=eja.path..'/bin/'
  eja.pathEtc=eja.path..'/etc/'
  eja.pathLib=eja.path..'/lib/'
  eja.pathVar=eja.path..'/var/'
  eja.pathTmp='/tmp/'
  eja.pathLock='/tmp/'
 end
 
 package.cpath=eja.pathLib..'?.so;'..package.cpath
 
else 

 t=ejaDirList(eja.pathLib)
 if t then 
  local help=eja.help
  eja.helpFull={}
  table.sort(t)
  for k,v in next,t do
   if v:match('.eja$') then
    eja.help={}
    ejaVmFileLoad(eja.pathLib..v)
    eja.helpFull[v:sub(0,-5)]=eja.help
   end
  end
  eja.help=help
 end

 if #arg > 0 then
  for i in next,arg do
   if arg[i]:match('^%-%-') then
    local k=arg[i]:sub(3):gsub("-(.)",function(x) return x:upper() end)
    if not arg[i+1] or arg[i+1]:match('^%-%-') then 
     eja.opt[k]=''
    else
     eja.opt[k]=arg[i+1]   
    end
   end
  end
  if arg[1]:match('^[^%-%-]') then
   if ejaFileStat(arg[1]) then
    ejaVmFileLoad(arg[1])
   else
    ejaVmFileLoad(eja.pathBin..arg[1])
   end
  end
  ejaRun(eja.opt)
 else
  ejaHelp() 
 end
 
end
