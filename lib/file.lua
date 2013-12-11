-- Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaFileCheck(f)
 local x=io.open(f,'r') --changes file access time...
 if x and x:read(1) then
  x:close()
  return true
 else
  return false
 end
end


function ejaFileRead(f)
 local x=io.open(f,'r') 
 local data=''
 if x then
  data=x:read('*a')
  x:close()
  return data
 else
  return false
 end
end


function ejaFileWrite(f,data)
 local x=io.open(f,'w') 
 if not data then data='' end
 if x then
  x:write(data)
  x:close()
  return true
 else
  return false
 end
end


function ejaFileSize(f)
 local fd=io.open(f,'r')
  if fd and fd:read(1) then
   size=fd:seek('end')
   fd:close()
   return size
  else
   return -1
  end
end
