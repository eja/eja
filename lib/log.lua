-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.opt.logFile='/dev/stderr'
eja.opt.logLevel=0
eja.help.logFile='log file {stderr}'
eja.help.logLevel='log level'


function ejaLog(level,message)
 local fd=io.open(eja.opt.logFile,'a')
 fd:write(os.date("%Y-%m-%d %T")..' '..level..' '..message..'\n')
 fd:close()
end


function ejaError(value,...)
 if ejaNumber(eja.opt.logLevel) >= 1 then
  ejaLog("E",ejaSprintf(value,...))
 end
end


function ejaWarn(value,...)
 if ejaNumber(eja.opt.logLevel) >= 2 then 
  ejaLog("W",ejaSprintf(value,...))
 end
end


function ejaInfo(value,...)
 if ejaNumber(eja.opt.logLevel) >= 3 then 
  ejaLog("I",ejaSprintf(value,...))
 end
end


function ejaDebug(value,...)
 if ejaNumber(eja.opt.logLevel) >= 4 then 
  ejaLog("D",ejaSprintf(value,...))
 end
end


function ejaTrace(value,...)
 if ejaNumber(eja.opt.logLevel) >= 5 then 
  ejaLog("T",ejaSprintf(value,...))
 end
end


