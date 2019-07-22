-- Copyright (C) 2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaWebFormInput(o,name,mode,label)
 local value=o.opt[name] or ''
 if o.form then 
  o.form[#o.form+1]={
   mode=mode or 'text',
   name=name,
   label=label or name,
   value=value
  }
 end
 return value
end


function ejaWebFormSelect(o,name,matrix,label)
 local value=o.opt[name] or ''
 if o.form then 
  o.form[#o.form+1]={
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
 if o.form then
  local name=name or 'ejaForm'
  out[#out+1]=ejaSprintf('<form name="%s" action="?" method="post">',name)
  for k,v in next,o.form do
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
  return table.concat(out)
 else
  return ''
 end
end

function ejaWebForm(opt)
 local o={}
 o.opt={}
 o.form={}
 o.output=function(...) return ejaWebFormOutput(...) end 
 o.input=function(...) return ejaWebFormInput(...) end
 o.select=function(...) return ejaWebFormSelect(...) end 
 if opt.opt then
  for k,v in next,opt.opt do
   o.opt[k]=ejaString(v)
  end
  opt.form=o
  return opt
 else
  for k,v in next,opt do
   o.opt[k]=ejaString(v)
  end
  return o
 end
end

