-- Copyright (C) 2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaWebFormInput(o,name,mode,label)
 local value=''
 if ejaTable(o).element then 
  value=o.value[name] or ''
  o.element[#o.element+1]={
   mode=mode or 'text',
   name=name,
   label=label or name,
   value=value
  }
 end
 return value
end


function ejaWebFormSelect(o,name,matrix,label)
 local value=''
 if ejaTable(o).element then 
  value=o.value[name] or ''
  o.element[#o.element+1]={
   mode='select',
   name=name,
   label=label or name,
   value=value,
   matrix=matrix
  }
 end
 return value
end


function ejaWebFormOutput(o,name,label,div,hide) 
 label=label or 1
 div=div or 1
 hide=hide or 0
 local out={}
 out[#out+1]=o.header
 if o.element then
  local name=name or 'ejaForm'
  out[#out+1]=ejaSprintf('<form name="%s" action="?" method="post">',name)
  for k,v in next,o.element do
   if ejaNumber(hide) > 0 and ejaString(v.value) ~= "" then 
    v.mode="hidden" 
    v.label=nil
   end
   if ejaNumber(div) > 0 and v.label then 
    out[#out+1]=ejaSprintf('<div class="%s" id="%s_%s">',name,name,v.name) 
   end
   if ejaNumber(label) > 0 and v.label then
    out[#out+1]=ejaSprintf('<label for="%s">%s</label>',v.name,v.label)
   end
   if v.mode == 'textarea' or v.mode =="area" then
    out[#out+1]=ejaSprintf('<textarea name="%s"',v.name)
    out[#out+1]=ejaSprintf('>%s</textarea>',v.value)
   elseif v.mode == 'select' then
    out[#out+1]=ejaSprintf('<select name="%s">',v.name)
     for kk,vv in next,v.matrix do
      out[#out+1]=ejaSprintf('<option value="%s"',vv)
      if ejaString(vv) == ejaString(v.value) then out[#out+1]=ejaSprintf('selected') end
      out[#out+1]=ejaSprintf('>%s</option>',vv)
     end
    out[#out+1]=ejaSprintf('</select>')
   else
    out[#out+1]=ejaSprintf('<input name="%s" type="%s" value="%s">',v.name,v.mode,v.value)
   end
   if div then out[#out+1]=ejaSprintf('</div>') end
  end
  out[#out+1]='<input type="submit"></form>'
  out[#out+1]=o.footer
  return table.concat(out)
 else
  return ''
 end
end


function ejaWebForm(o)
 o=ejaTable(o)
 o.form=ejaTable()
 o.form.value=ejaTable(o.opt)
 o.form.element=ejaTable()
 o.form.output=function(...) return ejaWebFormOutput(...) end 
 o.form.input=function(...) return ejaWebFormInput(...) end
 o.form.select=function(...) return ejaWebFormSelect(...) end 
 o.form.header=''
 o.form.footer=''
 return o
end

