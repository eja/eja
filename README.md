eja
===

a micro web server written in C and Lua that can serve dynamic content. 


INSTALLING
----------

If you are running any recent Debian or derivative it should be enough to run:

    sudo apt-get install eja

Othewise:

    git clone https://github.com/ubaldus/eja.git
    cd eja
    make
    sudo make install

USAGE
-----

The simplest way to use it would be:

    eja --web-start 

this would serve the files contained in /var/eja/web on port 35248, thus if the file /var/eja/web/index.html exists its content would be available on your browser at http://localhost:35248/ .

If the file ends in .eja (index.eja) its content is generated dynamic:

    web=...
    web.data="Hello World!"
    return web

or a little more complex with a file named `sum.eja`:

    web=...
    local a=ejaNumber(web.opt.a)
    local b=ejaNumber(web.opt.b)
    web.data=ejaSprintf("The sum is %d",a+b)
    return web

in this case opening the url http://localhost:35248/sum.eja?a=3&b=4 would return

    The sum is 7

