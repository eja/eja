-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>

eja.lib.shell='ejaShell'
eja.help.shell='interactive shell'


function ejaShell()
 while true do 
  io.stderr:write("> ");
  local ejaShellInput=io.read()
  if ejaShellInput and ejaShellInput ~= ".quit" then
   local ejaShellRun=loadstring(ejaShellInput)
   ejaShellRun()
  else 
   break
  end
 end
end
