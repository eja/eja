-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>

if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.i18n={} 
 eja.mime={} 
 eja.mimeApp={}

 eja.lang='en'
 eja.path='/opt/eja.it/'
 eja.pathBin=eja.path..'/bin/'
 eja.pathEtc=eja.path..'/etc/'
 eja.pathLib=eja.path..'/lib/'
 eja.pathVar=eja.path..'/var/'
 eja.pathTmp='/tmp/'
 eja.pathLock='/tmp/'
 
 package.cpath=eja.pathLib..'?.so'
 
else 

 t=ejaDirList(eja.pathLib)
 if t then 
  local help=eja.help
  eja.helpFull={}
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
