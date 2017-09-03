-- Copyright (C) 2007-2017 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.mime.taz='application/taz'
eja.mimeApp[eja.mime.taz]='ejaWebTaz'
eja.help.webTaz='taz max size {65535}'


function ejaWebTazList(size)
 local a={}
 for k,v in next,ejaDirTable(eja.pathTmp) do
  if v:match('^eja.taz.') then 
   local stat=ejaFileStat(eja.pathTmp..'/'..v)
   a[#a+1]={ ["name"]=v:sub(9), ["size"]=stat.size, ["time"]=stat.mtime }
  end
 end
 table.sort(a,function(l,r) return l.time>r.time end)
 for k,v in next,a do
  size=size-v.size
  if size < 0 then
   a[k]=nil
   ejaFileRemove(eja.pathTmp..'/eja.taz.'..v.name)
  end  
 end 
 return a
end


function ejaWebTaz(web)
 web.data=''
 web.headerOut['Content-Type']='application/json'
 if eja.opt.webTaz then
  local size=tonumber(eja.opt.webTaz) or 65535
  local js=ejaWebTazList(size)
  local file=web.path:match("^/(.-).taz$")
  if file=="" or file=='index' then
   web.data=ejaJsonEncode(js)
  else
   if ejaString(web.query) ~= "" or ejaString(web.postFile) ~= "" then
    local fileName=ejaSha256(file)
    local filePath=eja.pathTmp..'/eja.taz.'..fileName
    local fileLength=#web.query
    if ejaString(web.postFile) ~= "" then
     local stat=ejaFileStat(web.postFile)
     if stat and ejaNumber(stat.size) > size then
      web.status='413 Request Entity Too Large'
     else
      ejaFileMove(web.postFile,filePath)
     end
    else
     ejaFileWrite(filePath,web.query)         
    end    
    local stat=ejaFileStat(filePath)
    if stat then
     web.data=ejaJsonEncode(ejaWebTazList(size))
    else
     web.status='500 Internal Server Error'
    end
   else
    for k,v in next,js do
     if v.name == file then
      web.file=eja.pathTmp..'/eja.taz.'..file
     end
    end
    if ejaString(web.file) == "" then
     web.status='404 Not Found'
    end
   end
  end
 else
  web.status='501 Not Implemented'
 end
 return web
end
