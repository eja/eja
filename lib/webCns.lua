-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.help.webCns='cns timeout'


function ejaWebCns(web)
 local cnsData=''
 if web.path == "/library/test/success.html" or (web.headerIn['user-agent'] and web.headerIn['user-agent']:match('CaptiveNetworkSupport')) then	--ios
  cnsData=[[<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>]]
 end
 if web.path:match('generate_204') then	--android
  cnsData=ejaFileRead(eja.web.path..'/404.html')
  if cnsData and not cnsData:lower():match('wispaccessgatewayparam') then
   cnsData=[[<!--<?xml version='1.0' encoding='UTF-8'?><WISPAccessGatewayParam xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:noNamespaceSchemaLocation='WISPAccessGatewayParam.xsd'><Redirect><MessageType>100</MessageType><ResponseCode>0</ResponseCode><AccessProcedure>1.0</AccessProcedure><LoginURL>/404.html</LoginURL></Redirect></WISPAccessGatewayParam>-->]]..cnsData
  end
 end
 if cnsData ~= '' then
  if eja.opt.webCns then
   local cnsCheck=0
   local cnsPath=ejaSprintf('%s/eja.cns.log',eja.pathTmp)
   local cnsLog=ejaFileRead(cnsPath) or ''
   for time,ip,url in cnsLog:gmatch('([^ ]-) ([^ ]-) ([^\n]-)\n') do
    if (ip==web.remoteIp or url==web.path) and os.time()-time < ejaNumber(eja.opt.webCns) then cnsCheck=1 end
   end
   if cnsCheck > 0 then
    web.data=cnsData
   else
    ejaFileAppend(cnsPath,os.time()..' '..web.remoteIp..' '..web.path.."\n")
    web.data='CNS'
   end
  else
   web.data=cnsData
  end
  web.cns=1
 end
 return web
end
