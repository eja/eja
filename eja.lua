-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>

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
 eja.pathTmp=eja.path..'/tmp/'
 eja.pathLock='/tmp/'
 eja.opt.debug=0
 eja.opt.logFile='/dev/stderr' 
 
else 

 t=ejaDirList(eja.path..'/lib/')
 if t then 
  local help=eja.help
  eja.helpFull={}
  for k,v in next,t do
   if v:match('.eja$') then
    eja.help={}
    ejaVmFileLoad(eja.path..'/lib/'..v)
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
   ejaVmFileLoad(arg[1])
  end
  ejaRun(eja.opt)
 else
  ejaHelp() 
 end
 
end
