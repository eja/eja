/* Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it> */

#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/wait.h>
#include <netdb.h>
#include <errno.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <net/if.h>
#include <arpa/inet.h>
                     
#include "lua.h"
#include "lauxlib.h"
#include "eja.h"


static int eja_fork(lua_State *L) {
 lua_pushinteger(L, fork() );
 return 1;
}
        

static int eja_pid(lua_State *L) {
 lua_pushinteger(L, getpid() );  
 return 1;
}
        

static int eja_fork_clean(lua_State *L) {
 lua_pushinteger(L, waitpid(-1, NULL, WNOHANG) );  
 return 1;
}


static int eja_kill(lua_State *L) {
 pid_t pid=luaL_checknumber(L, 1);
 int sig=luaL_checknumber(L, 2); 
 lua_pushinteger(L, kill(pid, sig));
 return 1;
}


static int eja_sleep(lua_State *L) {
 lua_pushinteger(L,sleep(luaL_checknumber(L,1)));
 return 1; 
}


static int eja_dir_create(lua_State *L) {
 char *path=luaL_checkstring(L, 1);
 if (mkdir(path, S_IRUSR|S_IWUSR|S_IXUSR|S_IRGRP|S_IWGRP|S_IXGRP|S_IROTH|S_IXOTH) == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }
 return 1;
}


static int eja_dir_list(lua_State *L) {
 int i=1;
 DIR *dir;
 struct dirent *entry;
 char *path=luaL_checkstring(L, 1);

 dir=opendir(path);
 if (dir == NULL) {
  lua_pushnil(L);
 } else {
  lua_newtable(L);
  while( (entry=readdir(dir)) != NULL ) {
   lua_pushnumber(L, i++);
   lua_pushstring(L, entry->d_name);
   lua_settable(L, -3);
  }
  closedir(dir);
 }
 
 return 1;
}


static int eja_file_stat(lua_State *L) {
 struct stat s;
 char *path=luaL_checkstring(L, 1);
 if (stat(path,&s) == 0) {
  lua_newtable(L);
  lua_pushstring(L, "dev"); lua_pushnumber(L, s.st_dev); lua_settable(L, -3);
  lua_pushstring(L, "ino"); lua_pushnumber(L, s.st_ino); lua_settable(L, -3);
  lua_pushstring(L, "mode"); lua_pushnumber(L, s.st_mode); lua_settable(L, -3);
  lua_pushstring(L, "nlink"); lua_pushnumber(L, s.st_nlink); lua_settable(L, -3);
  lua_pushstring(L, "uid"); lua_pushnumber(L, s.st_uid); lua_settable(L, -3);
  lua_pushstring(L, "gid"); lua_pushnumber(L, s.st_gid); lua_settable(L, -3);
  lua_pushstring(L, "rdev"); lua_pushnumber(L, s.st_rdev); lua_settable(L, -3);
  lua_pushstring(L, "size"); lua_pushnumber(L, s.st_size); lua_settable(L, -3);
  lua_pushstring(L, "blksize"); lua_pushnumber(L, s.st_blksize); lua_settable(L, -3);
  lua_pushstring(L, "blocks"); lua_pushnumber(L, s.st_blocks); lua_settable(L, -3);
  lua_pushstring(L, "atime"); lua_pushnumber(L, s.st_atime); lua_settable(L, -3);
  lua_pushstring(L, "mtime"); lua_pushnumber(L, s.st_mtime); lua_settable(L, -3);
  lua_pushstring(L, "ctime"); lua_pushnumber(L, s.st_ctime); lua_settable(L, -3);
  return 1; 
 } else {
  lua_pushnil(L);
 }
 return 1;
}


// following functions are adapted from posix library at https://github.com/luaposix/luaposix/blob/master/ext/posix/posix.c


static int eja_socket_address_in(lua_State *L, int family, struct sockaddr *sa) {
 char addr[INET6_ADDRSTRLEN];
 int port;
 struct sockaddr_in *sa4;
 struct sockaddr_in6 *sa6;

 if (family == AF_INET6) {
  sa6=(struct sockaddr_in6 *)sa;
  inet_ntop(family, &sa6->sin6_addr, addr, sizeof addr);
  port=ntohs(sa6->sin6_port);
 } 
 if (family == AF_INET) {
  sa4=(struct sockaddr_in4 *)sa;
  inet_ntop(family, &sa4->sin_addr, addr, sizeof addr);
  port=ntohs(sa4->sin_port);
 }

 lua_newtable(L);
 lua_pushnumber(L, family); lua_setfield(L, -2, "family");
 lua_pushnumber(L, port); lua_setfield(L, -2, "port");
 lua_pushstring(L, addr); lua_setfield(L, -2, "addr");

 return 1;
}


static int eja_socket_address_out(lua_State *L, int index, struct sockaddr_storage *sa, socklen_t *addrlen) {
 struct sockaddr_in *sa4;
 struct sockaddr_in6 *sa6;
 int family, port;
 const char *addr;
 int r;

 memset(sa, 0, sizeof *sa);

 luaL_checktype(L, index, LUA_TTABLE);
 lua_getfield(L, index, "family"); family=luaL_checknumber(L, -1); lua_pop(L, 1);
 lua_getfield(L, index, "port"); port=luaL_checknumber(L, -1); lua_pop(L, 1);
 lua_getfield(L, index, "addr"); addr=luaL_checkstring(L, -1); lua_pop(L, 1);
 if (family == AF_INET6) {
  sa6=(struct sockaddr_in6 *)sa;
  r=inet_pton(AF_INET6, addr, &sa6->sin6_addr);
  if (r == 1) {
   sa6->sin6_family=family;
   sa6->sin6_port=htons(port);
   *addrlen=sizeof(*sa6);
   return 0;
  }
 }
 if (family == AF_INET) {
  sa4=(struct sockaddr_in *)sa;
  r=inet_pton(AF_INET, addr, &sa4->sin_addr);
  if (r == 1) {
   sa4->sin_family=family;
   sa4->sin_port=htons(port);
   *addrlen=sizeof(*sa4);
   return 0;
  }
 }  
 return -1;
}


static int eja_socket_open(lua_State *L) {
 int domain=luaL_checknumber(L, 1);
 int type=luaL_checknumber(L, 2);
 int protocol=luaL_checknumber(L, 3);
 lua_pushinteger(L, socket(domain, type, protocol));
 return 1;
}


static int eja_socket_close(lua_State *L) {
 int fd=luaL_checknumber(L, 1);
 lua_pushinteger(L, close(luaL_checknumber(L, 1)));
 return 1;
}


static int eja_socket_listen(lua_State *L) {
 int fd=luaL_checknumber(L, 1);
 int backlog=luaL_checkint(L, 2);
 if (listen(fd,backlog) == 0) {
  lua_pushboolean(L, 1);
 } else { 
  lua_pushnil(L);
 }
 return 1;
}


static int eja_socket_connect(lua_State *L) {
 struct sockaddr_storage sa;
 socklen_t salen;
 int r;
 int fd=luaL_checknumber(L, 1);
 
 eja_socket_address_out(L, 2, &sa, &salen);
 r=connect(fd, (struct sockaddr *)&sa, salen);
 if (r == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }

 return 1;
}


static int eja_socket_bind(lua_State *L) {
 struct sockaddr_storage sa;
 socklen_t salen;
 int r;
 int fd=luaL_checknumber(L, 1);
 
 eja_socket_address_out(L, 2, &sa, &salen);
 if (bind(fd, (struct sockaddr *)&sa, salen) == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }
 
 return 1;
}


static int eja_socket_accept(lua_State *L) {
 struct sockaddr_storage sa;
 unsigned int salen=sizeof(sa);
 int fdc;
 int fd=luaL_checknumber(L, 1);
 
 fdc=accept(fd, (struct sockaddr *)&sa, &salen);
 if (fdc >= 0) {
  lua_pushnumber(L, fdc);
  eja_socket_address_in(L, sa.ss_family, (struct sockaddr *)&sa);
  return 2;
 } else {
  lua_pushnil(L);
  return 1;
 }
}


static int eja_socket_read(lua_State *L) {
 int ret;
 int fd=luaL_checkint(L, 1);
 int count=luaL_checkint(L, 2);
 void *ud, *buf;
 lua_Alloc lalloc=lua_getallocf(L, &ud);

 if ( (buf=lalloc(ud, NULL, 0, count)) == NULL && count > 0) { 
  lua_pushnil(L);
 } else {
  ret=recv(fd, buf, count, 0);
  if (ret >= 0) {
   lua_pushlstring(L, buf, ret);
  } else {
   lua_pushnil(L);
  }
  lalloc(ud, buf, count, 0);
 }

 return 1;
}


static int eja_socket_write(lua_State *L) {
 size_t len;
 int r;
 int fd=luaL_checknumber(L, 1);
 const char *buf=luaL_checklstring(L, 2, &len);
 r=send(fd, buf, len, 0);
 if (r >= 0) {
  lua_pushnumber(L, r);
 } else {
  lua_pushnil(L);
 } 
 return 1;
}


static int eja_socket_get_addr_info(lua_State *L) {
 int r;
 int n=1;
 struct addrinfo *res, *rp, *hints=NULL;
 const char *host=luaL_checkstring(L, 1);
 const char *service=lua_tostring(L, 2);

 memset(&hints, 0, sizeof hints);
 hints=alloca(sizeof *hints);
 lua_getfield(L, 3, "family"); hints->ai_family=lua_tonumber(L, -1); lua_pop(L, 1);
 lua_getfield(L, 3, "flags"); hints->ai_flags=lua_tonumber(L, -1); lua_pop(L, 1);
 lua_getfield(L, 3, "socktype"); hints->ai_socktype=lua_tonumber(L, -1); lua_pop(L, 1);
 lua_getfield(L, 3, "protocol"); hints->ai_protocol=lua_tonumber(L, -1); lua_pop(L, 1);
 r=getaddrinfo(host, service, hints, &res);
 if(r != 0) {
  lua_pushnil(L);
 } else {
  lua_newtable(L);
  for (rp=res; rp != NULL; rp=rp->ai_next) {
   lua_pushnumber(L, n++);
   eja_socket_address_in(L, rp->ai_family, rp->ai_addr);
   lua_pushnumber(L, rp->ai_socktype); lua_setfield(L, -2, "socktype");
   lua_pushstring(L, rp->ai_canonname); lua_setfield(L, -2, "canonname");
   lua_pushnumber(L, rp->ai_protocol); lua_setfield(L, -2, "protocol");
   lua_settable(L, -3);
  }
  freeaddrinfo(res);
 }
 return 1;
}


static int eja_socket_receive(lua_State *L) {
 void *ud, *buf;
 socklen_t salen;
 struct sockaddr_storage sa;
 int r;
 int fd=luaL_checkint(L, 1);
 int count=luaL_checkint(L, 2);
 lua_Alloc lalloc=lua_getallocf(L, &ud);
 buf=lalloc(ud, NULL,0,count);
 salen=sizeof(sa);
 r=recvfrom(fd, buf, count, 0, (struct sockaddr *)&sa, &salen);
 if (r < 0) {
  lalloc(ud, buf, count, 0);
  lua_pushnil(L);
  return 1;
 } else {
  lua_pushlstring(L, buf, r);
  lalloc(ud, buf, count, 0);
  eja_socket_address_in(L, sa.ss_family, (struct sockaddr *)&sa);
  return 2; 
 }
}


static int eja_socket_send(lua_State *L) {
 size_t len;
 struct sockaddr_storage sa;
 socklen_t salen;
 int fd=luaL_checknumber(L, 1);
 const char *buf=luaL_checklstring(L, 2, &len);
 eja_socket_address_out(L, 3, &sa, &salen);
 lua_pushinteger(L, sendto(fd, buf, len, 0, (struct sockaddr *)&sa, salen));
 return 1;
}


static int eja_socket_option_set(lua_State *L) {
 int fd=luaL_checknumber(L, 1);
 int level=luaL_checknumber(L, 2);
 int optname=luaL_checknumber(L, 3);
 struct linger linger;
 struct timeval tv;
 struct ifreq ifr;
 struct ipv6_mreq mreq6;
 int vint=0;
 void *val=NULL;
 socklen_t len=sizeof(vint);

 if (level == SOL_SOCKET && optname == SO_LINGER) {
  linger.l_onoff=luaL_checknumber(L, 4);
  linger.l_linger=luaL_checknumber(L, 5);
  val=&linger;
  len=sizeof(linger);  
 }

 if (level == SOL_SOCKET && (optname == SO_RCVTIMEO || optname == SO_SNDTIMEO)) {
  tv.tv_sec=luaL_checknumber(L, 4);
  tv.tv_usec=luaL_checknumber(L, 5);
  val=&tv;
  len=sizeof(tv);
 }
 
 if (level == SOL_SOCKET && optname == SO_BINDTODEVICE) {
  strncpy(ifr.ifr_name, luaL_checkstring(L, 4), IFNAMSIZ);
  val = &ifr;
  len = sizeof(ifr);
 }

 if (level == IPPROTO_IPV6 && (optname == IPV6_JOIN_GROUP || optname == IPV6_LEAVE_GROUP)) {
  memset(&mreq6, 0, sizeof mreq6);
  inet_pton(AF_INET6, luaL_checkstring(L, 4), &mreq6.ipv6mr_multiaddr);
  val=&mreq6;
  len=sizeof(mreq6);
 }

 if (val == NULL) {
  vint=luaL_checknumber(L, 4);
  val=&vint;
  len=sizeof(vint);
 } 
 
 lua_pushinteger(L, setsockopt(fd, level, optname, val, len));
 
 return 1;
}


static int eja_socket_define(lua_State *L) {
 lua_pushnumber(L, AF_INET);		lua_setglobal(L, "AF_INET");
 lua_pushnumber(L, AF_INET6);		lua_setglobal(L, "AF_INET6");
 lua_pushnumber(L, SOCK_STREAM);	lua_setglobal(L, "SOCK_STREAM");
 lua_pushnumber(L, SOCK_DGRAM);		lua_setglobal(L, "SOCK_DGRAM");
 lua_pushnumber(L, SOL_SOCKET);		lua_setglobal(L, "SOL_SOCKET");
 lua_pushnumber(L, SO_REUSEADDR);	lua_setglobal(L, "SO_REUSEADDR");
 lua_pushnumber(L, SO_RCVTIMEO);	lua_setglobal(L, "SO_RCVTIMEO");
 lua_pushnumber(L, SO_SNDTIMEO);	lua_setglobal(L, "SO_SNDTIMEO");
 lua_pushnumber(L, SO_BINDTODEVICE);	lua_setglobal(L, "SO_BINDTODEVICE");
 lua_pushnumber(L, SO_BROADCAST);	lua_setglobal(L, "SO_BROADCAST");

 return 0;
}


int main (int argc, char **argv) { 
 int i; 
 lua_State *L=luaL_newstate();
 luaL_openlibs(L);
 lua_newtable(L);
 for (i=0; i<argc; i++) {
  lua_pushnumber(L, i);  
  lua_pushstring(L, argv[i]);
  lua_rawset(L, -3);
 }
 lua_setglobal(L, "arg");
 
 #ifdef _EJA_PATH
 #define xstr(s) str(s)
 #define str(s) #s
  lua_pushstring(L, xstr(_EJA_PATH) );
  lua_setglobal(L, "_eja_path");
 #endif   

 lua_pushcfunction(L, eja_pid);				lua_setglobal(L, "ejaPid");
 lua_pushcfunction(L, eja_fork);			lua_setglobal(L, "ejaFork");
 lua_pushcfunction(L, eja_fork_clean);			lua_setglobal(L, "ejaForkClean");
 lua_pushcfunction(L, eja_dir_create);			lua_setglobal(L, "ejaDirCreate");
 lua_pushcfunction(L, eja_dir_list);			lua_setglobal(L, "ejaDirList");
 lua_pushcfunction(L, eja_sleep); 			lua_setglobal(L, "ejaSleep");
 lua_pushcfunction(L, eja_file_stat); 			lua_setglobal(L, "ejaFileStat"); 
 lua_pushcfunction(L, eja_kill); 			lua_setglobal(L, "ejaKill"); 
 eja_socket_define(L);
 lua_pushcfunction(L, eja_socket_open);			lua_setglobal(L, "ejaSocketOpen"); 
 lua_pushcfunction(L, eja_socket_close);		lua_setglobal(L, "ejaSocketClose");
 lua_pushcfunction(L, eja_socket_connect);		lua_setglobal(L, "ejaSocketConnect");
 lua_pushcfunction(L, eja_socket_bind);			lua_setglobal(L, "ejaSocketBind");
 lua_pushcfunction(L, eja_socket_listen);		lua_setglobal(L, "ejaSocketListen");
 lua_pushcfunction(L, eja_socket_accept);		lua_setglobal(L, "ejaSocketAccept");
 lua_pushcfunction(L, eja_socket_read);			lua_setglobal(L, "ejaSocketRead");
 lua_pushcfunction(L, eja_socket_write);		lua_setglobal(L, "ejaSocketWrite");
 lua_pushcfunction(L, eja_socket_option_set);		lua_setglobal(L, "ejaSocketOptionSet"); 
 lua_pushcfunction(L, eja_socket_get_addr_info); 	lua_setglobal(L, "ejaSocketGetAddrInfo"); 
 lua_pushcfunction(L, eja_socket_receive);		lua_setglobal(L, "ejaSocketReceive"); 
 lua_pushcfunction(L, eja_socket_send); 		lua_setglobal(L, "ejaSocketSend"); 
 
 luaL_loadbuffer(L, luaBuf, sizeof(luaBuf), "ejaLua"); 
 lua_call(L,0,0);
 lua_close(L);   
}


