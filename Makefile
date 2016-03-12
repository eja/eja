prefix = /usr/local
bindir = $(prefix)/bin
sharedir = $(prefix)/share
mandir = $(sharedir)/man
man1dir = $(mandir)/man1

MYLIBS := -O2 -ldl -Wl,-E -w
MYCFLAGS := "-DLUA_USE_POSIX -DLUA_USE_DLOPEN"

ifdef PREFIX
 CFLAGS+="-D_EJA_PATH=$(PREFIX)"
endif

all: eja

static:
	make MYCFLAGS="-DLUA_USE_POSIX" MYLIBS="-static -w"
	
eja.h:
	@od -v -t x1 eja.lua lib/*.lua eja.lua | awk '{for(i=2;i<=NF;i++){o=o",0x"$$i}}END{print"char luaBuf[]={"substr(o,2)"};";}' > eja.h
	
eja: eja.h 
	cd lua/src && make generic CC=$(CC) MYCFLAGS=$(MYCFLAGS) MYLIBS="$(MYLIBS)"
	$(CC) $(CFLAGS) -o eja eja.c lua/src/liblua.a -Ilua/src/ -lm $(MYLIBS) 
	@- rm eja.h	
	
clean:
	@- rm eja
	@- rm eja.h 
	@- cd lua && make clean
	
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
	@- git-dch -R -N $(shell cat .version)-1 --auto 
	make update
	tar zcR /opt/eja.it/src/ > /opt/eja.it/bkp/eja-$(shell cat .version).tar.gz
	scp /opt/eja.it/bkp/eja-$(shell cat .version).tar.gz ubaldu@frs.sourceforge.net:/home/frs/project/eja/		

deb: eja.h
	$(CC) $(CFLAGS) -o eja eja.c $(shell pkg-config --libs --cflags lua5.2) -lm $(MYLIBS)
	@- rm eja.h
	make install

