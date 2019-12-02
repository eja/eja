-- Copyright (C) 2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaRock()
 local fcntl  		= require 'posix.fcntl'
 local stat  		= require 'posix.sys.stat'
 local dirent 	 	= require 'posix.dirent'
 local unistd 		= require 'posix.unistd'
 local wait		= require 'posix.sys.wait'
 local signal		= require 'posix.signal'
 local sock		= require 'posix.sys.socket'
 
 function ejaFileStat(file)
  local a={}
  local fd=fcntl.open(file,fcntl.O_RDONLY)
  if fd then 
   local x=stat.fstat(fd)
   for k,v in next,x do a[k:sub(4)]=v end
   return a
  else
   return nil
  end
 end
 
 function ejaDirList(path)
  local x,files=pcall(dirent.dir,path)
  if x then 
   return files
  else
   return {}
  end
 end
 
 function ejaFork()
  return unistd.fork()
 end
 
 function ejaForkClean()
  return wait.wait(-1,WNOHANG)
 end
 
 function ejaPid()
  return unistd.getpid()
 end
 
 function ejaKill(pid,sig)
  return signal.kill(pid,sig)
 end
 
 function ejaSleep(t)
  return unistd.sleep(t)
 end
 
 function ejaDirCreate(path,mode) 
  if stat.mkdir(path,mode) == 0 then 
   return true
  else
   return nil
  end
 end
 
 function ejaSocketOpen(domain,type,protocol)
  return sock.socket(domain,type,protocol)
 end
 
 function ejaSocketClose(fd)
  return unistd.close(fd)
 end
 
 function ejaSocketListen(fd,backlog)
  if sock.listen(fd,backlog) == 0 then
   return true
  else
   return nil
  end
 end
 
 function ejaSocketConnect(fd,addr)
  if sock.connect(fd,addr) == 0 then 
   return true
  else
   return nil
  end
 end
 
 function ejaSocketBind(fd,addr)
  if sock.bind(fd,addr) == 0 then
   return true
  else
   return nil
  end
 end
 
 function ejaSocketAccept(fd)
  return sock.accept(fd) 
 end
 
 function ejaSocketRead(fd,count)
  return sock.recv(fd,count)
 end
 
 function ejaSocketWrite(fd,buffer)
  return sock.send(fd,buffer)
 end
 
 function ejaSocketGetAddrInfo(host,service,protocol)
  return sock.getaddringo(host,service,protocol)
 end
 
 function ejaSocketReceive(fd,count)
  return sock.recv(fd,count)
 end
 
 function ejaSocketSend(fd,buffer)
  return sock.send(fd,buffer)
 end
 
 function ejaSocketOptionSet(fd,level,optname,val,len)
  if len then 
   return sock.setsockopt (fd,level,optname,val,len)
  else
   return sock.setsockopt (fd,level,optname,val)
  end
 end
 
 for k,v in next,sock do
  if type(v) == "number" then _G[k]=v end
 end
 
end
