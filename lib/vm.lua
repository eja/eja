-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.export='ejaVmFileExport'
eja.help.export='vm file to export'
eja.help.exportName='vm exported file name'


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
  o[#o+1]=string.dump(load("do end")):sub(1,18)
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


function ejaVmFileExport(inputFile,outputName)
 local outputName=outPut or eja.opt.exportName or eja.opt.export or nil
 local inputFile=inputFile or eja.opt.export
 if outputName then
  local data=ejaFileRead(inputFile) 
  if data then
   if outputName:match('%.lua$') then 
    outputName=outputName:sub(1,-5) 
    data=ejaVmExport(string.dump(load(data)))			--lua
   elseif outputName:match('%.luac$') then
    outputName=outputName:sub(1,-6) 
    data=ejaVmExport(data)					--luac
   elseif not data:match('^ejaVM') then				--eja clear
    data=ejaVmExport(string.dump(load(ejaVmToLua(data))))
    outputName=outputName:sub(1,-5)
   else
    ejaWarn('[eja] vm, input file not supported or already compiled.')
   end
  end
  if data and outputName then
   outputName=outputName..'.eja'
   if not ejaFileStat(outputName) then
    ejaFileWrite(outputName,data)
   else
    ejaWarn('[eja] vm, not overwriting existing file.')
   end
  end
 end 
end


function ejaVmFileLoad(fileName)
 local ff
 local dataIn=ejaFileRead(fileName) or fileName:sub(#eja.pathBin+1)
 if dataIn then
  if fileName:match('%.eja$') then
   if dataIn:match('^ejaVM') then
    ff,ee=load(ejaVmImport(dataIn))
    if not ff then
     ejaError('[eja] vm, corrupted vm file: %s',ee)
    end
   else
    ff,ee=load(ejaVmToLua(dataIn))
    if not ff then
     ejaError('[eja] vm, eja syntax error: %s',ee)
    end
   end
  else
   ff,ee=load(dataIn)
   if not ff then
    ejaError('[eja] vm, lua syntax error: %s',ee)
   end
  end
  if ff then
   ff()
  end  
 end
end


function ejaVmToLua(text)
 local a=ejaLuaLexer(text);
 local aIn={}
 local aOut={}
 local functionArray={}; functionArray[0]=0; functionCount=0;
 local whileArray={}; whileArray[0]=0; whileCount=0;
 local forArray={}; forArray[0]=0; forCount=0;
 local conditionalArray={}; conditionalArray[0]=0; conditionalCount=0;
 local elseArray={}; elseArray[0]=0; elseCount=0;
 local elseifArray={}; elseifArray[0]=0; elseifCount=0;

 for rowNumber,row in next,a do 
  for k,v in next,row do
   v.row=rowNumber
  --check with whitespace
   local aNext={}
   if v.type == "whitespace" and #aIn > 0 then 
    aIn[#aIn].space=v.data;
   else
    if v.type == "symbol" then
     if v.data:match("};$") or v.data:match("%){$") then
      local s1,s2=v.data:match('(.-)(.)$')
      v.data=s1;
      aNext.type="symbol"
      aNext.data=s2
     end
    end
    if v.type == "operator" then
     if v.data=="//" then v.data="--";		end
     if v.data=="/*" then v.data="--[[";	end
     if v.data=="*/" then v.data="--]]";	end
    end
    if v.type == "unidentified" then
     if v.data=="||" then v.data=" or ";	end
     if v.data=="&&" then v.data=" and ";	end
     if v.data=="!"  then 
      if row[k+1] and row[k+1].data == "=" then
       v.data="~";
      else
       v.data=" not ";	
      end
     end
    end
    aIn[#aIn+1]=v;
    if aNext.data then
     aIn[#aIn+1]=aNext;
    end
   end
  end
  if #aIn == 0 then
   aIn[#aIn+1]={}
  end
  aIn[#aIn].line=1;  
 end
 
 for k,v in next,aIn do
  local line=v.data;
  
  --check without whitespace
  if (v.type == "keyword" and v.data=="else" and aIn[k+1] and aIn[k+1].type == "keyword" and aIn[k+1].data == "if") then
   line=""
   aIn[k+1].data="elseif";
  end
  
  --function
  if (functionArray[functionCount] >= 3 and v.type == "symbol" and v.data == "}") then
   functionArray[functionCount]=functionArray[functionCount]-1;
   if functionArray[functionCount] == 2 then 
    functionArray[functionCount]=0
    functionCount=functionCount-1
    line=" end ";
   end
  end
  if (functionArray[functionCount] >= 2 and v.type == "symbol" and v.data == "{") then 
   functionArray[functionCount] = functionArray[functionCount] + 1;
   if (functionArray[functionCount] == 3) then 
    line="";
   end
  end
  if (functionArray[functionCount] == 1 and v.type == "ident") then
   functionArray[functionCount]=2;
  end
  if (v.type == "keyword" and v.data == "function") then
   functionCount=functionCount+1;
   functionArray[functionCount]=1;
  end

  --while
  if (whileArray[whileCount] >= 3 and v.type == "symbol" and v.data == "}") then
   whileArray[whileCount]=whileArray[whileCount]-1;
   if whileArray[whileCount] == 2 then 
    whileArray[whileCount]=0
    whileCount=whileCount-1
    line=" end ";
   end
  end
  if (whileArray[whileCount] >= 2 and v.type == "symbol" and v.data == "{") then 
   whileArray[whileCount] = whileArray[whileCount] + 1;
   if (whileArray[whileCount] == 3) then 
    line=" do ";
   end
  end
  if (whileArray[whileCount] == 1 and v.type == "ident") then
   whileArray[whileCount]=2;
  end
  if (v.type == "keyword" and v.data == "while") then
   whileCount=whileCount+1;
   whileArray[whileCount]=1;
  end

  --for  
  if (forArray[forCount] >= 4 and v.type == "symbol" and v.data == "}") then
   forArray[forCount]=forArray[forCount]-1;
   if forArray[forCount] == 3 then 
    forArray[forCount]=0
    forCount=forCount-1
    line=" end ";
   end
  end
  if (forArray[forCount] >= 3 and v.type == "symbol" and v.data == "{") then 
   forArray[forCount] = forArray[forCount] + 1;
   if (forArray[forCount] == 4) then 
    line=" do ";
   end
  end
  if (forArray[forCount] == 2 and v.type == "symbol" and v.data:match("%)$")) then
   forArray[forCount]=3;  
   line=v.data:sub(1,-2);
  end
  if (forArray[forCount] == 1 and v.type == "symbol" and v.data == "(" ) then
   forArray[forCount]=2;
   line="";
  end
  if (v.type == "keyword" and v.data == "for") then
   forCount=forCount+1;
   forArray[forCount]=1;
  end

  --if
  if (conditionalArray[conditionalCount] >= 2 and v.type == "symbol" and v.data == "}") then
   conditionalArray[conditionalCount]=conditionalArray[conditionalCount]-1
   if conditionalArray[conditionalCount] == 1 then
    conditionalArray[conditionalCount]=0
    conditionalCount=conditionalCount-1
    if aIn[k+1] and (aIn[k+1].data == "else" or aIn[k+1].data == "elseif")then
     line="";
    else
     line=" end "
    end
   end
  end
  if (conditionalArray[conditionalCount] >= 1 and v.type == "symbol" and v.data == "{") then
   conditionalArray[conditionalCount]=conditionalArray[conditionalCount]+1;
   if (conditionalArray[conditionalCount] == 2) then 
    line=" then ";
   end
  end  
  if (v.type == "keyword" and v.data == "if") then
   conditionalCount=conditionalCount+1;
   conditionalArray[conditionalCount]=1;
  end

  --else
  if (elseArray[elseCount] >= 2 and v.type == "symbol" and v.data == "}") then
   elseArray[elseCount]=elseArray[elseCount]-1
   if elseArray[elseCount] == 1 then
    elseArray[elseCount]=0
    elseCount=elseCount-1
    line=" end ";
   end
  end
  if (elseArray[elseCount] >= 1 and v.type == "symbol" and v.data == "{") then
   elseArray[elseCount]=elseArray[elseCount]+1;
   if (elseArray[elseCount] == 2) then 
    line="";
   end
  end  
  if (v.type == "keyword" and v.data == "else") then
   elseCount=elseCount+1;
   elseArray[elseCount]=1;
  end
   
  --elseif/else if
  if (elseifArray[elseifCount] >= 2 and v.type == "symbol" and v.data == "}") then
   elseifArray[elseifCount]=elseifArray[elseifCount]-1
   if elseifArray[elseifCount] == 1 then
    elseifArray[elseifCount]=0
    elseifCount=elseifCount-1
    if aIn[k+1] and (aIn[k+1].data == "else" or aIn[k+1].data == "elseif")then
     line="";
    else
     line=" end "
    end
   end
  end
  if (elseifArray[elseifCount] >= 1 and v.type == "symbol" and v.data == "{") then
   elseifArray[elseifCount]=elseifArray[elseifCount]+1;
   if (elseifArray[elseifCount] == 2) then 
    line=" then ";
   end
  end  
  if (v.type == "keyword" and v.data == "elseif") then
   elseifCount=elseifCount+1;
   elseifArray[elseifCount]=1;
  end
   
  aOut[#aOut+1]=line;
  if (v.line) then aOut[#aOut+1]="\n"; end
  if (v.space) then aOut[#aOut+1]=v.space; end
  if v.type and not v.type:match('string') then
   ejaTrace('[eja] lexer syntax check: %010d %010d % 16s\t%s',ejaNumber(v.row),k,v.type,line)
  end
 end
 local out=table.concat(aOut);
 ejaDebug('[eja] lexer dump:\n%s',out);
 return out;
end

