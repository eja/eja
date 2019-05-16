-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib['help']='ejaHelp'

eja.lib.update='ejaLibraryUpdate'
eja.lib.install='ejaLibraryUpdate'
eja.lib.remove="ejaLibraryRemove"
eja.help.update='update library'
eja.help.install="install library {systemd}"
eja.help.remove="remove library"


function ejaHelp()      
 ejaPrintf('Copyright: 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>\nVersion:   %s\nUsage:     eja [script] [options]\n',eja.version)
 if eja.opt.help and eja.opt.help == '' then eja.opt.help=nil end
 if not eja.opt.help or eja.opt.help == 'full' then
  for k,v in next,ejaTableKeys(ejaTableSort(eja.help)) do
   ejaPrintf(' --%-16s %s',v:gsub("([%u])",function(x) return '-'..x:lower() end),eja.help[v])
  end
  ejaPrintf(' --%-16s this help','help')
 end
 if eja.helpFull then
  if not eja.opt.help then ejaPrintf(' --%-16s full help','help full') end
  for k,v in next,eja.helpFull do
   if #k > 0 and (not eja.opt.help or eja.opt.help == 'full') then ejaPrintf(' --%-16s %s help','help '..k,k) end
   for kk,vv in next,ejaTableKeys(ejaTableSort(eja.helpFull[k])) do
    if eja.opt.help == 'full' or eja.opt.help == k then
     ejaPrintf(' --%-16s %s',vv:gsub("([%u])",function(x) return '-'..x:lower() end),v[vv])
    end
   end
  end
 end
 print('')
end 


function ejaRun(opt)
 for k,v in next,opt do
  if eja.lib[k] and type(_G[eja.lib[k]]) == 'function' then 
   _G[eja.lib[k]]()
  end 
 end
end


function ejaLibraryUpdate(libName)
 local libName=libName or eja.opt.update or eja.opt.install or ''
 if libName ~= '' then
  local libFile=ejaWebGet('http://update.eja.it/?version=%s&lib=%s',eja.version,libName)
  if libFile and #libFile>0 then 
   if not ejaFileStat(eja.pathLib) then ejaDirCreate(eja.pathLib) end
   if ejaFileWrite(eja.pathLib..libName..'.eja',libFile) then
    ejaPrintf("Library updated.")
   else
    ejaPrintf("Library not updated.")
   end
  else
   ejaPrintf("Library not found.")
  end
 else
  ejaInstall()
 end
end


function ejaLibraryRemove(libName)
 local libName=libName or eja.opt.remove or nil
 if libName and ejaFileRemove(eja.pathLib..libName..'.eja') then
  ejaPrintf("Library removed.")
 else
  ejaPrintf("Librarry doesn't exist or cannot be removed.")
 end
end


function ejaInstall()
 local webPath=eja.opt.webPath or eja.pathVar..'/web/'
 if not ejaFileStat(eja.pathBin) then ejaDirCreatePath(eja.pathBin) end
 if not ejaFileStat(eja.pathEtc) then ejaDirCreatePath(eja.pathEtc) end
 if not ejaFileStat(eja.pathLib) then ejaDirCreatePath(eja.pathLib) end  
 if not ejaFileStat(eja.pathVar) then ejaDirCreatePath(eja.pathVar) end  
 if not ejaFileStat(eja.pathTmp) then ejaDirCreatePath(eja.pathTmp) end  
 if not ejaFileStat(eja.pathLock) then ejaDirCreatePath(eja.pathLock) end
 if not ejaFileStat(webPath) then ejaDirCreatePath(webPath) end  

 ejaFileWrite(eja.pathEtc..'/eja.init',ejaSprintf([[
eja.opt.web=1
eja.opt.webPort=35248
eja.opt.webHost="0.0.0.0"
eja.opt.webPath="%s"
eja.opt.logFile="%s/eja.log"
eja.opt.logLevel=3
]],webPath,eja.pathTmp))

 ejaFileWrite(webPath..'/index.eja',[[
web=...
web.data=ejaSprintf('<html><body><h1>eja! :)</h1></body></html>')
return web
]])

 ejaFileWrite('/etc/systemd/system/eja.service',string.format([[[Unit]
Description=eja init
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStart=%s/eja %s/eja.init

[Install]
WantedBy=multi-user.target
]],eja.pathBin,eja.pathEtc))

 ejaExecute('ln -s /etc/systemd/system/eja.service /etc/systemd/system/multi-user.target.wants/eja.service')

end


function ejaExecute(v,...)
 os.execute(string.format(v,...))
end
