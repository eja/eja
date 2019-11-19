-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.export='ejaVmFileExport'
eja.help.export='vm export (file)'
eja.help.exportName='vm export file name'


function ejaVmInt2Hex(int) 	return ejaSprintf('i%X',int) end

function ejaVmByte2Hex(int) 	return ejaSprintf('b%X',int) end

function ejaVmInstr2Hex(int) 	return ejaSprintf('I%X',int) end

function ejaVmSize2Hex(int) 	return ejaSprintf('s%X',int) end

function ejaVmNum2Hex(int) 	return ejaSprintf('n%X',int) end


function ejaVmString2Hex(data)
 local out='S'
 local i
 for i=1,#data do out=out..ejaSprintf('%02X',data:byte(i)) end
 return out
end 


function ejaVmHex2Byte(little,hex,len)
 local o=''
 local n=tonumber(hex,16)
 for i=1,len do
  o=string.char(n%256)..o
  n=math.floor(n/256)
 end
 if little > 0 then o=o:reverse() end 
 return o
end


function ejaVmByte2Int(little,data)
 local n=0
 if little > 0 then
  for i=#data,1,-1 do n=n+tonumber(data:byte(i)*(256^i)) end
 else
  for i=1,#data do n=n+(data:byte(i)*(256^i)) end
 end
 return n/256
end


function ejaVmFunction(h,d,pos)	--header, data, position
 local o={}
 local i=0
 local z=0
 local p=pos
 local debug=false

 o[#o+1]=ejaVmInt2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1)));		p=p+h.int;	--first line
 o[#o+1]=ejaVmInt2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1)));		p=p+h.int;	--last line
 o[#o+1]=ejaVmByte2Hex(d:byte(p));						p=p+1;		--num params
 o[#o+1]=ejaVmByte2Hex(d:byte(p));						p=p+1;		--is vararg
 o[#o+1]=ejaVmByte2Hex(d:byte(p));						p=p+1;		--max stack size

 if debug then o[#o+1]='\ninstr\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(z);							p=p+h.int;	--length of Instruction block
 for n=1,z do
  o[#o+1]=ejaVmInstr2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.Instr-1)));	p=p+h.Instr;	--Instruction
 end

 if debug then o[#o+1]='\nconst\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(z);							p=p+h.int;	--length of constant
 for n=1,z do
  local cType=d:byte(p);
  o[#o+1]=ejaVmByte2Hex(cType);						p=p+1;		--const type
  if cType == 4 then
   local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   o[#o+1]=ejaVmSize2Hex(l);						p=p+h.size;	--string length
   if l > 0 then
    o[#o+1]=ejaVmString2Hex(d:sub(p,p+l-1));				p=p+l;		--string
   end
  end
  if cType == 3 then
   o[#o+1]=ejaVmNum2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.num-1)));	p=p+h.num;	--number
  end
  if cType == 1 then
   o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;		--boolean
  end
  if cType == 0 then end								--nil
 end

 if debug then o[#o+1]='\nproto\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(z);							p=p+h.int;	--length of function 
 for n=1,z do
  local t,n=ejaVmFunction(h,d,p)
  p=p+n
  o[#o+1]=t
 end
 
 if debug then o[#o+1]='\nupvalue\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(z);							p=p+h.int;	--length of upvalues
 for n=1,z do
  o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;		--stack
  o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;		--idx
 end

 if debug then o[#o+1]='\nsource\n' end	
 l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
 o[#o+1]=ejaVmSize2Hex(0);							p=p+h.size;	--string length
 if l > 0 then
  p=p+l;										--string
 end
 
 if debug then o[#o+1]='\nline info\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of line
 for n=1,z do
  p=p+h.int;										--begin
 end

  
 if debug then o[#o+1]='\nlocals\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of local vars
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   p=p+h.size;										--string length
  if l > 0 then
   p=p+l;										--string
  end
  p=p+h.int;										--begin
  p=p+h.int;										--end
 end

 if debug then o[#o+1]='\nupvalues\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of upvalues
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
  p=p+h.size;										--string length
  p=p+l;										--string
 end

 return table.concat(o),p-pos
end


function ejaVmHeader(data)
 local h={}
 h.version=data:byte(5);
 h.format=data:byte(6)
 h.endian=data:byte(7)
 h.int=data:byte(8)	
 h.size=data:byte(9)		
 h.Instr=data:byte(10)	
 h.num=data:byte(11)	
 h.integral=data:byte(12)
 return h  
end


function ejaVmExport(data)
 local o='ejaVM';
 local h=ejaVmHeader(data)
 local t,n=ejaVmFunction(h,data,12+6+1)
 return o..t
end


function ejaVmImport(data)
 if data:sub(1,5) == 'ejaVM' then
  local o={}
  local h=''
  o[#o+1]=string.dump(loadstring("do end")):sub(1,18)
  h=ejaVmHeader(o[1])
  for k,v in data:gmatch('([nbiIsS])([^nbiIsS]+)') do 
   if k == 'b' then o[#o+1]=ejaVmHex2Byte(h.endian,v,1) end
   if k == 'n' then o[#o+1]=ejaVmHex2Byte(h.endian,v,h.num) end
   if k == 'i' then o[#o+1]=ejaVmHex2Byte(h.endian,v,h.int) end
   if k == 'I' then o[#o+1]=ejaVmHex2Byte(h.endian,v,h.Instr) end
   if k == 's' then o[#o+1]=ejaVmHex2Byte(h.endian,v,h.size) end
   if k == 'S' then 
    for c in v:gmatch('..') do
     o[#o+1]=string.char(tonumber(c,16))
    end   
   end
  end 
  return table.concat(o)
 else
  return nil
 end
end


function ejaVmFileExport(file,name)
 local fileName=name or eja.opt.exportName or eja.opt.export or nil
 local file=file or eja.opt.export
 if fileName then
  local data=ejaFileRead(file) 
  if fileName:sub(-4) == '.lua' then fileName=fileName:sub(1,-5) end
  if data and data:sub(1,5) ~= 'ejaVM' then
   if data:sub(1,4) == string.char(27,76,117,97) then
    data=ejaVmExport(data)
   else
    data=ejaVmExport(string.dump(loadstring(data)))
   end
   ejaFileWrite(fileName..'.eja',data)
  end
 end 
end


function ejaVmFileLoad(f)
 local data=""
 if f:match('http%://') then
  local bin,head=ejaWebGet(f:match('http%://.*'))
  if bin and head then
   if ejaSha256(bin) == ejaString(head:match('ejaSha256%: ([%x]+)')) then
    data=bin
   else
    ejaError("Hash doesn't match, not loading.")
   end
  end
 else
  data=ejaFileRead(f)
 end
 if data then
  if data:sub(1,5) == 'ejaVM' then
   data=ejaVmImport(data)
  end
 end
 local ejaScriptRun=assert(loadstring(data))
 if ejaScriptRun then ejaScriptRun() end
end
