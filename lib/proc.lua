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


