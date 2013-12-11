/* Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it> */

#include <stdio.h>
#include <string.h>
#include <math.h>
#include <wait.h>
#include <netdb.h>
#include <errno.h>
#include <dirent.h>
#include "lua.h"
#include "lauxlib.h"
#include "eja.h"


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

static int ejaSocketOpen(lua_State *L) {
 int domain=luaL_checknumber(L, 1);
 int type=luaL_checknumber(L, 2);
 int protocol=luaL_checknumber(L, 3);
 lua_pushinteger(L, socket(domain, type, protocol));
 return 1;
}

static int ejaSocketClose(lua_State *L) {
 int fd = luaL_checknumber(L, 1);
 lua_pushinteger(L, close(fd));
 return 1;
}

/* following functions from https://github.com/luaposix/luaposix/blob/master/ext/posix/posix.c */

/*
* POSIX library for Lua 5.1/5.2.
* (c) Reuben Thomas <rrt@sc3d.org> 2010-2013
* (c) Natanael Copa <natanael.copa@gmail.com> 2008-2010
* Clean up and bug fixes by Leo Razoumov <slonik.az@gmail.com> 2006-10-11
* Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br> 07 Apr 2006 23:17:49
* Based on original by Claudio Terra for Lua 3.x.
* With contributions by Roberto Ierusalimschy.
* With documentation from Steve Donovan 2012
*/

static int pusherror(lua_State *L, const char *info)
{
        lua_pushnil(L);
        if (info==NULL)
                lua_pushstring(L, strerror(errno));
        else
                lua_pushfstring(L, "%s: %s", info, strerror(errno));
        lua_pushinteger(L, errno);
        return 3;
}

static int pushresult(lua_State *L, int i, const char *info)
{
        if (i==-1)
                return pusherror(L, info);
        lua_pushinteger(L, i);
        return 1;
}


/* Push a new lua table populated with the fields describing the passed sockaddr */

static int sockaddr_to_lua(lua_State *L, int family, struct sockaddr *sa)
{
        char addr[INET6_ADDRSTRLEN];
        int port;
        struct sockaddr_in *sa4;
        struct sockaddr_in6 *sa6;

        switch (family)
        {
                case AF_INET:
                        sa4 = (struct sockaddr_in *)sa;
                        inet_ntop(family, &sa4->sin_addr, addr, sizeof addr);
                        port = ntohs(sa4->sin_port);
                        break;
                case AF_INET6:
                        sa6 = (struct sockaddr_in6 *)sa;
                        inet_ntop(family, &sa6->sin6_addr, addr, sizeof addr);
                        port = ntohs(sa6->sin6_port);
                        break;
        }

        lua_newtable(L);
        lua_pushnumber(L, family); lua_setfield(L, -2, "family");
        lua_pushnumber(L, port); lua_setfield(L, -2, "port");
        lua_pushstring(L, addr); lua_setfield(L, -2, "addr");
        return 1;
}

/* Populate a sockaddr_storage with the info from the given lua table */

static int sockaddr_from_lua(lua_State *L, int index, struct sockaddr_storage *sa, socklen_t *addrlen)
{
        struct sockaddr_in *sa4;
        struct sockaddr_in6 *sa6;
        int family, port;
        const char *addr;
        int r;

        memset(sa, 0, sizeof *sa);

        luaL_checktype(L, index, LUA_TTABLE);
        lua_getfield(L, index, "family"); family = luaL_checknumber(L, -1); lua_pop(L, 1);
        lua_getfield(L, index, "port"); port = luaL_checknumber(L, -1); lua_pop(L, 1);
        lua_getfield(L, index, "addr"); addr = luaL_checkstring(L, -1); lua_pop(L, 1);

        switch(family) {
                case AF_INET:
                        sa4 = (struct sockaddr_in *)sa;
                        r = inet_pton(AF_INET, addr, &sa4->sin_addr);
                        if(r == 1) {
                                sa4->sin_family = family;
                                sa4->sin_port = htons(port);
                                *addrlen = sizeof(*sa4);
                                return 0;
                        }
                        break;
                case AF_INET6:
                        sa6 = (struct sockaddr_in6 *)sa;
                        r = inet_pton(AF_INET6, addr, &sa6->sin6_addr);
                        if(r == 1) {
                                sa6->sin6_family = family;
                                sa6->sin6_port = htons(port);
                                *addrlen = sizeof(*sa6);
                                return 0;
                        }
                        break;
        }
        return -1;
}

static int Pconnect(lua_State *L)
{
        struct sockaddr_storage sa;
        socklen_t salen;
        int r;
        int fd = luaL_checknumber(L, 1);
        r = sockaddr_from_lua(L, 2, &sa, &salen);
        if(r == -1) return pusherror(L, "not a valid IPv4 dotted-decimal or IPv6 address string");

        r = connect(fd, (struct sockaddr *)&sa, salen);
        if(r < 0 && errno != EINPROGRESS) return pusherror(L, NULL);

        lua_pushboolean(L, 1);
        return 1;
}

static int Pbind(lua_State *L)
{
        struct sockaddr_storage sa;
        socklen_t salen;
        int r;
        int fd = luaL_checknumber(L, 1);
        r = sockaddr_from_lua(L, 2, &sa, &salen);
        if(r == -1) return pusherror(L, "not a valid IPv4 dotted-decimal or IPv6 address string");

        r = bind(fd, (struct sockaddr *)&sa, salen);
        if(r < 0) return pusherror(L, NULL);
        lua_pushboolean(L, 1);
        return 1;
}

static int Plisten(lua_State *L)
{
        int fd = luaL_checknumber(L, 1);
        int backlog = luaL_checkint(L, 2);

        return pushresult(L, listen(fd, backlog), NULL);
}

static int Paccept(lua_State *L)
{
        int fd_client;
        struct sockaddr_storage sa;
        unsigned int salen;

        int fd = luaL_checknumber(L, 1);

        salen = sizeof(sa);
        fd_client = accept(fd, (struct sockaddr *)&sa, &salen);
        if(fd_client == -1) {
                return pusherror(L, NULL);
        }

        lua_pushnumber(L, fd_client);
        sockaddr_to_lua(L, sa.ss_family, (struct sockaddr *)&sa);

        return 2;
}

static int Precv(lua_State *L)
{
        int fd = luaL_checkint(L, 1);
        int count = luaL_checkint(L, 2), ret;
        void *ud, *buf;
        lua_Alloc lalloc = lua_getallocf(L, &ud);

        /* Reset errno in case lalloc doesn't set it */
        errno = 0;
        if ((buf = lalloc(ud, NULL, 0, count)) == NULL && count > 0)
                return pusherror(L, "lalloc");

        ret = recv(fd, buf, count, 0);
        if (ret < 0) {
                lalloc(ud, buf, count, 0);
                return pusherror(L, NULL);
        }

        lua_pushlstring(L, buf, ret);
        lalloc(ud, buf, count, 0);
        return 1;
}

static int Precvfrom(lua_State *L)
{
        void *ud, *buf;
        socklen_t salen;
        struct sockaddr_storage sa;
        int r;
        int fd = luaL_checkint(L, 1);
        int count = luaL_checkint(L, 2);
        lua_Alloc lalloc = lua_getallocf(L, &ud);

        /* Reset errno in case lalloc doesn't set it */
        errno = 0;
        if ((buf = lalloc(ud, NULL, 0, count)) == NULL && count > 0)
                return pusherror(L, "lalloc");

        salen = sizeof(sa);
        r = recvfrom(fd, buf, count, 0, (struct sockaddr *)&sa, &salen);
        if (r < 0) {
                lalloc(ud, buf, count, 0);
                return pusherror(L, NULL);
        }

        lua_pushlstring(L, buf, r);
        lalloc(ud, buf, count, 0);
        sockaddr_to_lua(L, sa.ss_family, (struct sockaddr *)&sa);

        return 2;
}

static int Psend(lua_State *L)
{
        int fd = luaL_checknumber(L, 1);
        size_t len;
        const char *buf = luaL_checklstring(L, 2, &len);

        return pushresult(L, send(fd, buf, len, 0), NULL);
}

static int Psendto(lua_State *L)
{
        size_t len;
        struct sockaddr_storage sa;
        socklen_t salen;
        int r;
        int fd = luaL_checknumber(L, 1);
        const char *buf = luaL_checklstring(L, 2, &len);
        r = sockaddr_from_lua(L, 3, &sa, &salen);
        if(r == -1) return pusherror(L, "not a valid IPv4 dotted-decimal or IPv6 address string");

        r = sendto(fd, buf, len, 0, (struct sockaddr *)&sa, salen);
        return pushresult(L, r, NULL);
}

static int Psetsockopt(lua_State *L)
{
        int fd = luaL_checknumber(L, 1);
        int level = luaL_checknumber(L, 2);
        int optname = luaL_checknumber(L, 3);
        struct linger linger;
        struct timeval tv;
        struct ipv6_mreq mreq6;
        int vint = 0;
        void *val = NULL;
        socklen_t len = sizeof(vint);

        switch(level) {
                case SOL_SOCKET:
                        switch(optname) {
                                case SO_LINGER:
                                        linger.l_onoff = luaL_checknumber(L, 4);
                                        linger.l_linger = luaL_checknumber(L, 5);
                                        val = &linger;
                                        len = sizeof(linger);
                                        break;
                                case SO_RCVTIMEO:
                                case SO_SNDTIMEO:
                                        tv.tv_sec = luaL_checknumber(L, 4);
                                        tv.tv_usec = luaL_checknumber(L, 5);
                                        val = &tv;
                                        len = sizeof(tv);
                                        break;
                                default:
                                        break;
                        }
                        break;
                case IPPROTO_IPV6:
                        switch(optname) {
                                case IPV6_JOIN_GROUP:
                                case IPV6_LEAVE_GROUP:
                                        memset(&mreq6, 0, sizeof mreq6);
                                        inet_pton(AF_INET6, luaL_checkstring(L, 4), &mreq6.ipv6mr_multiaddr);
                                        val = &mreq6;
                                        len = sizeof(mreq6);
                                        break;
                                default:
                                        break;
                        }
                        break;
                case IPPROTO_TCP:
                        switch(optname) {
                                default:
                                        break;
                        }
                        break;
                default:
                        break;
        }

        /* Default fallback to int if no specific handling of type above */

        if(val == NULL) {
                vint = luaL_checknumber(L, 4);
                val = &vint;
                len = sizeof(vint);
        }

        return pushresult(L, setsockopt(fd, level, optname, val, len), NULL);
}

static int Pdir(lua_State *L)
{
        const char *path = luaL_optstring(L, 1, ".");
        DIR *d = opendir(path);
        if (d == NULL)
                return pusherror(L, path);
        else
        {
                int i;
                struct dirent *entry;
                lua_newtable(L);
                for (i=1; (entry = readdir(d)) != NULL; i++)
                {
                        lua_pushstring(L, entry->d_name);
                        lua_rawseti(L, -2, i);
                }
                closedir(d);
                lua_pushinteger(L, i-1);
                return 2;
        }
}

/* end of functions taken from https://github.com/luaposix/luaposix/blob/master/ext/posix/posix.c */


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

 lua_pushcfunction(L, ejaPid);		lua_setglobal(L, "ejaPid");
 lua_pushcfunction(L, ejaFork);		lua_setglobal(L, "ejaFork");
 lua_pushcfunction(L, ejaForkClean);	lua_setglobal(L, "ejaForkClean");
 lua_pushcfunction(L, ejaSocketOpen);	lua_setglobal(L, "ejaSocketOpen"); 
 lua_pushcfunction(L, ejaSocketClose);	lua_setglobal(L, "ejaSocketClose");
 lua_pushcfunction(L, Pconnect); 	lua_setglobal(L, "ejaSocketConnect");
 lua_pushcfunction(L, Pbind); 		lua_setglobal(L, "ejaSocketBind");
 lua_pushcfunction(L, Plisten); 	lua_setglobal(L, "ejaSocketListen");
 lua_pushcfunction(L, Paccept); 	lua_setglobal(L, "ejaSocketAccept");
 lua_pushcfunction(L, Precv); 		lua_setglobal(L, "ejaSocketRead");
 lua_pushcfunction(L, Psend); 		lua_setglobal(L, "ejaSocketWrite");
 lua_pushcfunction(L, Psetsockopt); 	lua_setglobal(L, "ejaSocketOptionSet");
 lua_pushcfunction(L, Pdir);	 	lua_setglobal(L, "ejaDirList");

 luaL_loadbuffer(L,luaBuf,sizeof(luaBuf),"ejaLua"); 
 lua_call(L,0,0);
 lua_close(L);   
}


