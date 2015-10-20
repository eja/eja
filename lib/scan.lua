-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.scan='ejaScan'
eja.help.scan='scanning script {R=record, F=fields}'
eja.help.scanPattern='scanning Lua pattern {%S+}'
eja.help.scanFile='scanning input file {stdin}'
eja.help.scanRecord='scanning input record separator {\\n}'


function ejaScan(script, pattern, file, record)
 local script=script or eja.opt.scanScript or eja.opt.scan or nil
 local pattern=pattern or eja.opt.scanPattern or '%S+'
 local record=record or eja.opt.scanRecord or '\n'
 local file=file or eja.opt.scanFile or '/dev/stdin'

 local tp,ts=script:match('^/(.+)/{?([^}]*)}?$')
 if tp then 
  pattern=tp 
  if #ts < 1 then ts='print(R)' end 
  script='if F and #F>0 then '..ts..' end' 
 end
 if s(script) == '' then script='print(R)' end
 local fx,fe=loadstring('local R,F=...;'..script)

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
   if row then
    local fields={} 
    for v in row:gmatch('('..pattern..')') do table.insert(fields,v) end
    fx(row,fields) 
   end
  end
 else
  print(fe)  
 end 
end

