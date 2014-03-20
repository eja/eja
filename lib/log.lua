-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaLog(level,message)
 local fd=io.open(eja.opt.logFile,'a')
 fd:write(os.date("%Y-%m-%d %T")..' '..level..' '..message..'\n')
 fd:close()
end


function ejaError(value,...)
 if ge(eja.opt.debug,1) then
  ejaLog("E",string.format(value,...))
 end
end


function ejaWarn(value,...)
 if ge(eja.opt.debug,2) then 
  ejaLog("W",string.format(value,...))
 end
end


function ejaInfo(value,...)
 if ge(eja.opt.debug,3) then 
  ejaLog("I",string.format(value,...))
 end
end


function ejaDebug(value,...)
 if ge(eja.opt.debug,4) then 
  ejaLog("D",string.format(value,...))
 end
end


function ejaTrace(value,...)
 if ge(eja.opt.debug,5) then 
  ejaLog("T",string.format(value,...))
 end
end


