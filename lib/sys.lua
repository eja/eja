-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib['help']='ejaHelp'

eja.lib.update='ejaUpdate'
eja.help.update='update system library'


function ejaHelp()      
 print(sf('Copyright: 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>\nVersion:   %s\nUsage:     eja [script] [options]\n',eja.version))
 if eja.opt.help and eja.opt.help == '' then eja.opt.help=nil end
 if not eja.opt.help or eja.opt.help == 'full' then
  for k,v in next,ejaTableKeys(ejaTableSort(eja.help)) do
   print(sf(' --%-16s %s',v:gsub("([%u])",function(x) return '-'..x:lower() end),eja.help[v]))
  end
  print(sf(' --%-16s this help','help'))
 end
 if eja.helpFull then
  if not eja.opt.help then print(sf(' --%-16s full help','help full')) end
  for k,v in next,eja.helpFull do
   if not eja.opt.help or eja.opt.help == 'full' then print(sf(' --%-16s %s help','help '..k,k)) end
   for kk,vv in next,ejaTableKeys(ejaTableSort(eja.helpFull[k])) do
    if eja.opt.help == 'full' or eja.opt.help == k then
     print(sf(' --%-16s %s',vv:gsub("([%u])",function(x) return '-'..x:lower() end),v[vv]))
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


function ejaUpdate(libName)
 if eja.opt.update ~= '' then libName=eja.opt.update end
 if not ejaFileStat(eja.pathLib) then ejaDirCreate(eja.pathLib) end
 if libName then
  x=ejaWebGet(sf('http://get.eja.it/?lib='..libName))
  if x and x~= '' then ejaFileWrite(eja.pathLib..libName..'.eja',x) end
 else 
  x=ejaWebGet(sf('http://get.eja.it/?action=update&version=%s&mac=%s&elf=%s',eja.version,ejaGetMAC(),ejaGetELF()))
  if x then
   loadstring(x)()
  end
 end
end


function ejaExecute(v,...)
 os.execute(string.format(v,...))
end
