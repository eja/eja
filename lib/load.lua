-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.mime={} 
 eja.mimeApp={}
end


function ejaLoad()

 if not eja.load then 
  eja.load=1
 else
  eja.load=eja.load+1
 end

 if eja.path or eja.load ~= 3 then return end

 if not _G['ejaPid'] then
  if ejaModuleCheck("posix") then
   ejaRock()
  else
   print("Please use eja or install luaposix.")
   os.exit()
  end
 end

 eja.path=_eja_path or '/'
 eja.pathBin=eja.pathBin or eja.path..'/usr/bin/'
 eja.pathEtc=eja.pathEtc or eja.path..'/etc/eja/'
 eja.pathLib=eja.pathLib or eja.path..'/usr/lib/eja/'
 eja.pathVar=eja.pathVar or eja.path..'/var/eja/'
 eja.pathTmp=eja.pathTmp or eja.path..'/tmp/'
 eja.pathLock=eja.pathLock or eja.path..'/var/lock/'
 
 package.cpath=eja.pathLib..'?.so;'..package.cpath
 
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


ejaLoad();

