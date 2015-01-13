-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaProcCpuCount()
 local procCpuInfo=ejaFileRead('/proc/cpuinfo')
 local cpuCount=0
 if procCpuInfo then
  _,cpuCount=procCpuInfo:gsub('processor','')
 end
 return cpuCount
end


function ejaProcCpuSum()
 local procStat=ejaFileRead('/proc/stat')
 local procCpu=0
 if procStat then
  local user,nice,system,idle=procStat:match('[^%d]+ ([%d]+) ([%d]+) ([%d]+) ([%d]+)')
  procCpu=user+nice+system+idle
 end
 return procCpu
end


function ejaProcCpuSumPid(pid)
 local procPidStat=ejaFileRead('/proc/'..pid..'/stat')
 local procPidCpu=0
 local procPidName=''
 if procPidStat then
  local pid,comm,state,ppid,pgrp,session,tty_nr,tpgid,flags,minflt,cminflt,majflt,cmajflt,utime,stime,cutime,cstime=procPidStat:gsub(' +',' '):match('([^ ]+) ([^ ]+) ([^ ]) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)')
  procPidCpu=utime+stime
  procPidName=comm
 end
 return procPidCpu,procPidName
end


function ejaProcCpuCheck(name)
 local a={}
 local procPidList=ejaDirList('/proc/')
 a.sum=ejaProcCpuSum()
 a.time=os.time()
 for _,pid in next,procPidList do
  if pid:match('[%d]+') then
   local pidCpu,pidName=ejaProcCpuSumPid(pid)
   if pidName:match(name) then
    a[pid]=pidCpu
   end
  end
 end
 return a
end


function ejaProcPidChildren(pidCheck, count)
 if not count then count=5 else count=count-1 end
 if count < 1 then return {} end
 local a={}
 local procPidList=ejaDirList('/proc/')
 for _,pid in next,procPidList do
  if pid:match('[%d]+') then
   local data=ejaFileRead('/proc/'..pid..'/stat')
   if data then
    local pidParent=data:gsub(' +',' '):match('[^ ]+ [^ ]+ [^ ] ([^ ]+)')
    if pidParent and eq(pidParent,pidCheck) then
     a[#a+1]=pid
     local t1=ejaProcPidChildren(pid,count)
     if #t1 > 0 then
      for k,v in next,t1 do
       if not a[v] then a[#a+1]=v end
      end
     end
    end
   end
  end
 end
 return a
end


function ejaGetELF()
 local x=io.open('/proc/self/exe','r')
 local out=''
 if x then
  local data=x:read(24)
  if data then out=data:gsub("(.)",function(h) return sf('%02X',string.byte(h)) end ) end
  x:close()
 end
 return out
end


function ejaGetMAC(ip)
 local mac=""
 if ip then 
  local data=ejaFileRead('/proc/net/arp')
  if data then
   for aIp,aMac in data:gmatch('\n(%d+.%d+.%d+.%d+)%s+[^%s]+%s+[^%s]+%s+([^%s]*)') do
    if aIp==ip then mac=aMac; break; end
   end
  end 
 else
  local d=ejaDirListSort('/sys/class/net')
  if d and d[3] then
   if d[3] == 'lo' then d[3]=d[4] end
   mac=ejaFileRead('/sys/class/net/'..d[3]..'/address')
   if mac then mac=mac:gsub('\n','') end
  end
 end
 return mac
end


