prefix = /usr/local
bindir = $(prefix)/bin
sharedir = $(prefix)/share
mandir = $(sharedir)/man
man1dir = $(mandir)/man1

MYLIBS := -O2 -ldl -Wl,-E -w
MYCFLAGS := "-DLUA_USE_POSIX -DLUA_USE_DLOPEN"

PKGCONFIG_LIBS = $(shell pkg-config --silence-errors --libs lua5.2)
PKGCONFIG_CFLAGS = $(shell pkg-config --silence-errors --cflags lua5.2)

ifdef PREFIX
 CFLAGS+="-D_EJA_PATH=$(PREFIX)"
endif


all: eja


static:
	make MYCFLAGS="-DLUA_USE_POSIX" MYLIBS="-static -w"
	
	
eja: 
	@od -v -t x1 eja.lua lib/*.lua eja.lua | awk '{for(i=2;i<=NF;i++){o=o",0x"$$i}}END{print"char luaBuf[]={"substr(o,2)"};";}' > eja.h
ifeq ($(PKGCONFIG_LIBS),)	
	cd lua/src && make generic CC=$(CC) MYCFLAGS=$(MYCFLAGS) MYLIBS="$(MYLIBS)"
	$(CC) $(CFLAGS) -o eja eja.c lua/src/liblua.a -Ilua/src/ -lm $(MYLIBS) 
else
	$(CC) $(CFLAGS) -o eja eja.c $(PKGCONFIG_CFLAGS) -lm $(MYLIBS) $(PKGCONFIG_LIBS)
endif
	
	
clean:
	@- rm eja
	@- rm eja.h 
ifeq ($(PKGCONFIG_LIBS),)		
	@- cd lua && make clean
endif	


install: eja 
	@ install -d $(DESTDIR)$(bindir) $(DESTDIR)$(man1dir)
	@ install eja $(DESTDIR)$(bindir)
	@ install doc/eja.1 $(DESTDIR)$(man1dir)


git:
	@ echo "eja.version='$(shell cat .version)'" > lib/version.lua
	@ git add .
	@- git commit


update: clean git
	@ git push
	

release: clean git 
	make update
	tar zcR /opt/eja.it/src/ > /tmp/eja-$(shell cat .version).tar.gz
	scp /tmp/eja-$(shell cat .version).tar.gz ubaldu@frs.sourceforge.net:/home/frs/project/eja/		

