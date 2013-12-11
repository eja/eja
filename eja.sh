#!/bin/sh
#
# Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>
#


if [ "$1" = "make" ]; then  

 ejaCC="gcc"
 ejaLuaTmp="/tmp/eja/"
 ejaCFLAGS=" -lm -DLUA_USE_POPEN -w -ldl -I./lua/src -I$ejaLuaTmp "



 if [ ! -e $ejaLuaTmp ]; then 
  mkdir -p $ejaLuaTmp; 
 else
  rm -f $ejaLuaTmp/*
 fi
 if [ -e eja ]; then rm eja; fi
 if [ ! -e lib ]; then mkdir lib; fi
 if [ ! -e lua ]; then 
  git clone https://github.com/ubaldus/lua.git
  cd lua
  make posix
  cd ..
 fi

 cp lua/src/*.o  $ejaLuaTmp
 rm $ejaLuaTmp/lua.o
 rm $ejaLuaTmp/luac.o

 if [ -e lib ]; then
  lua/src/lua -e "fo=io.open('lib/version.lua','w');fo:write(string.format('eja.version=\"%s\";',(os.date('%y')-7)..'.'..os.date('%j',os.time()-1190014200)..'.'..os.date('%H%M')));fo:close()"
  lua/src/luac -o $ejaLuaTmp/eja.luac eja.lua $(find lib/*.lua) eja.lua
 fi

 lua/src/lua -e "fo=io.open('$ejaLuaTmp/eja.h','w');fo:write('char luaBuf[]={'); f=io.open('$ejaLuaTmp/eja.luac','r'); while f do c=f:read(1); if not c then break else fo:write(string.byte(c)..','); end; end; fo:write('0};'); f:close();fo:close()" 


 $ejaCC -o eja eja.c $(find $ejaLuaTmp/*.o) $ejaCFLAGS
 #strip eja 
 #upx eja

fi


if [ "$1" = "install" ]; then
 if [ ! -d /opt/eja.it/bin ]; then mkdir -p /opt/eja.it/bin; fi
 cp eja /opt/eja.it/bin/eja
 if [ ! -e /usr/bin/eja ]; then ln -s /opt/eja.it/bin/eja /usr/bin/eja; fi
fi


if [ "$1" = "clean" ]; then
 if [ -d lua ]; then rm -Rf lua; fi
 if [ -e eja ]; then rm eja; fi
fi


if [ "$1" = "git" ]; then
 if [ ! -d .git ]; then git init; fi
 echo 'Git message: '
 read gitMsg
 if [ "$gitMsg" != "" ]; then
  git add .
  git commit -m "$gitMsg"
  git remote add origin https://github.com/ubaldus/eja.git
  git push -f origin master
 fi
fi


if [ "$1" = "bkp" ]; then
 if [ ! -d /opt/eja.it/bkp ]; then mkdir -p /opt/eja.it/bkp; fi
 tar zcRv /opt/eja.it/src --exclude "lua/*" > /opt/eja.it/bkp/eja-$(date +"%y%m%d%H%M%S").tar.gz
fi


if [ "$1" = "" ]; then
 echo $0" [make] [install] [git] [bkp] [clean]"
fi

