-- Copyright (C) 2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaFormInput(o,name,mode,label)
 local value
 local label=label or name
 if o then
  value=o.value[name]
  if not value then
   ejaPrintf('%s:',label)
   value=ejaString(io.read("*l"))
  end
 end
 o.value[name]=value
 return value
end


function ejaFormSelect(o,name,matrix,label)
 local value
 local label=label or name
 if o and type(matrix)=="table" then
  value=o.value[name]
  if not value then
   local stop=0
   while stop==0 do
    ejaPrintf('%s %s:',label,ejaJsonEncode(matrix))
    value=ejaString(io.read("*l"))
    for k,v in next,matrix do
     if value==v then 
      stop=1
     end
    end
   end
  end
 end
 o.value[name]=value
 return value
end


function ejaFormOutput(o)
 return ejaJsonEncode(o.value,1) 
end


function ejaForm(o)
 if type(o) == "table" then
  return ejaWebForm(o)
 else
  o=ejaTable(o)
  o.form=ejaTable()
  o.form.value=ejaTable(eja.opt)
  o.form.element=ejaTable()
  o.form.input=function(...) return ejaFormInput(...) end
  o.form.select=function(...) return ejaFormSelect(...) end
  o.form.output=function(...) return ejaFormOutput(...) end
  return o
 end
end

