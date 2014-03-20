-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.shell='ejaShell'
eja.help.shell='interactive shell'


function ejaShell()
 if eja.opt.shell == '' then
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
