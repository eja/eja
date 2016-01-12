MYLIBS := -O2 -ldl -Wl,-E -w
MYCFLAGS := "-DLUA_USE_POSIX -DLUA_USE_DLOPEN" 


all: eja

static:
	make MYCFLAGS="-DLUA_USE_POSIX" MYLIBS="-static -w"

lua/src/lua: lua
	cd lua/src && make generic CC=$(CC) MYCFLAGS=$(MYCFLAGS) MYLIBS="$(MYLIBS)"

lua:	
	git clone https://github.com/ubaldus/lua.git
	
eja.h:	lua lua/src/lua
	@od -v -t x1 eja.lua lib/*.lua eja.lua | awk '{for(i=2;i<=NF;i++){o=o",0x"$$i}}END{print"char luaBuf[]={"substr(o,2)"};";}' > eja.h
	
eja: eja.h 
	$(CC) -o eja eja.c lua/src/liblua.a -Ilua/src/ -lm $(MYLIBS) 
	@- rm eja.h	
	
clean:
	@- rm -f eja 
	@- rm -Rf lua
	
backup: clean
	tar zcR /opt/eja.it/src/ > /opt/eja.it/bkp/eja-$(shell cat .version).tar.gz
	
/opt/eja.it:
	@ mkdir -p /opt/eja.it/bin
	@ mkdir -p /opt/eja.it/lib
	@ mkdir -p /opt/eja.it/etc
	@ mkdir -p /opt/eja.it/var/web

/usr/bin/eja:
	@- ln -fs /opt/eja.it/bin/eja /usr/bin/eja

install: eja /opt/eja.it /usr/bin/eja
	@- cp eja /opt/eja.it/bin/eja

git:
	@ echo "eja.version='$(shell cat .version)'" > lib/version.lua
	@ git add .
	@- git commit
	@ git push

update: clean git backup
	scp /opt/eja.it/bkp/eja-$(shell cat .version).tar.gz ubaldu@frs.sourceforge.net:/home/frs/project/eja/		