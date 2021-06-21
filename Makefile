prefix = /usr/local
bindir = $(prefix)/bin
sharedir = $(prefix)/share
mandir = $(sharedir)/man
man1dir = $(mandir)/man1

MYLIBS := -O2 -ldl -Wl,-E -w
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

eja.lua: 
	@ echo "eja.version='$(shell cat .version)'" > lib/version.lua
	@ cat lib/load.lua lib/*.lua lib/load.lua > eja.lua
	
eja.eja: eja.lua
	@ eja --export eja.lua 
	
eja:	eja.lua
	@od -v -t x1 -A n -w1 eja.lua | awk 'BEGIN{printf"char luaBuf[]={"}{printf"0x%s,",$$1}END{printf"0x0A};";}' > eja.h
ifeq ($(PKGCONFIG_LIBS),)	
	cd lua/src && make generic CC=$(CC) MYCFLAGS=$(MYCFLAGS) MYLIBS="$(MYLIBS)"
	$(CC) $(CFLAGS) $(CPPFLAGS) -g -o eja eja.c lua/src/liblua.a -Ilua/src/ -lm $(MYLIBS) $(LDFLAGS)
else
	$(CC) $(CFLAGS) $(CPPFLAGS) -g -o eja eja.c $(PKGCONFIG_CFLAGS) -lm $(MYLIBS) $(PKGCONFIG_LIBS) $(LDFLAGS)
endif
	
	
clean:
	@- rm -f eja eja.h eja.lua eja.eja
ifeq ($(PKGCONFIG_LIBS),)		
	@- cd lua && make clean
endif	


install: eja 
	@ install -d $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir)
	@ install eja $(DESTDIR)$(bindir)
	@ install doc/eja.1 $(DESTDIR)$(man1dir)


git:	eja.lua eja.eja
	@ git add .
	@- git commit


update: clean git
	@ git push
	

release: clean git 
	make update
	tar zcR ../eja > /tmp/eja-$(shell cat .version).tar.gz
	scp /tmp/eja-$(shell cat .version).tar.gz ubaldu@frs.sourceforge.net:/home/frs/project/eja/		

