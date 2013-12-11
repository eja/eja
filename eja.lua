-- Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>

if not eja then

 eja={}; 
 eja.opt={}; 
 eja.lib={}; 
 eja.help={}; 
 eja.mime={}; 
 eja.mimeApp={};

 eja.path='/opt/eja.it/'
 eja.pathTmp='/tmp/'
 eja.lib['help']='ejaHelp'


 function ejaHelp()      
  ejaPrintf('Copyright: 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>\nVersion:   %s\nUsage:     eja [script] [options]\n',eja.version)
  for k,v in ipairs(getmetatable(ejaTableSort(eja.help))) do
   ejaPrintf(' --%-16s %s',v,eja.help[v])
  end
  ejaPrintf(' --%-16s this help\n','help')
 end 


 function ejaRun(opt)
  for k,v in pairs(opt) do
   if eja.lib[k] and type(_G[eja.lib[k]]) == 'function' then 
    _G[eja.lib[k]]()
   end 
  end
 end

else 

 if #arg > 0 then
  for i in ipairs(arg) do
   if arg[i]:match('^%-%-') then
    local k=arg[i]:sub(3)
    if not arg[i+1] or arg[i+1]:match('^%-%-') then 
     eja.opt[k]=''
    else
     eja.opt[k]=arg[i+1]   
    end
   end
  end
 
  if arg[1]:match('^[^%-%-]') then
   local file=arg[1]
   if not ejaFileCheck(file) then file=eja.path..'/lib/'..arg[1] end
   if not ejaFileCheck(file) then file=eja.path..'/lib/'..arg[1]..'.eja' end
   if ejaFileCheck(file) then 
    local x=assert(loadfile(file))
    if x then x() end
   end
  else
   ejaRun(eja.opt)
  end

 else
  ejaHelp() 
 end

end
