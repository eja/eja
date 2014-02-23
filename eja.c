/* Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it> */

#include <stdio.h>
#include <string.h>
#include <math.h>
#include <wait.h>
#include <netdb.h>
#include <errno.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
                     
#include "lua.h"
#include "lauxlib.h"
#include "eja.h"
#include "ext.c"


static int ejaFork(lua_State *L) {
 lua_pushinteger(L, fork() );
 return 1;
}
        

static int ejaPid(lua_State *L) {
 lua_pushinteger(L, getpid() );  
 return 1;
}
        

static int ejaForkClean(lua_State *L) {
 lua_pushinteger(L, waitpid(-1, NULL, WNOHANG) );  
 return 1;
}


static int ejaKill(lua_State *L) {
 pid_t pid=luaL_checknumber(L, 1);
 int sig=luaL_checknumber(L, 2); 
 lua_pushinteger(L, kill(pid, sig));
 return 1;
}

static int ejaSocketOpen(lua_State *L) {
 int domain=luaL_checknumber(L, 1);
 int type=luaL_checknumber(L, 2);
 int protocol=luaL_checknumber(L, 3);
 lua_pushinteger(L, socket(domain, type, protocol));
 return 1;
}


static int ejaSocketClose(lua_State *L) {
 int fd=luaL_checknumber(L, 1);
 lua_pushinteger(L, close(luaL_checknumber(L, 1)));
 return 1;
}


static int ejaSocketListen(lua_State *L) {
 int fd = luaL_checknumber(L, 1);
 int backlog = luaL_checkint(L, 2);
 if (listen(fd,backlog) == 0) {
  lua_pushboolean(L, 1);
 } else { 
  lua_pushnil(L);
 }
 return 1;
}


static int ejaSocketConnect(lua_State *L) {
 struct sockaddr_storage sa;
 socklen_t salen;
 int r;
 int fd = luaL_checknumber(L, 1);
 
 sockaddr_from_lua(L, 2, &sa, &salen);
 r=connect(fd, (struct sockaddr *)&sa, salen);
 if (r == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }

 return 1;
}


static int ejaSocketBind(lua_State *L) {
 struct sockaddr_storage sa;
 socklen_t salen;
 int r;
 int fd = luaL_checknumber(L, 1);
 
 sockaddr_from_lua(L, 2, &sa, &salen);
 if (bind(fd, (struct sockaddr *)&sa, salen) == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }
 
 return 1;
}


static int ejaSocketAccept(lua_State *L) {
 struct sockaddr_storage sa;
 unsigned int salen=sizeof(sa);
 int fdc;
 int fd = luaL_checknumber(L, 1);
 
 fdc=accept(fd, (struct sockaddr *)&sa, &salen);
 if (fdc >= 0) {
  lua_pushnumber(L, fdc);
  sockaddr_to_lua(L, sa.ss_family, (struct sockaddr *)&sa);
  return 2;
 } else {
  lua_pushnil(L);
  return 1;
 }
}


static int ejaSocketRead(lua_State *L) {
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


static int ejaSocketWrite(lua_State *L) {
 size_t len;
 int r;
 int fd=luaL_checknumber(L, 1);
 const char *buf = luaL_checklstring(L, 2, &len);
 r=send(fd, buf, len, 0);
 if (r >= 0) {
  lua_pushnumber(L, r);
 } else {
  lua_pushnil(L);
 } 
 return 1;
}


static int ejaSleep(lua_State *L) {
 lua_pushinteger(L,sleep(luaL_checknumber(L,1)));
 return 1; 
}


static int ejaDirCreate(lua_State *L) {
 char *path=luaL_checkstring(L, 1);
 if (mkdir(path, S_IRUSR|S_IWUSR|S_IXUSR|S_IRGRP|S_IWGRP|S_IXGRP|S_IROTH|S_IXOTH) == 0) {
  lua_pushboolean(L, 1);
 } else {
  lua_pushnil(L);
 }
 return 1;
}


static int ejaDirList(lua_State *L) {
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


static int ejaFileStat(lua_State *L) {
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


int main (int argc, char **argv) { 
 int i; 
 lua_State *L = luaL_newstate();
 luaL_openlibs(L);
 lua_newtable(L);
 for (i=0; i<argc; i++) {
  lua_pushnumber(L, i);  
  lua_pushstring(L, argv[i]);
  lua_rawset(L, -3);
 }
 lua_setglobal(L, "arg");

 lua_pushcfunction(L, ejaPid);			lua_setglobal(L, "ejaPid");
 lua_pushcfunction(L, ejaFork);			lua_setglobal(L, "ejaFork");
 lua_pushcfunction(L, ejaForkClean);		lua_setglobal(L, "ejaForkClean");
 lua_pushcfunction(L, ejaSocketOpen);		lua_setglobal(L, "ejaSocketOpen"); 
 lua_pushcfunction(L, ejaSocketClose);		lua_setglobal(L, "ejaSocketClose");
 lua_pushcfunction(L, ejaSocketConnect);	lua_setglobal(L, "ejaSocketConnect");
 lua_pushcfunction(L, ejaSocketBind);		lua_setglobal(L, "ejaSocketBind");
 lua_pushcfunction(L, ejaSocketListen);		lua_setglobal(L, "ejaSocketListen");
 lua_pushcfunction(L, ejaSocketAccept);		lua_setglobal(L, "ejaSocketAccept");
 lua_pushcfunction(L, ejaSocketRead);		lua_setglobal(L, "ejaSocketRead");
 lua_pushcfunction(L, ejaSocketWrite);		lua_setglobal(L, "ejaSocketWrite");
 lua_pushcfunction(L, ejaDirCreate);		lua_setglobal(L, "ejaDirCreate");
 lua_pushcfunction(L, ejaDirList);		lua_setglobal(L, "ejaDirList");
 lua_pushcfunction(L, ejaSleep); 		lua_setglobal(L, "ejaSleep");
 lua_pushcfunction(L, ejaFileStat); 		lua_setglobal(L, "ejaFileStat"); 
 lua_pushcfunction(L, ejaKill); 		lua_setglobal(L, "ejaKill"); 

 lua_pushcfunction(L, Psetsockopt); 		lua_setglobal(L, "ejaSocketOptionSet"); 
 lua_pushcfunction(L, Pgetaddrinfo); 		lua_setglobal(L, "ejaSocketGetAddrInfo"); 
 lua_pushcfunction(L, Precvfrom); 		lua_setglobal(L, "ejaSocketReceive"); 
 lua_pushcfunction(L, Psendto); 		lua_setglobal(L, "ejaSocketSend"); 

 luaL_loadbuffer(L,luaJIT_BC_eja,luaJIT_BC_eja_SIZE,"ejaLua"); 
 lua_call(L,0,0);
 lua_close(L);   
}


