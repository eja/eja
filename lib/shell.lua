-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>	


eja.lib.shell='ejaShell'	
eja.help.shell='interactive lua shell'	


function ejaShell()	
 if eja.opt.shell == '' then
  print("Lua 5.2 Interactive Shell");
  while true do 	
   io.stderr:write("> ");	
   local ejaShellInput=io.read()	
   if ejaShellInput and ejaShellInput ~= ".quit" then	
    loadstring(ejaShellInput)()	
   else 	
    break	
   end	
  end	
 else	
  loadstring(eja.opt.shell)()	
 end	
end