-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.scan='ejaScan'
eja.help.scan='scanning script {a = matched pattern array}'
eja.help.scanPattern='scanning Lua pattern {%S+}'
eja.help.scanFile='scanning input file {stdin}'
eja.help.scanRecord='scanning input record separator {\\n}'


function ejaScan(script, pattern, file, record)
 local script=script or eja.opt.scanScript or eja.opt.scan or nil
 local pattern=pattern or eja.opt.scanPattern or '%S+'
 local record=record or eja.opt.scanRecord or '\n'
 local file=file or eja.opt.scanFile or '/dev/stdin'
 
 if script then 
  local fx=loadstring('local a=...;'..script)
  if fx then
   local fd=io.open(file)
   while fd do
    local row=''
    local c=''
    while c do
     c=fd:read(1)
     if c and (row..c):match(record..'$') then 
      break 
     else
      if c then 
       row=row..c 
      else
       fd:close()
       fd=nil
      end
     end
    end
    if row ~= '' then  
     local a={} 
     for v in row:gmatch('('..pattern..')') do table.insert(a,v) end
     fx(a)
    end
   end  
  end 
 end
end

