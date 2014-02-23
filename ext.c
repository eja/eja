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

static int Pgetaddrinfo(lua_State *L)
{
        int r;
        int n = 1;
        struct addrinfo *res, *rp, *hints = NULL;
        const char *host = luaL_checkstring(L, 1);
        const char *service = lua_tostring(L, 2);

        memset(&hints, 0, sizeof hints);

        if(lua_type(L, 3) == LUA_TTABLE) {
                hints = alloca(sizeof *hints);
                lua_getfield(L, 3, "family"); hints->ai_family = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_getfield(L, 3, "flags"); hints->ai_flags = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_getfield(L, 3, "socktype"); hints->ai_socktype = lua_tonumber(L, -1); lua_pop(L, 1);
                lua_getfield(L, 3, "protocol"); hints->ai_protocol = lua_tonumber(L, -1); lua_pop(L, 1);
        }

        r = getaddrinfo(host, service, hints, &res);
        if(r != 0) {
                lua_pushnil(L);
                lua_pushstring(L, gai_strerror(r));
                lua_pushinteger(L, r);
                return 3;
        }

        /* Copy getaddrinfo() result into Lua table */

        lua_newtable(L);

        for (rp = res; rp != NULL; rp = rp->ai_next) {
                lua_pushnumber(L, n++);
                sockaddr_to_lua(L, rp->ai_family, rp->ai_addr);
                lua_pushnumber(L, rp->ai_socktype); lua_setfield(L, -2, "socktype");
                lua_pushstring(L, rp->ai_canonname); lua_setfield(L, -2, "canonname");
                lua_pushnumber(L, rp->ai_protocol); lua_setfield(L, -2, "protocol");
                lua_settable(L, -3);
        }

        freeaddrinfo(res);

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