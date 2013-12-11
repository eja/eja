-- Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>

eja.lib['shell']='ejaShell'
eja.help['shell']='interactive shell'

function ejaShell()
 while true do 
  io.write("> ");
  local input=io.read()
  if input and input ~= ".quit" then
   local x=loadstring(input)
   x()
  else 
   break
  end
 end
end
