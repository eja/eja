CC=gcc
CFLAGS=-w
LIBS=-lm -ldl

all: eja

luajit-2.0: 
	@ git clone http://luajit.org/git/luajit-2.0.git 

luajit-2.0/src/luajit: luajit-2.0
	@ cd luajit-2.0 && make

eja.h: luajit-2.0 luajit-2.0/src/luajit
	@ echo "eja.version='"$$(($(shell date +%y) - $(shell date +%y -d @1190014200)))$(shell date +.%m%d.%H%M)"'" > lib/version.lua
	@ cat eja.lua lib/*.lua eja.lua > eja.raw
	@ cd luajit-2.0/src/ && ./luajit -bg ../../eja.raw ../../eja.h
	
eja: eja.h 
	@ $(CC) $(CFLAGS) -o eja eja.c luajit-2.0/src/libluajit.a -Iluajit-2.0/src/ $(LIBS)
	@ rm eja.h
	
clean:
	@ -rm eja eja.h eja.raw
	
uninstall: clean
	@ -rm -Rf luajit-2.0
	@ -rm /opt/eja.it/bin/eja
	@ -rm /usr/bin/eja

backup:
	tar zcR /opt/eja.it/src > /opt/eja.it/bkp/eja-$(shell date +%y%m%d%H%M).tar.gz
	
/usr/bin/eja:
	@ -ln -s /opt/eja.it/bin/eja /usr/bin/eja 
	
install: eja /usr/bin/eja
	@ cp eja /opt/eja.it/bin/eja
	