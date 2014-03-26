-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.export='ejaVmFileExport'
eja.help.export='vm export (file)'


function ejaVmInt2Hex(int) 	return sf('i%X',int) end

function ejaVmByte2Hex(int) 	return sf('b%X',int) end

function ejaVmInstr2Hex(int) 	return sf('I%X',int) end

function ejaVmSize2Hex(int) 	return sf('s%X',int) end

function ejaVmNum2Hex(int) 	return sf('n%X',int) end


function ejaVmString2Hex(data)
 local out='S'
 local i
 for i=1,#data do out=out..sf('%02X',data:byte(i)) end
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
 local o=''
 local i=0
 local z=0
 local p=pos
 local debug=false

 o=o..ejaVmInt2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1)));		p=p+h.int;	--first line
 o=o..ejaVmInt2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1)));		p=p+h.int;	--last line
 o=o..ejaVmByte2Hex(d:byte(p));						p=p+1;		--num params
 o=o..ejaVmByte2Hex(d:byte(p));						p=p+1;		--is vararg
 o=o..ejaVmByte2Hex(d:byte(p));						p=p+1;		--max stack size

 if debug then o=o..'\ninstr\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(z);							p=p+h.int;	--length of Instruction block
 for n=1,z do
  o=o..ejaVmInstr2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.Instr-1)));	p=p+h.Instr;	--Instruction
 end

 if debug then o=o..'\nconst\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(z);							p=p+h.int;	--length of constant
 for n=1,z do
  local cType=d:byte(p);
  o=o..ejaVmByte2Hex(cType);						p=p+1;		--const type
  if cType == 4 then
   local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   o=o..ejaVmSize2Hex(l);						p=p+h.size;	--string length
   if l > 0 then
    o=o..ejaVmString2Hex(d:sub(p,p+l-1));				p=p+l;		--string
   end
  end
  if cType == 3 then
   o=o..ejaVmNum2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.num-1)));	p=p+h.num;	--number
  end
  if cType == 1 then
   o=o..ejaVmByte2Hex(d:byte(p));					p=p+1;		--boolean
  end
  if cType == 0 then end								--nil
 end

 if debug then o=o..'\nproto\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(z);							p=p+h.int;	--length of function 
 for n=1,z do
  local t,n=ejaVmFunction(h,d,p)
  p=p+n
  o=o..t
 end
 
 if debug then o=o..'\nupvalue\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(z);							p=p+h.int;	--length of upvalues
 for n=1,z do
  o=o..ejaVmByte2Hex(d:byte(p));					p=p+1;		--stack
  o=o..ejaVmByte2Hex(d:byte(p));					p=p+1;		--idx
 end

 if debug then o=o..'\nsource\n' end	
 l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
 o=o..ejaVmSize2Hex(0);							p=p+h.size;	--string length
 if l > 0 then
  p=p+l;										--string
 end
 
 if debug then o=o..'\nline info\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(0);							p=p+h.int;	--length of line
 for n=1,z do
  p=p+h.int;										--begin
 end

  
 if debug then o=o..'\nlocals\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(0);							p=p+h.int;	--length of local vars
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   p=p+h.size;										--string length
  if l > 0 then
   p=p+l;										--string
  end
  p=p+h.int;										--begin
  p=p+h.int;										--end
 end

 if debug then o=o..'\nupvalues\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o=o..ejaVmInt2Hex(0);							p=p+h.int;	--length of upvalues
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
  p=p+h.size;										--string length
  p=p+l;										--string
 end

 return o,p-pos
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
  local o=string.dump(loadstring("do end")):sub(1,18)
  local h=ejaVmHeader(o)
  for k,v in data:gmatch('([nbiIsS])([^nbiIsS]+)') do 
   if k == 'b' then o=o..ejaVmHex2Byte(h.endian,v,1) end
   if k == 'n' then o=o..ejaVmHex2Byte(h.endian,v,h.num) end
   if k == 'i' then o=o..ejaVmHex2Byte(h.endian,v,h.int) end
   if k == 'I' then o=o..ejaVmHex2Byte(h.endian,v,h.Instr) end
   if k == 's' then o=o..ejaVmHex2Byte(h.endian,v,h.size) end
   if k == 'S' then 
    for c in v:gmatch('..') do
     o=o..string.char(tonumber(c,16))
    end   
   end
  end 
  return o
 else
  return nil
 end
end


function ejaVmFileExport(file)
 local f=file or eja.opt.export or nil
 if f then
  local data=ejaFileRead(f) 
  if f:sub(-4) == '.lua' then f=f:sub(1,-5) end
  if data and data:sub(1,5) ~= 'ejaVM' then
   if data:sub(1,4) == string.char(27,76,117,97) then
    data=ejaVmExport(data)
   else
    data=ejaVmExport(string.dump(loadstring(data)))
   end
   ejaFileWrite(f..'.eja',data)
  end
 end 
end


function ejaVmFileLoad(f)
 local data=ejaFileRead(f)
 if data then
  if data:sub(1,5) == 'ejaVM' then
   data=ejaVmImport(data)
  end
 end
 local ejaScriptRun=assert(loadstring(data))
 if ejaScriptRun then ejaScriptRun() end
end


