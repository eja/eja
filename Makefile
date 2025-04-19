prefix = /usr/local
bindir = $(prefix)/bin
sharedir = $(prefix)/share
mandir = $(sharedir)/man
man1dir = $(mandir)/man1

MYLIBS := -O2 -ldl -w
MYCFLAGS := "-DLUA_USE_POSIX -DLUA_USE_DLOPEN"

PKGCONFIG_LIBS = $(shell pkg-config --silence-errors --libs lua5.2)
PKGCONFIG_CFLAGS = $(shell pkg-config --silence-errors --cflags lua5.2)

ifdef EJA_PATH
 CFLAGS+="-DEJA_PATH=$(EJA_PATH)"
endif

ifdef EJA_PATH_BIN
 CFLAGS+="-DEJA_PATH_BIN=$(EJA_PATH_BIN)"
endif

ifdef EJA_PATH_ETC
 CFLAGS+="-DEJA_PATH_ETC=$(EJA_PATH_ETC)"
endif

ifdef EJA_PATH_LIB
 CFLAGS+="-DEJA_PATH_LIB=$(EJA_PATH_LIB)"
endif

ifdef EJA_PATH_VAR
 CFLAGS+="-DEJA_PATH_VAR=$(EJA_PATH_VAR)"
endif

ifdef EJA_PATH_TMP
 CFLAGS+="-DEJA_PATH_TMP=$(EJA_PATH_TMP)"
endif

ifdef EJA_PATH_LOCK
 CFLAGS+="-DEJA_PATH_LOCK=$(EJA_PATH_LOCK)"
endif



all: eja


static:
	make MYCFLAGS="-DLUA_USE_POSIX" MYLIBS="-static -w"

eja:
	@echo "eja.version='$(shell cat .version)'" > lib/version.lua
	@cat lib/load.lua lib/*.lua lib/load.lua | hexdump -v -e '1/1 "0x%02x,\n"' | awk 'BEGIN{printf "char luaBuf[]={"}{printf "%s",$$0}END{printf "0x0A};"}' > eja.h
ifeq ($(PKGCONFIG_LIBS),)	
	cd lua/src && make generic CC=$(CC) MYCFLAGS=$(MYCFLAGS) MYLIBS="$(MYLIBS)"
	$(CC) $(CFLAGS) $(CPPFLAGS) -g -o eja eja.c lua/src/liblua.a -Ilua/src/ -lm $(MYLIBS) $(LDFLAGS)
else
	$(CC) $(CFLAGS) $(CPPFLAGS) -g -o eja eja.c $(PKGCONFIG_CFLAGS) -lm $(MYLIBS) $(PKGCONFIG_LIBS) $(LDFLAGS)
endif
	
	
clean:
	@- rm -f eja eja.h
	@- rm -rf eja.dSYM
ifeq ($(PKGCONFIG_LIBS),)		
	@- cd lua && make clean
endif	


install: eja 
	@ install -d $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir)
	@ install eja $(DESTDIR)$(bindir)
	@ install doc/eja.1 $(DESTDIR)$(man1dir)

