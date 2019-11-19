-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib['help']='ejaHelp'

eja.lib.update='ejaLibraryUpdate'
eja.lib.install='ejaLibraryUpdate'
eja.lib.remove="ejaLibraryRemove"
eja.lib.setup='ejaSetup'
eja.lib.init='ejaInit'
eja.help.update='update library {self}'
eja.help.install='install library'
eja.help.remove='remove library'
eja.help.setup='system setup'
eja.help.init='load init configuration {eja.init}'


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
 local libFile
 if libName:match('^https?%://') then 
  ejaTrace('[eja] library check on: %s',libName)
  libFile=ejaWebGet(libName)
  libName=libName:match('^.+/(.+)%.eja$')
 else
  ejaTrace('[eja] library check on: github.com')  
  if ejaString(libName) ~= "" then gitName=libName else gitName="eja" end
  libFile=ejaWebGet('https://raw.githubusercontent.com/eja/%s/master/%s.eja',gitName,gitName)
  if ejaString(libFile) == "" then  
   ejaTrace('[eja] library check on: eja.it')     
   libFile=ejaWebGet('http://update.eja.it/?version=%s&lib=%s',eja.version,libName)
  end
 end
 if libName and libFile and #libFile>0 then 
  if not ejaFileStat(eja.pathLib) then ejaDirCreate(eja.pathLib) end
  if ejaFileWrite(eja.pathLib..libName..'.eja',libFile) then
   ejaInfo("[eja] library updated")
  else
   ejaError("[eja] library not updated")
  end
 else
  ejaWarn("[eja] library not found")
 end
end


function ejaLibraryRemove(libName)
 local libName=libName or eja.opt.remove or nil
 if libName and ejaFileRemove(eja.pathLib..libName..'.eja') then
  ejaInfo("[eja] library removed")
 else
  ejaWarn("[eja] library doesn't exist or cannot be removed")
 end
end


function ejaUpdate()
 ejaLibraryUpdate()
 ejaVmFileLoad(eja.pathLib..'.eja')
end


function ejaSetup()
 local webPath=eja.opt.webPath or eja.pathVar..'/web/'
 local webFile=webPath..'/index.eja'
 local webPort=eja.opt.webPort or 35248
 local webHost=eja.opt.webHost or '0.0.0.0'
 local etcFile=eja.pathEtc..'/eja.init'
 if not ejaFileStat(eja.pathBin) then ejaDirCreatePath(eja.pathBin) end
 if not ejaFileStat(eja.pathEtc) then ejaDirCreatePath(eja.pathEtc) end
 if not ejaFileStat(eja.pathLib) then ejaDirCreatePath(eja.pathLib) end  
 if not ejaFileStat(eja.pathVar) then ejaDirCreatePath(eja.pathVar) end  
 if not ejaFileStat(eja.pathTmp) then ejaDirCreatePath(eja.pathTmp) end  
 if not ejaFileStat(eja.pathLock) then ejaDirCreatePath(eja.pathLock) end
 if not ejaFileStat(webPath) then ejaDirCreatePath(webPath) end  
 if not ejaFileStat(etcFile) then
  ejaFileWrite(etcFile,ejaSprintf('eja.opt.web=1;\neja.opt.webPort=%s;\neja.opt.webHost="%s";\neja.opt.webPath="%s";\neja.opt.logFile="%s/eja.log";\neja.opt.logLevel=3;\n',webPort,webHost,webPath,eja.pathTmp))
  ejaInfo('[eja] init script installed')
 end
 if not ejaFileStat(webFile) then
  ejaFileWrite(webFile,'web=...;\nweb.data="<html><body><h1>eja! :)</h1></body></html>";\nreturn web;\n')
  ejaInfo('[eja] web demo installed')
 end
 if not ejaFileStat('/etc/systemd/system/eja.service') then
  ejaFileWrite('/etc/systemd/system/eja.service',string.format([[[Unit]
Description=eja init
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStart=%s/eja --init

[Install]
WantedBy=multi-user.target
]],eja.pathBin))

  ejaExecute('ln -s /etc/systemd/system/eja.service /etc/systemd/system/multi-user.target.wants/eja.service')
  ejaInfo('[eja] systemd installed')
 end
end


function ejaExecute(v,...)
 os.execute(string.format(v,...))
end


function ejaInit(file)
 local file=file or eja.opt.init or ''
 if ejaFileCheck(eja.pathEtc) then
  if file ~= '' then file='.'..file end
  if ejaFileCheck(eja.pathEtc..'/eja.init'..file) then
   ejaVmFileLoad(eja.pathEtc..'/eja.init'..file)
   eja.opt.init=nil
   ejaRun(eja.opt)
  else
   ejaError('[eja] init file not found')
  end
 end
end


function ejaModuleCheck(name)
 for _,x in next,(package.searchers or package.loaders) do 
  local check=x(name)
  if type(check) == "function" then return true end
 end

 return false
end


function ejaModuleLoad(name)
 if ejaModuleCheck(name) then
  return require(name)
 else
  return false
 end
end
