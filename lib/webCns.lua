-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.help.webCns='cns timeout'


function ejaWebCns(web)
 local cnsData=''
 local mode=nil
 if web.path == "/library/test/success.html" or (web.headerIn['user-agent'] and web.headerIn['user-agent']:match('CaptiveNetworkSupport')) then	--ios
  mode='ios'
  cnsData=[[<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>]]
 end
 if web.path:match('generate_204') then	--android
  mode='android'
 end
 if mode then
  local wisp=[[<!--<?xml version='1.0' encoding='UTF-8'?><WISPAccessGatewayParam xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:noNamespaceSchemaLocation='WISPAccessGatewayParam.xsd'><Redirect><MessageType>100</MessageType><ResponseCode>0</ResponseCode><AccessProcedure>1.0</AccessProcedure><LoginURL>/407.html</LoginURL></Redirect></WISPAccessGatewayParam>-->]]
  local login=ejaFileRead(eja.web.path..'/407.html')

  if login and not login:lower():match('wispaccessgatewayparam') then
   login=wisp..login
  end

  if eja.opt.webCns then
   local cnsCheck=0
   local cnsPath=ejaSprintf('%s/eja.cns.log',eja.pathTmp)
   local cnsLog=ejaFileRead(cnsPath) or ''
   for time,ip,url in cnsLog:gmatch('([^ ]-) ([^ ]-) ([^\n]-)\n') do
    if (ip==web.remoteIp or url==web.path) and os.time()-time < ejaNumber(eja.opt.webCns) then cnsCheck=1 end
   end
   if cnsCheck > 0 then
    if mode == 'ios' then web.data=cnsData end
    if mode == 'android' then web.status='204 No Content' end
   else
    ejaFileAppend(cnsPath,os.time()..' '..web.remoteIp..' '..web.path.."\n")
    web.data=wisp
   end
  else
   web.data=wisp
  end
  web.cns=1
 end

 return web
end
