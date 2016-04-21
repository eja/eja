-- Copyright (C) 2015 Alberto Cubeddu <acubeddu87@gmail.com>


eja.lib.webUser='ejaWebUser'
eja.help.webUser='add a new web user'


function ejaWebUser()
    if (ejaFileAppend(eja.pathEtc..'eja.web',"")) then
        local username;
        local password;
        local power;
        
        repeat
            local pass = false;
            io.write("Username: ")
            username=io.read("*l")
            
            if (#username == 0) then
                io.write("Please insert a valid username\n");
            elseif (username:match("%s")) then
                io.write("No whitespace allowed\n");
            elseif (username:match("[^%w]")) then
                io.write("Only alphanumerical character\n");
            else
                pass = true;
            end 
        until pass==true;

        repeat
            local pass = false;
            local passwordCheck;

            io.write("Password: ")
            os.execute('stty -echo');
            password=io.read("*l")
            io.write("\n");
            os.execute('stty echo');  
                 

            if(#password == 0) then
                io.write("Invalid password. Please insert a valid password\n");
            else
                io.write("Retype password: ")
                os.execute('stty -echo');
                passwordCheck=io.read("*l")
                io.write("\n");
                os.execute('stty echo');
                
                if(passwordCheck == password) then
                    pass=true
                else
                    io.write("Password mismatch. Please try again\n");
                end
            end


        until pass==true;

        repeat 
            local pass=false;
            io.write("Power: ")
            power=io.read("*l")
            if (tonumber(power) ~= nil) then
                pass=true;
            else
                io.write("Power value must be integer\n")
            end
        until pass==true;
        
        ejaFileAppend(eja.pathEtc..'eja.web', ejaSprintf("%s %d\n",ejaSha256(username..password),power) )
    else
        print("Insufficent permission");
    end
end
 
