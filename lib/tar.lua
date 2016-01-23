-- Copyright (C) 2007-2016 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaUntar(fileIn, dirOut)
 local i=-1
 local size=512
 local path=""
 local fd=io.open(fileIn, "r")
 if fd then 
  i=0
  if dirOut then 
   path=dirOut..'/' 
   if not ejaDirList(path) then
    if not ejaDirCreatePath(path) then 
     i=-2
    end
   end
  end
  while i >= 0 do
   local block=fd:read(size)
   if not block then 
    break
   else
    local h={}
    h.name=path..block:sub(1,100):match('^[^%z]*')
    h.mode=block:sub(101,108):match('^[^%z]*')
    h.type=ejaNumber(block:sub(157,157))
    h.size=ejaOct2Dec(block:sub(125,136):match('^[^%z]*'))
    h.time=ejaOct2Dec(block:sub(137,148):match('^[^%z]*'))	--?
    h.link=block:sub(158,257):match('^[^%z]*')
    if h.name ~= path then
     ejaTrace('[untar] %s %11s %s %s %s %s %s', fileIn, h.size, h.time, h.mode, h.type, h.name, h.link)
    end
    if h.type == 5 then		--dir
     ejaDirCreatePath(h.name)
     ejaExecute('chmod %s %s',h.mode,h.name)
    elseif h.type == 2 then	--symlink
     ejaExecute('ln -s %s %s', h.link, h.name)
    elseif h.size > 0 then	--anything else
     local data=fd:read(math.ceil(h.size/size)*size)
     if data and #data > 0 then 
      data=data:sub(1,h.size)
      ejaFileWrite(h.name,data)
      ejaExecute('chmod %s %s',h.mode,h.name)
     end
    end
    i=i+1
   end
  end
  fd:close()
 end

 return i
end

