-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.mime={} 
 eja.mimeApp={}
end


function ejaLoad()

 if not eja.load then 
  eja.load=1
 else
  eja.load=eja.load+1
 end

 if eja.path or eja.load ~= 3 then return end

 if not _G['ejaPid'] then
  if ejaModuleCheck("posix") then
   ejaRock()
  else
   print("Please use eja or install luaposix.")
   os.exit()
  end
 end

 eja.path=_eja_path or '/'
 eja.pathBin=_eja_path_bin or eja.path..'/usr/bin/'
 eja.pathEtc=_eja_path_etc or eja.path..'/etc/eja/'
 eja.pathLib=_eja_path_lib or eja.path..'/usr/lib/eja/'
 eja.pathVar=_eja_path_var or eja.path..'/var/eja/'
 eja.pathTmp=_eja_path_tmp or eja.path..'/tmp/'
 eja.pathLock=_eja_path_lock or eja.path..'/var/lock/'
 
 package.cpath=eja.pathLib..'?.so;'..package.cpath
 
 t=ejaDirList(eja.pathLib)
 if t then 
  local help=eja.help
  eja.helpFull={}
  table.sort(t)
  for k,v in next,t do
   if v:match('.eja$') then
    eja.help={}
    ejaVmFileLoad(eja.pathLib..v)
    eja.helpFull[v:sub(0,-5)]=eja.help
   end
  end
  eja.help=help
 end

 if #arg > 0 then
  for i in next,arg do
   if arg[i]:match('^%-%-') then
    local k=arg[i]:sub(3):gsub("-(.)",function(x) return x:upper() end)
    if not arg[i+1] or arg[i+1]:match('^%-%-') then 
     eja.opt[k]=''
    else
     eja.opt[k]=arg[i+1]   
    end
   end
  end
  if arg[1]:match('^[^%-%-]') then
   if ejaFileStat(arg[1]) then
    ejaVmFileLoad(arg[1])
   else
    ejaVmFileLoad(eja.pathBin..arg[1])
   end
  end
  ejaRun(eja.opt)
 else
  ejaHelp() 
 end
 
end


ejaLoad();

-- Copyright (C) 2020 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaEncode(data, password)
 if ejaString(password) ~= "" then
  return ejaBase64Encode(ejaAES().ejaEncrypt(password, data, 32, 2));
 else
  return ejaBase64Encode(data);
 end
end


function ejaDecode(data, password)
 if ejaString(password) ~= "" then
  return ejaAES().ejaDecrypt(password, ejaBase64Decode(data), 32, 2);
 else
  return ejaBase64Decode(data);
 end
end


function ejaAES()

 local bit=bit32;

--[[
aeslua: Lua AES implementation
Copyright (c) 2006,2007 Matthias Hilbig

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser Public License as published by the
Free Software Foundation; either version 2.1 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser Public License for more details.

A copy of the terms and conditions of the license can be found in
License.txt or online at

    http://www.gnu.org/copyleft/lesser.html

To obtain a copy, write to the Free Software Foundation, Inc.,
59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Author
-------
Matthias Hilbig
mhilbig@gmail.com
]]


 function aes()
  local gf = gf();
  local util = util();
  
  --
  -- Implementation of AES with nearly pure lua (only bitlib is needed) 
  --
  -- AES with lua is slow, really slow :-)
  --
  
  local public = {};
  local private = {};
  
  aeslua.aes = public;
  
  -- some constants
  public.ROUNDS = "rounds";
  public.KEY_TYPE = "type";
  public.ENCRYPTION_KEY=1;
  public.DECRYPTION_KEY=2;
  
  -- aes SBOX
  private.SBox = {};
  private.iSBox = {};
  
  -- aes tables
  private.table0 = {};
  private.table1 = {};
  private.table2 = {};
  private.table3 = {};
  
  private.tableInv0 = {};
  private.tableInv1 = {};
  private.tableInv2 = {};
  private.tableInv3 = {};
  
  -- round constants
  private.rCon = {0x01000000, 
                  0x02000000, 
                  0x04000000, 
                  0x08000000, 
                  0x10000000, 
                  0x20000000, 
                  0x40000000, 
                  0x80000000, 
                  0x1b000000, 
                  0x36000000,
                  0x6c000000,
                  0xd8000000,
                  0xab000000,
                  0x4d000000,
                  0x9a000000,
                  0x2f000000};
  
  --
  -- affine transformation for calculating the S-Box of AES
  --
  function private.affinMap(byte)
      mask = 0xf8;
      result = 0;
      for i = 1,8 do
          result = bit.lshift(result,1);
  
          parity = util.byteParity(bit.band(byte,mask)); 
          result = result + parity
  
          -- simulate roll
          lastbit = bit.band(mask, 1);
          mask = bit.band(bit.rshift(mask, 1),0xff);
          if (lastbit ~= 0) then
              mask = bit.bor(mask, 0x80);
          else
              mask = bit.band(mask, 0x7f);
          end
      end
  
      return bit.bxor(result, 0x63);
  end
  
  --
  -- calculate S-Box and inverse S-Box of AES
  -- apply affine transformation to inverse in finite field 2^8 
  --
  function private.calcSBox() 
      for i = 0, 255 do
      if (i ~= 0) then
          inverse = gf.invert(i);
      else
          inverse = i;
      end
          mapped = private.affinMap(inverse);                 
          private.SBox[i] = mapped;
          private.iSBox[mapped] = i;
      end
  end
  
  --
  -- Calculate round tables
  -- round tables are used to calculate shiftRow, MixColumn and SubBytes 
  -- with 4 table lookups and 4 xor operations.
  --
  function private.calcRoundTables()
      for x = 0,255 do
          byte = private.SBox[x];
          private.table0[x] = util.putByte(gf.mul(0x03, byte), 0)
                            + util.putByte(             byte , 1)
                            + util.putByte(             byte , 2)
                            + util.putByte(gf.mul(0x02, byte), 3);
          private.table1[x] = util.putByte(             byte , 0)
                            + util.putByte(             byte , 1)
                            + util.putByte(gf.mul(0x02, byte), 2)
                            + util.putByte(gf.mul(0x03, byte), 3);
          private.table2[x] = util.putByte(             byte , 0)
                            + util.putByte(gf.mul(0x02, byte), 1)
                            + util.putByte(gf.mul(0x03, byte), 2)
                            + util.putByte(             byte , 3);
          private.table3[x] = util.putByte(gf.mul(0x02, byte), 0)
                            + util.putByte(gf.mul(0x03, byte), 1)
                            + util.putByte(             byte , 2)
                            + util.putByte(             byte , 3);
      end
  end
  
  --
  -- Calculate inverse round tables
  -- does the inverse of the normal roundtables for the equivalent 
  -- decryption algorithm.
  --
  function private.calcInvRoundTables()
      for x = 0,255 do
          byte = private.iSBox[x];
          private.tableInv0[x] = util.putByte(gf.mul(0x0b, byte), 0)
                               + util.putByte(gf.mul(0x0d, byte), 1)
                               + util.putByte(gf.mul(0x09, byte), 2)
                               + util.putByte(gf.mul(0x0e, byte), 3);
          private.tableInv1[x] = util.putByte(gf.mul(0x0d, byte), 0)
                               + util.putByte(gf.mul(0x09, byte), 1)
                               + util.putByte(gf.mul(0x0e, byte), 2)
                               + util.putByte(gf.mul(0x0b, byte), 3);
          private.tableInv2[x] = util.putByte(gf.mul(0x09, byte), 0)
                               + util.putByte(gf.mul(0x0e, byte), 1)
                               + util.putByte(gf.mul(0x0b, byte), 2)
                               + util.putByte(gf.mul(0x0d, byte), 3);
          private.tableInv3[x] = util.putByte(gf.mul(0x0e, byte), 0)
                               + util.putByte(gf.mul(0x0b, byte), 1)
                               + util.putByte(gf.mul(0x0d, byte), 2)
                               + util.putByte(gf.mul(0x09, byte), 3);
      end
  end
  
  
  --
  -- rotate word: 0xaabbccdd gets 0xbbccddaa
  -- used for key schedule
  --
  function private.rotWord(word)
      local tmp = bit.band(word,0xff000000);
      return (bit.lshift(word,8) + bit.rshift(tmp,24)) ;
  end
  
  --
  -- replace all bytes in a word with the SBox.
  -- used for key schedule
  --
  function private.subWord(word)
      return util.putByte(private.SBox[util.getByte(word,0)],0) 
           + util.putByte(private.SBox[util.getByte(word,1)],1) 
           + util.putByte(private.SBox[util.getByte(word,2)],2)
           + util.putByte(private.SBox[util.getByte(word,3)],3);
  end
  
  --
  -- generate key schedule for aes encryption
  --
  -- returns table with all round keys and
  -- the necessary number of rounds saved in [public.ROUNDS]
  --
  function public.expandEncryptionKey(key)
      local keySchedule = {};
      local keyWords = math.floor(#key / 4);
     
   
      if ((keyWords ~= 4 and keyWords ~= 6 and keyWords ~= 8) or (keyWords * 4 ~= #key)) then
          print("Invalid key size: ", keyWords);
          return nil;
      end
  
      keySchedule[public.ROUNDS] = keyWords + 6;
      keySchedule[public.KEY_TYPE] = public.ENCRYPTION_KEY;
   
      for i = 0,keyWords - 1 do
          keySchedule[i] = util.putByte(key[i*4+1], 3) 
                         + util.putByte(key[i*4+2], 2)
                         + util.putByte(key[i*4+3], 1)
                         + util.putByte(key[i*4+4], 0);  
      end    
     
      for i = keyWords, (keySchedule[public.ROUNDS] + 1)*4 - 1 do
          local tmp = keySchedule[i-1];
  
          if ( i % keyWords == 0) then
              tmp = private.rotWord(tmp);
              tmp = private.subWord(tmp);
              
              local index = math.floor(i/keyWords);
              tmp = bit.bxor(tmp,private.rCon[index]);
          elseif (keyWords > 6 and i % keyWords == 4) then
              tmp = private.subWord(tmp);
          end
          
          keySchedule[i] = bit.bxor(keySchedule[(i-keyWords)],tmp);
      end
  
      return keySchedule;
  end
  
  --
  -- Inverse mix column
  -- used for key schedule of decryption key
  --
  function private.invMixColumnOld(word)
      local b0 = util.getByte(word,3);
      local b1 = util.getByte(word,2);
      local b2 = util.getByte(word,1);
      local b3 = util.getByte(word,0);
       
      return util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b1), 
                                               gf.mul(0x0d, b2)), 
                                               gf.mul(0x09, b3)), 
                                               gf.mul(0x0e, b0)),3)
           + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b2), 
                                               gf.mul(0x0d, b3)), 
                                               gf.mul(0x09, b0)), 
                                               gf.mul(0x0e, b1)),2)
           + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b3), 
                                               gf.mul(0x0d, b0)), 
                                               gf.mul(0x09, b1)), 
                                               gf.mul(0x0e, b2)),1)
           + util.putByte(gf.add(gf.add(gf.add(gf.mul(0x0b, b0), 
                                               gf.mul(0x0d, b1)), 
                                               gf.mul(0x09, b2)), 
                                               gf.mul(0x0e, b3)),0);
  end
  
  -- 
  -- Optimized inverse mix column
  -- look at http://fp.gladman.plus.com/cryptography_technology/rijndael/aes.spec.311.pdf
  -- TODO: make it work
  --
  function private.invMixColumn(word)
      local b0 = util.getByte(word,3);
      local b1 = util.getByte(word,2);
      local b2 = util.getByte(word,1);
      local b3 = util.getByte(word,0);
      
      local t = bit.bxor(b3,b2);
      local u = bit.bxor(b1,b0);
      local v = bit.bxor(t,u);
      v = bit.bxor(v,gf.mul(0x08,v));
      w = bit.bxor(v,gf.mul(0x04, bit.bxor(b2,b0)));
      v = bit.bxor(v,gf.mul(0x04, bit.bxor(b3,b1)));
      
      return util.putByte( bit.bxor(bit.bxor(b3,v), gf.mul(0x02, bit.bxor(b0,b3))), 0)
           + util.putByte( bit.bxor(bit.bxor(b2,w), gf.mul(0x02, t              )), 1)
           + util.putByte( bit.bxor(bit.bxor(b1,v), gf.mul(0x02, bit.bxor(b0,b3))), 2)
           + util.putByte( bit.bxor(bit.bxor(b0,w), gf.mul(0x02, u              )), 3);
  end
  
  --
  -- generate key schedule for aes decryption
  --
  -- uses key schedule for aes encryption and transforms each
  -- key by inverse mix column. 
  --
  function public.expandDecryptionKey(key)
      local keySchedule = public.expandEncryptionKey(key);
      if (keySchedule == nil) then
          return nil;
      end
      
      keySchedule[public.KEY_TYPE] = public.DECRYPTION_KEY;    
  
      for i = 4, (keySchedule[public.ROUNDS] + 1)*4 - 5 do
          keySchedule[i] = private.invMixColumnOld(keySchedule[i]);
      end
      
      return keySchedule;
  end
  
  --
  -- xor round key to state
  --
  function private.addRoundKey(state, key, round)
      for i = 0, 3 do
          state[i] = bit.bxor(state[i], key[round*4+i]);
      end
  end
  
  --
  -- do encryption round (ShiftRow, SubBytes, MixColumn together)
  --
  function private.doRound(origState, dstState)
      dstState[0] =  bit.bxor(bit.bxor(bit.bxor(
                  private.table0[util.getByte(origState[0],3)],
                  private.table1[util.getByte(origState[1],2)]),
                  private.table2[util.getByte(origState[2],1)]),
                  private.table3[util.getByte(origState[3],0)]);
  
      dstState[1] =  bit.bxor(bit.bxor(bit.bxor(
                  private.table0[util.getByte(origState[1],3)],
                  private.table1[util.getByte(origState[2],2)]),
                  private.table2[util.getByte(origState[3],1)]),
                  private.table3[util.getByte(origState[0],0)]);
      
      dstState[2] =  bit.bxor(bit.bxor(bit.bxor(
                  private.table0[util.getByte(origState[2],3)],
                  private.table1[util.getByte(origState[3],2)]),
                  private.table2[util.getByte(origState[0],1)]),
                  private.table3[util.getByte(origState[1],0)]);
      
      dstState[3] =  bit.bxor(bit.bxor(bit.bxor(
                  private.table0[util.getByte(origState[3],3)],
                  private.table1[util.getByte(origState[0],2)]),
                  private.table2[util.getByte(origState[1],1)]),
                  private.table3[util.getByte(origState[2],0)]);
  end
  
  --
  -- do last encryption round (ShiftRow and SubBytes)
  --
  function private.doLastRound(origState, dstState)
      dstState[0] = util.putByte(private.SBox[util.getByte(origState[0],3)], 3)
                  + util.putByte(private.SBox[util.getByte(origState[1],2)], 2)
                  + util.putByte(private.SBox[util.getByte(origState[2],1)], 1)
                  + util.putByte(private.SBox[util.getByte(origState[3],0)], 0);
  
      dstState[1] = util.putByte(private.SBox[util.getByte(origState[1],3)], 3)
                  + util.putByte(private.SBox[util.getByte(origState[2],2)], 2)
                  + util.putByte(private.SBox[util.getByte(origState[3],1)], 1)
                  + util.putByte(private.SBox[util.getByte(origState[0],0)], 0);
  
      dstState[2] = util.putByte(private.SBox[util.getByte(origState[2],3)], 3)
                  + util.putByte(private.SBox[util.getByte(origState[3],2)], 2)
                  + util.putByte(private.SBox[util.getByte(origState[0],1)], 1)
                  + util.putByte(private.SBox[util.getByte(origState[1],0)], 0);
  
      dstState[3] = util.putByte(private.SBox[util.getByte(origState[3],3)], 3)
                  + util.putByte(private.SBox[util.getByte(origState[0],2)], 2)
                  + util.putByte(private.SBox[util.getByte(origState[1],1)], 1)
                  + util.putByte(private.SBox[util.getByte(origState[2],0)], 0);
  end
  
  --
  -- do decryption round 
  --
  function private.doInvRound(origState, dstState)
      dstState[0] =  bit.bxor(bit.bxor(bit.bxor(
                  private.tableInv0[util.getByte(origState[0],3)],
                  private.tableInv1[util.getByte(origState[3],2)]),
                  private.tableInv2[util.getByte(origState[2],1)]),
                  private.tableInv3[util.getByte(origState[1],0)]);
  
      dstState[1] =  bit.bxor(bit.bxor(bit.bxor(
                  private.tableInv0[util.getByte(origState[1],3)],
                  private.tableInv1[util.getByte(origState[0],2)]),
                  private.tableInv2[util.getByte(origState[3],1)]),
                  private.tableInv3[util.getByte(origState[2],0)]);
      
      dstState[2] =  bit.bxor(bit.bxor(bit.bxor(
                  private.tableInv0[util.getByte(origState[2],3)],
                  private.tableInv1[util.getByte(origState[1],2)]),
                  private.tableInv2[util.getByte(origState[0],1)]),
                  private.tableInv3[util.getByte(origState[3],0)]);
      
      dstState[3] =  bit.bxor(bit.bxor(bit.bxor(
                  private.tableInv0[util.getByte(origState[3],3)],
                  private.tableInv1[util.getByte(origState[2],2)]),
                  private.tableInv2[util.getByte(origState[1],1)]),
                  private.tableInv3[util.getByte(origState[0],0)]);
  end
  
  --
  -- do last decryption round
  --
  function private.doInvLastRound(origState, dstState)
      dstState[0] = util.putByte(private.iSBox[util.getByte(origState[0],3)], 3)
                  + util.putByte(private.iSBox[util.getByte(origState[3],2)], 2)
                  + util.putByte(private.iSBox[util.getByte(origState[2],1)], 1)
                  + util.putByte(private.iSBox[util.getByte(origState[1],0)], 0);
  
      dstState[1] = util.putByte(private.iSBox[util.getByte(origState[1],3)], 3)
                  + util.putByte(private.iSBox[util.getByte(origState[0],2)], 2)
                  + util.putByte(private.iSBox[util.getByte(origState[3],1)], 1)
                  + util.putByte(private.iSBox[util.getByte(origState[2],0)], 0);
  
      dstState[2] = util.putByte(private.iSBox[util.getByte(origState[2],3)], 3)
                  + util.putByte(private.iSBox[util.getByte(origState[1],2)], 2)
                  + util.putByte(private.iSBox[util.getByte(origState[0],1)], 1)
                  + util.putByte(private.iSBox[util.getByte(origState[3],0)], 0);
  
      dstState[3] = util.putByte(private.iSBox[util.getByte(origState[3],3)], 3)
                  + util.putByte(private.iSBox[util.getByte(origState[2],2)], 2)
                  + util.putByte(private.iSBox[util.getByte(origState[1],1)], 1)
                  + util.putByte(private.iSBox[util.getByte(origState[0],0)], 0);
  end
  
  --
  -- encrypts 16 Bytes
  -- key           encryption key schedule
  -- input         array with input data
  -- inputOffset   start index for input
  -- output        array for encrypted data
  -- outputOffset  start index for output
  --
  function public.encrypt(key, input, inputOffset, output, outputOffset) 
      --default parameters
      inputOffset = inputOffset or 1;
      output = output or {};
      outputOffset = outputOffset or 1;
  
      local state = {};
      local tmpState = {};
      
      if (key[public.KEY_TYPE] ~= public.ENCRYPTION_KEY) then
          print("No encryption key: ", key[public.KEY_TYPE]);
          return;
      end
  
      state = util.bytesToInts(input, inputOffset, 4);
      private.addRoundKey(state, key, 0);
  
      local round = 1;
      while (round < key[public.ROUNDS] - 1) do
          -- do a double round to save temporary assignments
          private.doRound(state, tmpState);
          private.addRoundKey(tmpState, key, round);
          round = round + 1;
  
          private.doRound(tmpState, state);
          private.addRoundKey(state, key, round);
          round = round + 1;
      end
      
      private.doRound(state, tmpState);
      private.addRoundKey(tmpState, key, round);
      round = round +1;
  
      private.doLastRound(tmpState, state);
      private.addRoundKey(state, key, round);
      
      return util.intsToBytes(state, output, outputOffset);
  end
  
  --
  -- decrypt 16 bytes
  -- key           decryption key schedule
  -- input         array with input data
  -- inputOffset   start index for input
  -- output        array for decrypted data
  -- outputOffset  start index for output
  ---
  function public.decrypt(key, input, inputOffset, output, outputOffset) 
      -- default arguments
      inputOffset = inputOffset or 1;
      output = output or {};
      outputOffset = outputOffset or 1;
  
      local state = {};
      local tmpState = {};
  
      if (key[public.KEY_TYPE] ~= public.DECRYPTION_KEY) then
          print("No decryption key: ", key[public.KEY_TYPE]);
          return;
      end
  
      state = util.bytesToInts(input, inputOffset, 4);
      private.addRoundKey(state, key, key[public.ROUNDS]);
  
      local round = key[public.ROUNDS] - 1;
      while (round > 2) do
          -- do a double round to save temporary assignments
          private.doInvRound(state, tmpState);
          private.addRoundKey(tmpState, key, round);
          round = round - 1;
  
          private.doInvRound(tmpState, state);
          private.addRoundKey(state, key, round);
          round = round - 1;
      end
      
      private.doInvRound(state, tmpState);
      private.addRoundKey(tmpState, key, round);
      round = round - 1;
  
      private.doInvLastRound(tmpState, state);
      private.addRoundKey(state, key, round);
      
      return util.intsToBytes(state, output, outputOffset);
  end
  
  -- calculate all tables when loading this file
  private.calcSBox();
  private.calcRoundTables();
  private.calcInvRoundTables();
  
  return public;
 end


 function buffer()
  local public = {};
  
  aeslua.buffer = public;
  
  function public.new ()
    return {};
  end
  
  function public.addString (stack, s)
    table.insert(stack, s)
    for i = #stack - 1, 1, -1 do
      if #stack[i] > #stack[i+1] then 
          break;
      end
      stack[i] = stack[i] .. table.remove(stack);
    end
  end
  
  function public.toString (stack)
    for i = #stack - 1, 1, -1 do
      stack[i] = stack[i] .. table.remove(stack);
    end
    return stack[1];
  end
  
  return public;
 end

 
 function ciphermode()
  local aes = aes()
  local util = util();
  local buffer = buffer();
  
  local public = {};
  
  aeslua.ciphermode = public;
  
  --
  -- Encrypt strings
  -- key - byte array with key
  -- string - string to encrypt
  -- modefunction - function for cipher mode to use
  --
  function public.encryptString(key, data, modeFunction)
      local iv = iv or {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
      local keySched = aes.expandEncryptionKey(key);
      local encryptedData = buffer.new();
      
      for i = 1, #data/16 do
          local offset = (i-1)*16 + 1;
          local byteData = {string.byte(data,offset,offset +15)};
  		
          modeFunction(keySched, byteData, iv);
  
          buffer.addString(encryptedData, string.char(unpack(byteData)));    
      end
      
      return buffer.toString(encryptedData);
  end
  
  --
  -- the following 4 functions can be used as 
  -- modefunction for encryptString
  --
  
  -- Electronic code book mode encrypt function
  function public.encryptECB(keySched, byteData, iv) 
  	aes.encrypt(keySched, byteData, 1, byteData, 1);
  end
  
  -- Cipher block chaining mode encrypt function
  function public.encryptCBC(keySched, byteData, iv) 
      util.xorIV(byteData, iv);
  
      aes.encrypt(keySched, byteData, 1, byteData, 1);    
          
      for j = 1,16 do
          iv[j] = byteData[j];
      end
  end
  
  -- Output feedback mode encrypt function
  function public.encryptOFB(keySched, byteData, iv) 
      aes.encrypt(keySched, iv, 1, iv, 1);
      util.xorIV(byteData, iv);
  end
  
  -- Cipher feedback mode encrypt function
  function public.encryptCFB(keySched, byteData, iv) 
      aes.encrypt(keySched, iv, 1, iv, 1);    
      util.xorIV(byteData, iv);
         
      for j = 1,16 do
          iv[j] = byteData[j];
      end        
  end
  
  --
  -- Decrypt strings
  -- key - byte array with key
  -- string - string to decrypt
  -- modefunction - function for cipher mode to use
  --
  function public.decryptString(key, data, modeFunction)
      local iv = iv or {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
      
      local keySched;
      if (modeFunction == public.decryptOFB or modeFunction == public.decryptCFB) then
      	keySched = aes.expandEncryptionKey(key);
     	else
     		keySched = aes.expandDecryptionKey(key);
      end
      
      local decryptedData = buffer.new();
  
      for i = 1, #data/16 do
          local offset = (i-1)*16 + 1;
          local byteData = {string.byte(data,offset,offset +15)};
  
  		iv = modeFunction(keySched, byteData, iv);
  
          buffer.addString(decryptedData, string.char(unpack(byteData)));
      end
  
      return buffer.toString(decryptedData);    
  end
  
  --
  -- the following 4 functions can be used as 
  -- modefunction for decryptString
  --
  
  -- Electronic code book mode decrypt function
  function public.decryptECB(keySched, byteData, iv) 
  
      aes.decrypt(keySched, byteData, 1, byteData, 1);
      
      return iv;
  end
  
  -- Cipher block chaining mode decrypt function
  function public.decryptCBC(keySched, byteData, iv) 
  	local nextIV = {};
      for j = 1,16 do
          nextIV[j] = byteData[j];
      end
          
      aes.decrypt(keySched, byteData, 1, byteData, 1);    
      util.xorIV(byteData, iv);
  
  	return nextIV;
  end
  
  -- Output feedback mode decrypt function
  function public.decryptOFB(keySched, byteData, iv) 
      aes.encrypt(keySched, iv, 1, iv, 1);
      util.xorIV(byteData, iv);
      
      return iv;
  end
  
  -- Cipher feedback mode decrypt function
  function public.decryptCFB(keySched, byteData, iv) 
      local nextIV = {};
      for j = 1,16 do
          nextIV[j] = byteData[j];
      end
  
      aes.encrypt(keySched, iv, 1, iv, 1);
          
      util.xorIV(byteData, iv);
      
      return nextIV;
  end
  
  return public;
 end


 function gf()
  
  -- finite field with base 2 and modulo irreducible polynom x^8+x^4+x^3+x+1 = 0x11d
  local private = {};
  local public = {};
  
  aeslua.gf = public;
  
  -- private data of gf
  private.n = 0x100;
  private.ord = 0xff;
  private.irrPolynom = 0x11b;
  private.exp = {};
  private.log = {};
  
  --
  -- add two polynoms (its simply xor)
  --
  function public.add(operand1, operand2) 
  	return bit.bxor(operand1,operand2);
  end
  
  -- 
  -- subtract two polynoms (same as addition)
  --
  function public.sub(operand1, operand2) 
  	return bit.bxor(operand1,operand2);
  end
  
  --
  -- inverts element
  -- a^(-1) = g^(order - log(a))
  --
  function public.invert(operand)
  	-- special case for 1 
  	if (operand == 1) then
  		return 1;
  	end;
  	-- normal invert
  	local exponent = private.ord - private.log[operand];
  	return private.exp[exponent];
  end
  
  --
  -- multiply two elements using a logarithm table
  -- a*b = g^(log(a)+log(b))
  --
  function public.mul(operand1, operand2)
      if (operand1 == 0 or operand2 == 0) then
          return 0;
      end
  	
      local exponent = private.log[operand1] + private.log[operand2];
  	if (exponent >= private.ord) then
  		exponent = exponent - private.ord;
  	end
  	return  private.exp[exponent];
  end
  
  --
  -- divide two elements
  -- a/b = g^(log(a)-log(b))
  --
  function public.div(operand1, operand2)
      if (operand1 == 0)  then
          return 0;
      end
      -- TODO: exception if operand2 == 0
  	local exponent = private.log[operand1] - private.log[operand2];
  	if (exponent < 0) then
  		exponent = exponent + private.ord;
  	end
  	return private.exp[exponent];
  end
  
  --
  -- print logarithmic table
  --
  function public.printLog()
  	for i = 1, private.n do
  		print("log(", i-1, ")=", private.log[i-1]);
  	end
  end
  
  --
  -- print exponentiation table
  --
  function public.printExp()
  	for i = 1, private.n do
  		print("exp(", i-1, ")=", private.exp[i-1]);
  	end
  end
  
  --
  -- calculate logarithmic and exponentiation table
  --
  function private.initMulTable()
  	local a = 1;
  
  	for i = 0,private.ord-1 do
      	private.exp[i] = a;
  		private.log[a] = i;
  
  		-- multiply with generator x+1 -> left shift + 1	
  		a = bit.bxor(bit.lshift(a, 1), a);
  
  		-- if a gets larger than order, reduce modulo irreducible polynom
  		if a > private.ord then
  			a = public.sub(a, private.irrPolynom);
  		end
  	end
  end
  
  private.initMulTable();
  
  return public;
 end

 
 function util()
  
  local public = {};
  local private = {};
  
  aeslua.util = public;
  
  --
  -- calculate the parity of one byte
  --
  function public.byteParity(byte)
      byte = bit.bxor(byte, bit.rshift(byte, 4));
      byte = bit.bxor(byte, bit.rshift(byte, 2));
      byte = bit.bxor(byte, bit.rshift(byte, 1));
      return bit.band(byte, 1);
  end
  
  -- 
  -- get byte at position index
  --
  function public.getByte(number, index)
      if (index == 0) then
          return bit.band(number,0xff);
      else
          return bit.band(bit.rshift(number, index*8),0xff);
      end
  end
  
  
  --
  -- put number into int at position index
  --
  function public.putByte(number, index)
      if (index == 0) then
          return bit.band(number,0xff);
      else
          return bit.lshift(bit.band(number,0xff),index*8);
      end
  end
  
  --
  -- convert byte array to int array
  --
  function public.bytesToInts(bytes, start, n)
      local ints = {};
      for i = 0, n - 1 do
          ints[i] = public.putByte(bytes[start + (i*4)    ], 3)
                  + public.putByte(bytes[start + (i*4) + 1], 2) 
                  + public.putByte(bytes[start + (i*4) + 2], 1)    
                  + public.putByte(bytes[start + (i*4) + 3], 0);
      end
      return ints;
  end
  
  --
  -- convert int array to byte array
  --
  function public.intsToBytes(ints, output, outputOffset, n)
      n = n or #ints;
      for i = 0, n do
          for j = 0,3 do
              output[outputOffset + i*4 + (3 - j)] = public.getByte(ints[i], j);
          end
      end
      return output;
  end
  
  --
  -- convert bytes to hexString
  --
  function private.bytesToHex(bytes)
      local hexBytes = "";
      
      for i,byte in ipairs(bytes) do 
          hexBytes = hexBytes .. string.format("%02x ", byte);
      end
  
      return hexBytes;
  end
  
  --
  -- convert data to hex string
  --
  function public.toHexString(data)
      local type = type(data);
      if (type == "number") then
          return string.format("%08x",data);
      elseif (type == "table") then
          return private.bytesToHex(data);
      elseif (type == "string") then
          local bytes = {string.byte(data, 1, #data)}; 
  
          return private.bytesToHex(bytes);
      else
          return data;
      end
  end
  
  function public.padByteString(data)
      local dataLength = #data;
      
      local random1 = math.random(0,255);
      local random2 = math.random(0,255);
  
      local prefix = string.char(random1,
                                 random2,
                                 random1,
                                 random2,
                                 public.getByte(dataLength, 3),
                                 public.getByte(dataLength, 2),
                                 public.getByte(dataLength, 1),
                                 public.getByte(dataLength, 0));
  
      data = prefix .. data;
  
      local paddingLength = math.ceil(#data/16)*16 - #data;
      local padding = "";
      for i=1,paddingLength do
          padding = padding .. string.char(math.random(0,255));
      end 
  
      return data .. padding;
  end
  
  function private.properlyDecrypted(data)
      local random = {string.byte(data,1,4)};
  
      if (random[1] == random[3] and random[2] == random[4]) then
          return true;
      end
      
      return false;
  end
  
  function public.unpadByteString(data)
      if (not private.properlyDecrypted(data)) then
          return nil;
      end
  
      local dataLength = public.putByte(string.byte(data,5), 3)
                       + public.putByte(string.byte(data,6), 2) 
                       + public.putByte(string.byte(data,7), 1)    
                       + public.putByte(string.byte(data,8), 0);
      
      return string.sub(data,9,8+dataLength);
  end
  
  function public.xorIV(data, iv)
      for i = 1,16 do
          data[i] = bit.bxor(data[i], iv[i]);
      end 
  end
  
  return public;
 end


 local private = {};
 local public = {};
 aeslua = public;
 
 local ciphermode = ciphermode();
 local util = util();
 
 --
 -- Simple API for encrypting strings.
 --
 
 public.AES128 = 16;
 public.AES192 = 24;
 public.AES256 = 32;
 
 public.ECBMODE = 1;
 public.CBCMODE = 2;
 public.OFBMODE = 3;
 public.CFBMODE = 4;
 
 function private.pwToKey(password, keyLength)
     local padLength = keyLength;
     if (keyLength == public.AES192) then
         padLength = 32;
     end
     
     if (padLength > #password) then
         local postfix = "";
         for i = 1,padLength - #password do
             postfix = postfix .. string.char(0);
         end
         password = password .. postfix;
     else
         password = string.sub(password, 1, padLength);
     end
     
     local pwBytes = {string.byte(password,1,#password)};
     password = ciphermode.encryptString(pwBytes, password, ciphermode.encryptCBC);
     
     password = string.sub(password, 1, keyLength);
    
     return {string.byte(password,1,#password)};
 end
 
 --
 -- Encrypts string data with password password.
 -- password  - the encryption key is generated from this string
 -- data      - string to encrypt (must not be too large)
 -- keyLength - length of aes key: 128(default), 192 or 256 Bit
 -- mode      - mode of encryption: ecb, cbc(default), ofb, cfb 
 --
 -- mode and keyLength must be the same for encryption and decryption.
 --
 function public.encrypt(password, data, keyLength, mode)
 	assert(password ~= nil, "Empty password.");
 	assert(data ~= nil, "Empty data.");
 	 
     local mode = mode or public.CBCMODE;
     local keyLength = keyLength or public.AES128;
 
     local key = private.pwToKey(password, keyLength);
 
     local paddedData = util.padByteString(data);
     
     if (mode == public.ECBMODE) then
         return ciphermode.encryptString(key, paddedData, ciphermode.encryptECB);
     elseif (mode == public.CBCMODE) then
         return ciphermode.encryptString(key, paddedData, ciphermode.encryptCBC);
     elseif (mode == public.OFBMODE) then
         return ciphermode.encryptString(key, paddedData, ciphermode.encryptOFB);
     elseif (mode == public.CFBMODE) then
         return ciphermode.encryptString(key, paddedData, ciphermode.encryptCFB);
     else
         return nil;
     end
 end
 
 
 
 
 --
 -- Decrypts string data with password password.
 -- password  - the decryption key is generated from this string
 -- data      - string to encrypt
 -- keyLength - length of aes key: 128(default), 192 or 256 Bit
 -- mode      - mode of decryption: ecb, cbc(default), ofb, cfb 
 --
 -- mode and keyLength must be the same for encryption and decryption.
 --
 function public.decrypt(password, data, keyLength, mode)
     local mode = mode or public.CBCMODE;
     local keyLength = keyLength or public.AES128;
 
     local key = private.pwToKey(password, keyLength);
     
     local plain;
     if (mode == public.ECBMODE) then
         plain = ciphermode.decryptString(key, data, ciphermode.decryptECB);
     elseif (mode == public.CBCMODE) then
         plain = ciphermode.decryptString(key, data, ciphermode.decryptCBC);
     elseif (mode == public.OFBMODE) then
         plain = ciphermode.decryptString(key, data, ciphermode.decryptOFB);
     elseif (mode == public.CFBMODE) then
         plain = ciphermode.decryptString(key, data, ciphermode.decryptCFB);
     end
     
     result = util.unpadByteString(plain);
     
     if (result == nil) then
         return nil;
     end
     
     return result;
 end
 
 
 -- eja integration to comply with PKCS5 padding and sha256 password hashing
 
 
 function public.ejaPwToKey(password,size)
  return {string.byte(ejaSha256(password):gsub('..', function(cc) return string.char(tonumber(cc, 16)); end),1,size); }
 end
 

 function public.ejaEncrypt(password, data, size, mode)
  local pBytes=(16-(#data % 16));
  local pString="";
  for i=1,pBytes do
   pString=pString..string.char(pBytes);
  end
  paddedData=data..pString;

  local key=public.ejaPwToKey(password,size)

  if (mode == public.ECBMODE) then
   return ciphermode.encryptString(key, paddedData, ciphermode.encryptECB);
  elseif (mode == public.CBCMODE) then
   return ciphermode.encryptString(key, paddedData, ciphermode.encryptCBC);
  elseif (mode == public.OFBMODE) then
   return ciphermode.encryptString(key, paddedData, ciphermode.encryptOFB);
  elseif (mode == public.CFBMODE) then
   return ciphermode.encryptString(key, paddedData, ciphermode.encryptCFB);
  else
   return nil;
  end
 end
 
 
 function public.ejaDecrypt(password, data, size, mode)
  local key=public.ejaPwToKey(password,size)
  local plain;
  if (mode == public.ECBMODE) then
   plain = ciphermode.decryptString(key, data, ciphermode.decryptECB);
  elseif (mode == public.CBCMODE) then
   plain = ciphermode.decryptString(key, data, ciphermode.decryptCBC);
  elseif (mode == public.OFBMODE) then
   plain = ciphermode.decryptString(key, data, ciphermode.decryptOFB);
  elseif (mode == public.CFBMODE) then
   plain = ciphermode.decryptString(key, data, ciphermode.decryptCFB);
  end

  local pBytes=string.sub(plain,-1);
  if pBytes then
   pBytes=string.byte(pBytes);
   if pBytes > 0 and pBytes < #plain then
    plain=plain:sub(1,-1-pBytes);
   end
  end

  return plain
 end 
 
 return public;

end

-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

function ejaBase64Encode(data)
 local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function ejaBase64Decode(data)
 local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end
-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaDbPath(name,id)
 local path=eja.pathVar
 if name and name:match('^/') then
  path=path..name:gsub('/([^/]*)$','/eja.%1')
 else
  path=path..'db/eja.'..name
 end
 path=path:gsub('//','/')
 if not ejaFileStat(path) then 
  ejaDirCreatePath(path:gsub('[^/]-$','')) 
 end
 if id then path=path..'.'..id end
 return path
end


function ejaDbPut(name,id,...)
 local o=''
 local a=ejaTablePack(...)
 for i=1,#a do
  o=o..tostring(a[i]):gsub('\t','eJaTaB')..'\t'
 end
 return ejaFileWrite(ejaDbPath(name,id),o)
end


function ejaDbDel(name,id)
 return ejaFileRemove(ejaDbPath(name,id))
end


function ejaDbNew(name,...)
 local last=ejaDbLast(name)+1
 if ejaDbPut(name,last,...) then
  return last
 else
  return nil
 end
end


function ejaDbGet(name,id,regex)
 local data=ejaFileRead(ejaDbPath(name,id))
 if data then
  if regex then
   return data:match(regex)
  else
   local i=0
   local a={}
   for v in data:gmatch('([^\t]*)\t?') do
    if v then a[#a+1]=v:gsub('eJaTaB','\t') end
   end
   a[#a]=nil
   return ejaTableUnpack(a)
  end
 else 
  return false
 end
end


function ejaDbLast(name)
 local last=0
 local path=ejaDbPath(name):match('(.+)/') or ''
 local file=name:match('([^/]-)$') or '' or ''
 local d=ejaDirList(path) or {}
 for k,v in next,d do
  local id=v:match('eja.'..file..'.([0-9]+)')
  if id and ejaNumber(id) > last then last=id end
 end
 return last
end


function ejaDbList(name)
 local a={}
 local path,name=ejaDbPath(name):match('(.-)/?eja%.(%w+)$')
 for k,v in next,ejaDirTable(path) do
  local id=v:match('^eja.'..name..'%.(%d*)$')
  if id then a[#a+1]=ejaNumber(id) end
 end
 return a
end


-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


-- from eja.c
-- function ejaFileStat(p) end
-- function ejaDirList(d) end
-- function ejaDirCreate(d) end


function ejaFileCheck(f)
 if ejaFileStat(f) then
  return true
 else
  return false
 end
end


function ejaFileRead(f)
 local x=io.open(f,'r') 
 local data=''
 if x then
  data=x:read('*a')
  x:close()
  return data
 else
  return false
 end
end


function ejaFileWrite(f,data)
 local x=io.open(f,'w') 
 if not data then data='' end
 if x then
  x:write(data)
  x:close()
  return true
 else
  return false
 end
end


function ejaFileAppend(f,data)
 local x=io.open(f,'a')
 if x then
  x:write(data or '')
  return x:close()
 else
  return false
 end
end


function ejaFileSize(f)
 local fd=io.open(f,'r')
  if fd and fd:read(1) then
   size=fd:seek('end')
   fd:close()
   return size
  else
   return -1
  end
end


function ejaFileCopy(fileIn,fileOut)
 ejaExecute('cp "'..fileIn..'" "'..fileOut..'"')
end


function ejaFileRemove(f)
 return os.remove(f)
end


function ejaFileMove(old, new)
 ejaExecute('mv "'..old..'" "'..new..'"')
end


function ejaFileLoad(f)
 local ejaScriptRun=assert(loadfile(f))
 if ejaScriptRun then ejaScriptRun() end
end


function ejaFileTmp() 
 if (ejaFileStat("/tmp")) then
  return os.tmpname();
 else
  return eja.pathTmp..'/eja.tmp.file.'..(os.time()+os.clock());
 end
end


function ejaDirListSort(d)	--sort alphabetically
 local t=ejaDirList(d)
 if type(t) == 'table' then 
  table.sort(t)
  return t
 else
  return false
 end
end


function ejaDirTable(d)		--return list as array
 local t=ejaDirList(d)
 local tt={}
 if t then 
  for k,v in next,t do
   if not v:match('^%.$') and not v:match('^%.%.$') then 
    tt[#tt+1]=v
   end
  end
 end 
 return tt
end


function ejaDirTableSort(d)	
 local t=ejaDirTable(d)
 table.sort(t)
 return t
end


function ejaDirListSafe(d)	--no hidden files
 local t=ejaDirList(d)
 local tt={}
 if t then 
  for k,v in next,t do
   if v:match('^[^.]') then 
    tt[#tt+1]=v
   end
  end
  return tt
 else
  return false
 end 
end


function ejaDirCreatePath(p)
 local path=''
 local r=false
 if not p:match('^/') then path='.' end
 for k in p:gmatch('[^/]+') do
  path=path..'/'..k
  if not ejaFileStat(path) then
   r=ejaDirCreate(path)
  end
 end
 return r
end


function ejaDirTree(path)
 local out=''
 for k,v in next,ejaDirTable(path) do
  local x=ejaFileStat(path..'/'..v) 
  if x then
   out=out..ejaSprintf('%10s %06o %s %s\n',x.mtime,x.mode,x.size,path..'/'..v)
   if ejaSprintf('%o',x.mode):sub(-5,1)=='4' then out=out..ejaDirTree(path..'/'..v) end
  end
 end
 return out
end


function ejaDirCheck(path)
 local stat=ejaFileStat(path);
 if stat and ejaSprintf('%o',stat.mode):sub(-5,1) == '4' then
  return true
 else
  return false
 end
end
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

-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>
 
 
function ejaJsonEncode(val, indent, nullVal)
 return ejaJson('encode', val, {indent = indent}, nullVal);
end


function ejaJsonDecode(val, pos)
 return ejaJson('decode', ejaString(val), pos);
end


function ejaJsonFileWrite(file, array)
 local data=ejaJsonEncode(array);
 if data then
  return ejaFileWrite(file,data);
 else
  return nil;
 end
end


function ejaJsonFileRead(file)
 local data=ejaFileRead(file);
 if data then 
  return ejaJsonDecode(data);
 else
  return nil;
 end 
end


function ejaJsonPost(url, array, timeout)
 timeout=timeout or 10;
 local protocol,host,port,path=url:match('(.-)://([^/:]+):?([^/]*)/?(.*)');
 if ejaNumber(port) < 1 then port=80; end
 local fd=ejaWebOpen(host,port,timeout);
 if fd then
  local t={};
  local body=ejaJsonEncode(array);
  local head=ejaSprintf('POST /%s HTTP/1.0\r\nHost: %s\r\nUser-Agent: eja %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: Close\r\n\r\n',path,host,eja.version, #body)
  ejaWebWrite(fd,head);
  ejaWebWrite(fd,body);  
  while true do
   local buf=ejaWebRead(fd,1024);
   if not buf or #buf == 0 then break; end
   t[#t+1]=buf;
  end
  ejaWebClose(fd);
  local header,data=table.concat(t):match('(.-)\r?\n\r?\n(.*)');
  return ejaJsonDecode(data);
 else
  return nil;
 end
end
 
 
function ejaJson(mode,val, posOrState, nullVal)
 --dkjson begin 

 -- Module options:
 local always_try_using_lpeg = true
 local register_global_module_table = false
 local global_module_name = 'json'
 
 --[==[
 
 David Kolf's JSON module for Lua 5.1/5.2
 
 Version 2.5
 
 
 For the documentation see the corresponding readme.txt or visit
 <http://dkolf.de/src/dkjson-lua.fsl/>.
 
 You can contact the author by sending an e-mail to 'david' at the
 domain 'dkolf.de'.
 
 
 Copyright (C) 2010-2013 David Heiko Kolf
 
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the
 "Software"), to deal in the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to
 permit persons to whom the Software is furnished to do so, subject to
 the following conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 
 --]==]
 
 -- global dependencies:
 local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
       pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
 local error, require, pcall, select = error, require, pcall, select
 local floor, huge = math.floor, math.huge
 local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
       string.rep, string.gsub, string.sub, string.byte, string.char,
       string.find, string.len, string.format
 local strmatch = string.match
 local concat = table.concat
 
 local json = { version = "dkjson 2.5" }
 
 if register_global_module_table then
   _G[global_module_name] = json
 end
 
 local _ENV = nil -- blocking globals in Lua 5.2
 
 pcall (function()
   -- Enable access to blocked metatables.
   -- Don't worry, this module doesn't change anything in them.
   local debmeta = require "debug".getmetatable
   if debmeta then getmetatable = debmeta end
 end)
 
 json.null = setmetatable ({}, {
   __tojson = function () return "null" end
 })
 
 local function isarray (tbl)
   local max, n, arraylen = 0, 0, 0
   for k,v in pairs (tbl) do
     if k == 'n' and type(v) == 'number' then
       arraylen = v
       if v > max then
         max = v
       end
     else
       if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
         return false
       end
       if k > max then
         max = k
       end
       n = n + 1
     end
   end
   if max > 10 and max > arraylen and max > n * 2 then
     return false -- don't create an array with too many holes
   end
   return true, max
 end
 
 local escapecodes = {
   ["\""] = "\\\"", ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
   ["\n"] = "\\n",  ["\r"] = "\\r",  ["\t"] = "\\t"
 }
 
 local function escapeutf8 (uchar)
   local value = escapecodes[uchar]
   if value then
     return value
   end
   local a, b, c, d = strbyte (uchar, 1, 4)
   a, b, c, d = a or 0, b or 0, c or 0, d or 0
   if a <= 0x7f then
     value = a
   elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
     value = (a - 0xc0) * 0x40 + b - 0x80
   elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
     value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
   elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
     value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
   else
     return ""
   end
   if value <= 0xffff then
     return strformat ("\\u%.4x", value)
   elseif value <= 0x10ffff then
     -- encode as UTF-16 surrogate pair
     value = value - 0x10000
     local highsur, lowsur = 0xD800 + floor (value/0x400), 0xDC00 + (value % 0x400)
     return strformat ("\\u%.4x\\u%.4x", highsur, lowsur)
   else
     return ""
   end
 end
 
 local function fsub (str, pattern, repl)
   -- gsub always builds a new string in a buffer, even when no match
   -- exists. First using find should be more efficient when most strings
   -- don't contain the pattern.
   if strfind (str, pattern) then
     return gsub (str, pattern, repl)
   else
     return str
   end
 end
 
 local function quotestring (value)
   -- based on the regexp "escapable" in https://github.com/douglascrockford/JSON-js
   value = fsub (value, "[%z\1-\31\"\\\127]", escapeutf8)
   if strfind (value, "[\194\216\220\225\226\239]") then
     value = fsub (value, "\194[\128-\159\173]", escapeutf8)
     value = fsub (value, "\216[\128-\132]", escapeutf8)
     value = fsub (value, "\220\143", escapeutf8)
     value = fsub (value, "\225\158[\180\181]", escapeutf8)
     value = fsub (value, "\226\128[\140-\143\168-\175]", escapeutf8)
     value = fsub (value, "\226\129[\160-\175]", escapeutf8)
     value = fsub (value, "\239\187\191", escapeutf8)
     value = fsub (value, "\239\191[\176-\191]", escapeutf8)
   end
   return "\"" .. value .. "\""
 end
 json.quotestring = quotestring
 
 local function replace(str, o, n)
   local i, j = strfind (str, o, 1, true)
   if i then
     return strsub(str, 1, i-1) .. n .. strsub(str, j+1, -1)
   else
     return str
   end
 end
 
 -- locale independent num2str and str2num functions
 local decpoint, numfilter
 
 local function updatedecpoint ()
   decpoint = strmatch(tostring(0.5), "([^05+])")
   -- build a filter that can be used to remove group separators
   numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
 end
 
 updatedecpoint()
 
 local function num2str (num)
   return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
 end
 
 local function str2num (str)
   local num = tonumber(replace(str, ".", decpoint))
   if not num then
     updatedecpoint()
     num = tonumber(replace(str, ".", decpoint))
   end
   return num
 end
 
 local function addnewline2 (level, buffer, buflen)
   buffer[buflen+1] = "\n"
   buffer[buflen+2] = strrep ("  ", level)
   buflen = buflen + 2
   return buflen
 end
 
 function json.addnewline (state)
   if state.indent then
     state.bufferlen = addnewline2 (state.level or 0,
                            state.buffer, state.bufferlen or #(state.buffer))
   end
 end
 
 local encode2 -- forward declaration
 
 local function addpair (key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
   local kt = type (key)
   if kt ~= 'string' and kt ~= 'number' then
     return nil, "type '" .. kt .. "' is not supported as a key by JSON."
   end
   if prev then
     buflen = buflen + 1
     buffer[buflen] = ","
   end
   if indent then
     buflen = addnewline2 (level, buffer, buflen)
   end
   buffer[buflen+1] = quotestring (key)
   buffer[buflen+2] = ":"
   return encode2 (value, indent, level, buffer, buflen + 2, tables, globalorder, state)
 end
 
 local function appendcustom(res, buffer, state)
   local buflen = state.bufferlen
   if type (res) == 'string' then
     buflen = buflen + 1
     buffer[buflen] = res
   end
   return buflen
 end
 
 local function exception(reason, value, state, buffer, buflen, defaultmessage)
   defaultmessage = defaultmessage or reason
   local handler = state.exception
   if not handler then
     return nil, defaultmessage
   else
     state.bufferlen = buflen
     local ret, msg = handler (reason, value, state, defaultmessage)
     if not ret then return nil, msg or defaultmessage end
     return appendcustom(ret, buffer, state)
   end
 end
 
 function json.encodeexception(reason, value, state, defaultmessage)
   return quotestring("<" .. defaultmessage .. ">")
 end
 
 encode2 = function (value, indent, level, buffer, buflen, tables, globalorder, state)
   local valtype = type (value)
   local valmeta = getmetatable (value)
   valmeta = type (valmeta) == 'table' and valmeta -- only tables
   local valtojson = valmeta and valmeta.__tojson
   if valtojson then
     if tables[value] then
       return exception('reference cycle', value, state, buffer, buflen)
     end
     tables[value] = true
     state.bufferlen = buflen
     local ret, msg = valtojson (value, state)
     if not ret then return exception('custom encoder failed', value, state, buffer, buflen, msg) end
     tables[value] = nil
     buflen = appendcustom(ret, buffer, state)
   elseif value == nil then
     buflen = buflen + 1
     buffer[buflen] = "null"
   elseif valtype == 'number' then
     local s
     if value ~= value or value >= huge or -value >= huge then
       -- This is the behaviour of the original JSON implementation.
       s = "null"
     else
       s = num2str (value)
     end
     buflen = buflen + 1
     buffer[buflen] = s
   elseif valtype == 'boolean' then
     buflen = buflen + 1
     buffer[buflen] = value and "true" or "false"
   elseif valtype == 'string' then
     buflen = buflen + 1
     buffer[buflen] = quotestring (value)
   elseif valtype == 'table' then
     if tables[value] then
       return exception('reference cycle', value, state, buffer, buflen)
     end
     tables[value] = true
     level = level + 1
     local isa, n = isarray (value)
     if n == 0 and valmeta and valmeta.__jsontype == 'object' then
       isa = false
     end
     local msg
     if isa then -- JSON array
       buflen = buflen + 1
       buffer[buflen] = "["
       for i = 1, n do
         buflen, msg = encode2 (value[i], indent, level, buffer, buflen, tables, globalorder, state)
         if not buflen then return nil, msg end
         if i < n then
           buflen = buflen + 1
           buffer[buflen] = ","
         end
       end
       buflen = buflen + 1
       buffer[buflen] = "]"
     else -- JSON object
       local prev = false
       buflen = buflen + 1
       buffer[buflen] = "{"
       local order = valmeta and valmeta.__jsonorder or globalorder
       if order then
         local used = {}
         n = #order
         for i = 1, n do
           local k = order[i]
           local v = value[k]
           if v then
             used[k] = true
             buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
             prev = true -- add a separator before the next element
           end
         end
         for k,v in pairs (value) do
           if not used[k] then
             buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
             if not buflen then return nil, msg end
             prev = true -- add a separator before the next element
           end
         end
       else -- unordered
         for k,v in pairs (value) do
           buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
           if not buflen then return nil, msg end
           prev = true -- add a separator before the next element
         end
       end
       if indent then
         buflen = addnewline2 (level - 1, buffer, buflen)
       end
       buflen = buflen + 1
       buffer[buflen] = "}"
     end
     tables[value] = nil
   else
     return exception ('unsupported type', value, state, buffer, buflen,
       "type '" .. valtype .. "' is not supported by JSON.")
   end
   return buflen
 end
 
 function json.encode (value, state)
   state = state or {}
   local oldbuffer = state.buffer
   local buffer = oldbuffer or {}
   state.buffer = buffer
   updatedecpoint()
   local ret, msg = encode2 (value, state.indent, state.level or 0,
                    buffer, state.bufferlen or 0, state.tables or {}, state.keyorder, state)
   if not ret then
     error (msg, 2)
   elseif oldbuffer == buffer then
     state.bufferlen = ret
     return true
   else
     state.bufferlen = nil
     state.buffer = nil
     return concat (buffer)
   end
 end
 
 local function loc (str, where)
   local line, pos, linepos = 1, 1, 0
   while true do
     pos = strfind (str, "\n", pos, true)
     if pos and pos < where then
       line = line + 1
       linepos = pos
       pos = pos + 1
     else
       break
     end
   end
   return "line " .. line .. ", column " .. (where - linepos)
 end
 
 local function unterminated (str, what, where)
   return nil, strlen (str) + 1, "unterminated " .. what .. " at " .. loc (str, where)
 end
 
 local function scanwhite (str, pos)
   while true do
     pos = strfind (str, "%S", pos)
     if not pos then return nil end
     local sub2 = strsub (str, pos, pos + 1)
     if sub2 == "\239\187" and strsub (str, pos + 2, pos + 2) == "\191" then
       -- UTF-8 Byte Order Mark
       pos = pos + 3
     elseif sub2 == "//" then
       pos = strfind (str, "[\n\r]", pos + 2)
       if not pos then return nil end
     elseif sub2 == "/*" then
       pos = strfind (str, "*/", pos + 2)
       if not pos then return nil end
       pos = pos + 2
     else
       return pos
     end
   end
 end
 
 local escapechars = {
   ["\""] = "\"", ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f",
   ["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
 }
 
 local function unichar (value)
   if value < 0 then
     return nil
   elseif value <= 0x007f then
     return strchar (value)
   elseif value <= 0x07ff then
     return strchar (0xc0 + floor(value/0x40),
                     0x80 + (floor(value) % 0x40))
   elseif value <= 0xffff then
     return strchar (0xe0 + floor(value/0x1000),
                     0x80 + (floor(value/0x40) % 0x40),
                     0x80 + (floor(value) % 0x40))
   elseif value <= 0x10ffff then
     return strchar (0xf0 + floor(value/0x40000),
                     0x80 + (floor(value/0x1000) % 0x40),
                     0x80 + (floor(value/0x40) % 0x40),
                     0x80 + (floor(value) % 0x40))
   else
     return nil
   end
 end
 
 local function scanstring (str, pos)
   local lastpos = pos + 1
   local buffer, n = {}, 0
   while true do
     local nextpos = strfind (str, "[\"\\]", lastpos)
     if not nextpos then
       return unterminated (str, "string", pos)
     end
     if nextpos > lastpos then
       n = n + 1
       buffer[n] = strsub (str, lastpos, nextpos - 1)
     end
     if strsub (str, nextpos, nextpos) == "\"" then
       lastpos = nextpos + 1
       break
     else
       local escchar = strsub (str, nextpos + 1, nextpos + 1)
       local value
       if escchar == "u" then
         value = tonumber (strsub (str, nextpos + 2, nextpos + 5), 16)
         if value then
           local value2
           if 0xD800 <= value and value <= 0xDBff then
             -- we have the high surrogate of UTF-16. Check if there is a
             -- low surrogate escaped nearby to combine them.
             if strsub (str, nextpos + 6, nextpos + 7) == "\\u" then
               value2 = tonumber (strsub (str, nextpos + 8, nextpos + 11), 16)
               if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
                 value = (value - 0xD800)  * 0x400 + (value2 - 0xDC00) + 0x10000
               else
                 value2 = nil -- in case it was out of range for a low surrogate
               end
             end
           end
           value = value and unichar (value)
           if value then
             if value2 then
               lastpos = nextpos + 12
             else
               lastpos = nextpos + 6
             end
           end
         end
       end
       if not value then
         value = escapechars[escchar] or escchar
         lastpos = nextpos + 2
       end
       n = n + 1
       buffer[n] = value
     end
   end
   if n == 1 then
     return buffer[1], lastpos
   elseif n > 1 then
     return concat (buffer), lastpos
   else
     return "", lastpos
   end
 end
 
 local scanvalue -- forward declaration
 
 local function scantable (what, closechar, str, startpos, nullval, objectmeta, arraymeta)
   local len = strlen (str)
   local tbl, n = {}, 0
   local pos = startpos + 1
   if what == 'object' then
     setmetatable (tbl, objectmeta)
   else
     setmetatable (tbl, arraymeta)
   end
   while true do
     pos = scanwhite (str, pos)
     if not pos then return unterminated (str, what, startpos) end
     local char = strsub (str, pos, pos)
     if char == closechar then
       return tbl, pos + 1
     end
     local val1, err
     val1, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
     if err then return nil, pos, err end
     pos = scanwhite (str, pos)
     if not pos then return unterminated (str, what, startpos) end
     char = strsub (str, pos, pos)
     if char == ":" then
       if val1 == nil then
         return nil, pos, "cannot use nil as table index (at " .. loc (str, pos) .. ")"
       end
       pos = scanwhite (str, pos + 1)
       if not pos then return unterminated (str, what, startpos) end
       local val2
       val2, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
       if err then return nil, pos, err end
       tbl[val1] = val2
       pos = scanwhite (str, pos)
       if not pos then return unterminated (str, what, startpos) end
       char = strsub (str, pos, pos)
     else
       n = n + 1
       tbl[n] = val1
     end
     if char == "," then
       pos = pos + 1
     end
   end
 end
 
 scanvalue = function (str, pos, nullval, objectmeta, arraymeta)
   pos = pos or 1
   pos = scanwhite (str, pos)
   if not pos then
     return nil, strlen (str) + 1, "no valid JSON value (reached the end)"
   end
   local char = strsub (str, pos, pos)
   if char == "{" then
     return scantable ('object', "}", str, pos, nullval, objectmeta, arraymeta)
   elseif char == "[" then
     return scantable ('array', "]", str, pos, nullval, objectmeta, arraymeta)
   elseif char == "\"" then
     return scanstring (str, pos)
   else
     local pstart, pend = strfind (str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
     if pstart then
       local number = str2num (strsub (str, pstart, pend))
       if number then
         return number, pend + 1
       end
     end
     pstart, pend = strfind (str, "^%a%w*", pos)
     if pstart then
       local name = strsub (str, pstart, pend)
       if name == "true" then
         return true, pend + 1
       elseif name == "false" then
         return false, pend + 1
       elseif name == "null" then
         return nullval, pend + 1
       end
     end
     return nil, pos, "no valid JSON value at " .. loc (str, pos)
   end
 end
 
 local function optionalmetatables(...)
   if select("#", ...) > 0 then
     return ...
   else
     return {__jsontype = 'object'}, {__jsontype = 'array'}
   end
 end
 
 function json.decode (str, pos, nullval, ...)
   local objectmeta, arraymeta = optionalmetatables(...)
   return scanvalue (str, pos, nullval, objectmeta, arraymeta)
 end
 
 function json.use_lpeg ()
   local g = require ("lpeg")
 
   if g.version() == "0.11" then
     error "due to a bug in LPeg 0.11, it cannot be used for JSON matching"
   end
 
   local pegmatch = g.match
   local P, S, R = g.P, g.S, g.R
 
   local function ErrorCall (str, pos, msg, state)
     if not state.msg then
       state.msg = msg .. " at " .. loc (str, pos)
       state.pos = pos
     end
     return false
   end
 
   local function Err (msg)
     return g.Cmt (g.Cc (msg) * g.Carg (2), ErrorCall)
   end
 
   local SingleLineComment = P"//" * (1 - S"\n\r")^0
   local MultiLineComment = P"/*" * (1 - P"*/")^0 * P"*/"
   local Space = (S" \n\r\t" + P"\239\187\191" + SingleLineComment + MultiLineComment)^0
 
   local PlainChar = 1 - S"\"\\\n\r"
   local EscapeSequence = (P"\\" * g.C (S"\"\\/bfnrt" + Err "unsupported escape sequence")) / escapechars
   local HexDigit = R("09", "af", "AF")
   local function UTF16Surrogate (match, pos, high, low)
     high, low = tonumber (high, 16), tonumber (low, 16)
     if 0xD800 <= high and high <= 0xDBff and 0xDC00 <= low and low <= 0xDFFF then
       return true, unichar ((high - 0xD800)  * 0x400 + (low - 0xDC00) + 0x10000)
     else
       return false
     end
   end
   local function UTF16BMP (hex)
     return unichar (tonumber (hex, 16))
   end
   local U16Sequence = (P"\\u" * g.C (HexDigit * HexDigit * HexDigit * HexDigit))
   local UnicodeEscape = g.Cmt (U16Sequence * U16Sequence, UTF16Surrogate) + U16Sequence/UTF16BMP
   local Char = UnicodeEscape + EscapeSequence + PlainChar
   local String = P"\"" * g.Cs (Char ^ 0) * (P"\"" + Err "unterminated string")
   local Integer = P"-"^(-1) * (P"0" + (R"19" * R"09"^0))
   local Fractal = P"." * R"09"^0
   local Exponent = (S"eE") * (S"+-")^(-1) * R"09"^1
   local Number = (Integer * Fractal^(-1) * Exponent^(-1))/str2num
   local Constant = P"true" * g.Cc (true) + P"false" * g.Cc (false) + P"null" * g.Carg (1)
   local SimpleValue = Number + String + Constant
   local ArrayContent, ObjectContent
 
   -- The functions parsearray and parseobject parse only a single value/pair
   -- at a time and store them directly to avoid hitting the LPeg limits.
   local function parsearray (str, pos, nullval, state)
     local obj, cont
     local npos
     local t, nt = {}, 0
     repeat
       obj, cont, npos = pegmatch (ArrayContent, str, pos, nullval, state)
       if not npos then break end
       pos = npos
       nt = nt + 1
       t[nt] = obj
     until cont == 'last'
     return pos, setmetatable (t, state.arraymeta)
   end
 
   local function parseobject (str, pos, nullval, state)
     local obj, key, cont
     local npos
     local t = {}
     repeat
       key, obj, cont, npos = pegmatch (ObjectContent, str, pos, nullval, state)
       if not npos then break end
       pos = npos
       t[key] = obj
     until cont == 'last'
     return pos, setmetatable (t, state.objectmeta)
   end
 
   local Array = P"[" * g.Cmt (g.Carg(1) * g.Carg(2), parsearray) * Space * (P"]" + Err "']' expected")
   local Object = P"{" * g.Cmt (g.Carg(1) * g.Carg(2), parseobject) * Space * (P"}" + Err "'}' expected")
   local Value = Space * (Array + Object + SimpleValue)
   local ExpectedValue = Value + Space * Err "value expected"
   ArrayContent = Value * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
   local Pair = g.Cg (Space * String * Space * (P":" + Err "colon expected") * ExpectedValue)
   ObjectContent = Pair * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
   local DecodeValue = ExpectedValue * g.Cp ()
 
   function json.decode (str, pos, nullval, ...)
     local state = {}
     state.objectmeta, state.arraymeta = optionalmetatables(...)
     local obj, retpos = pegmatch (DecodeValue, str, pos, nullval, state)
     if state.msg then
       return nil, state.pos, state.msg
     else
       return obj, retpos
     end
   end
 
   -- use this function only once:
   json.use_lpeg = function () return json end
 
   json.using_lpeg = true
 
   return json -- so you can get the module using json = require "dkjson".use_lpeg()
 end
 
 if always_try_using_lpeg then
   pcall (json.use_lpeg)
 end

 --dkjson end
 if mode == 'decode' then
  return json.decode(val, posOrState, nullVal);
 else
  return json.encode(val, posOrState);
 end
 
end


function ejaLuaLexer(text) 
 if not ejaLuaLexerEnable then ejaLuaLexerEnable=ejaLuaLexerFunction() end
 return ejaLuaLexerEnable(text)
end


function ejaLuaLexerFunction()

-- MIT License
-- 
-- Copyright (c) 2018 LoganDark
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

function lookupify(src, list)
	list = list or {}

	if type(src) == 'string' then
		for i = 1, src:len() do
			list[src:sub(i, i)] = true
		end
	elseif type(src) == 'table' then
		for i = 1, #src do
			list[src[i]] = true
		end
	end

	return list
end

local base_ident = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
local base_digits = '0123456789'
local base_operators = '+-*/^%#'

local chars = {
	whitespace = lookupify(' \n\t\r'),
	validEscapes = lookupify('abfnrtv"\'\\'),
	ident = lookupify(
		base_ident .. base_digits,
		{
			start = lookupify(base_ident),
		}
	),

	digits = lookupify(
		base_digits,
		{
			hex = lookupify(base_digits .. 'abcdefABCDEF')
		}
	),

	symbols = lookupify(
		base_operators .. ',{}[]();.:', {
			equality = lookupify('~=><'),
			operators = lookupify(base_operators)
		}
	)
}

local keywords = {
	structure = lookupify({
		'and', 'break', 'do', 'else', 'elseif', 'end', 'for', 'function',
		'goto', 'if', 'in', 'local', 'not', 'or', 'repeat', 'return', 'then',
		'until', 'while'
	}),

	values = lookupify({
		'true', 'false', 'nil'
	})
}

return function(text)
	local pos = 1
	local start = 1
	local buffer = {}
	local lines = {}

	local function look(delta)
		delta = pos + (delta or 0)

		return text:sub(delta, delta)
	end

	local function get()
		pos = pos + 1

		return look(-1)
	end

	local function getDataLevel()
		local num = 0

		while look(num) == '=' do
			num = num + 1
		end

		if look(num) == '[' then
			pos = pos + num + 1

			return num
		end
	end

	local function getCurrentTokenText()
		return text:sub(start, pos - 1)
	end

	local currentLineLength = 0
	local lineoffset = 0

	local function pushToken(type, text)
		text = text or getCurrentTokenText()

		local tk = buffer[#buffer]

		if not tk or tk.type ~= type then
			tk = {
				type = type,
				data = text,
				posFirst = start - lineoffset,
				posLast = pos - 1 - lineoffset
			}

			if tk.data ~= '' then
				buffer[#buffer + 1] = tk
			end
		else
			tk.data = tk.data .. text
			tk.posLast = tk.posLast + text:len()
		end

		currentLineLength = currentLineLength + text:len()
		start = pos

		return tk
	end

	local function newline()
		lines[#lines + 1] = buffer
		buffer = {}

		get()
		pushToken('newline')
		buffer[1] = nil

		lineoffset = lineoffset + currentLineLength
		currentLineLength = 0
	end

	local function getData(level, type)
		while true do
			local char = get()

			if char == '' then
				return
			elseif char == '\n' then
				pos = pos - 1
				pushToken(type)
				newline()
			elseif char == ']' then
				local valid = true

				for i = 1, level do
					if look() == '=' then
						pos = pos + 1
					else
						valid = false
						break
					end
				end

				if valid and look() == ']' then
					pos = pos - level - 1

					return
				end
			end
		end
	end

	local function chompWhitespace()
		while true do
			local char = look()

			if char == '\n' then
				pushToken('whitespace')
				newline()
			elseif chars.whitespace[char] then
				pos = pos + 1
			else
				break
			end
		end

		pushToken('whitespace')
	end

	while true do
		chompWhitespace()

		local char = get()

		if char == '' then
			break
		elseif char == '-' and look() == '-' then
			pos = pos + 1

			if look() == '[' then
				pos = pos + 1

				local level = getDataLevel()

				if level then
					getData(level, 'comment')

					pos = pos + level + 2
					pushToken('comment')
				else
					while true do
						local char2 = get()

						if char2 == '' or char2 == '\n' then
							pos = pos - 1
							pushToken('comment')

							if char2 == '\n' then
								newline()
							end

							break
						end
					end
				end
			else
				while true do
					local char2 = get()

					if char2 == '' or char2 == '\n' then
						pos = pos - 1
						pushToken('comment')

						if char2 == '\n' then
							newline()
						end

						break
					end
				end
			end

			pushToken('comment')
		elseif char == '\'' or char == '"' then
			pushToken('string_start')

			while true do
				local char2 = get()

				if char2 == '\\' then
					pos = pos - 1
					pushToken('string')
					get()

					local char3 = get()

					if chars.digits[char3] then
						for i = 1, 2 do
							if chars.digits[look()] then
								pos = pos + 1
							end
						end
					elseif char3 == 'x' then
						if chars.digits.hex[look()] and chars.digits.hex[look(1)] then
							pos = pos + 2
						else
							pushToken('unidentified')
						end
					elseif char3 == '\n' then
						pos = pos - 1
						pushToken('escape')
						newline()
					elseif not chars.validEscapes[char3] then
						pushToken('unidentified')
					end

					pushToken('escape')
				elseif char2 == '\n' then
					pos = pos - 1
					pushToken('string')
					newline()

					break
				elseif char2 == char or char2 == '' then
					pos = pos - 1
					pushToken('string')
					get()

					break
				end
			end

			pushToken('string_end')
		elseif chars.ident.start[char] then
			while chars.ident[look()] do
				pos = pos + 1
			end

			local word = getCurrentTokenText()

			if keywords.structure[word] then
				pushToken('keyword')
			elseif keywords.values[word] then
				pushToken('value')
			else
				pushToken('ident')
			end
		elseif chars.digits[char] or (char == '.' and chars.digits[look()]) then
			if char == '0' and look() == 'x' then
				pos = pos + 1

				while chars.digits.hex[look()] do
					pos = pos + 1
				end
			else
				while chars.digits[look()] do
					pos = pos + 1
				end

				if look() == '.' then
					pos = pos + 1

					while chars.digits[look()] do
						pos = pos + 1
					end
				end

				if look():lower() == 'e' then
					pos = pos + 1

					if look() == '-' then
						pos = pos + 1
					end

					while chars.digits[look()] do
						pos = pos + 1
					end
				end
			end

			pushToken('number')
		elseif char == '[' then
			local level = getDataLevel()

			if level then
				pushToken('string_start')

				getData(level, 'string')
				pushToken('string')

				pos = pos + level + 2
				pushToken('string_end')
			else
				pushToken('symbol')
			end
		elseif char == '.' then
			if look() == '.' then
				pos = pos + 1

				if look() == '.' then
					pos = pos + 1
				end
			end

			if getCurrentTokenText():len() == 3 then
				pushToken('vararg')
			else
				pushToken('symbol')
			end
		elseif char == ':' and look() == ':' then
			get()

			pushToken('label_start')

			chompWhitespace()

			if chars.ident.start[look()] then
				get()

				while chars.ident[look()] do
					get()
				end

				pushToken('label')

				chompWhitespace()

				if look() == ':' and look(1) == ':' then
					get()
					get()

					pushToken('label_end')
				end
			end
		elseif chars.symbols.equality[char] then
			if look() == '=' then
				pos = pos + 1
			end

			pushToken('operator')
		elseif chars.symbols[char] then
			if chars.symbols.operators[char] then
				pushToken('operator')
			else
				pushToken('symbol')
			end
		else
			pushToken('unidentified')
		end
	end

	lines[#lines + 1] = buffer

	return lines
end

end








-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.mime={} 
 eja.mimeApp={}
end


function ejaLoad()

 if not eja.load then 
  eja.load=1
 else
  eja.load=eja.load+1
 end

 if eja.path or eja.load ~= 3 then return end

 if not _G['ejaPid'] then
  if ejaModuleCheck("posix") then
   ejaRock()
  else
   print("Please use eja or install luaposix.")
   os.exit()
  end
 end

 eja.path=_eja_path or '/'
 eja.pathBin=_eja_path_bin or eja.path..'/usr/bin/'
 eja.pathEtc=_eja_path_etc or eja.path..'/etc/eja/'
 eja.pathLib=_eja_path_lib or eja.path..'/usr/lib/eja/'
 eja.pathVar=_eja_path_var or eja.path..'/var/eja/'
 eja.pathTmp=_eja_path_tmp or eja.path..'/tmp/'
 eja.pathLock=_eja_path_lock or eja.path..'/var/lock/'
 
 package.cpath=eja.pathLib..'?.so;'..package.cpath
 
 t=ejaDirList(eja.pathLib)
 if t then 
  local help=eja.help
  eja.helpFull={}
  table.sort(t)
  for k,v in next,t do
   if v:match('.eja$') then
    eja.help={}
    ejaVmFileLoad(eja.pathLib..v)
    eja.helpFull[v:sub(0,-5)]=eja.help
   end
  end
  eja.help=help
 end

 if #arg > 0 then
  for i in next,arg do
   if arg[i]:match('^%-%-') then
    local k=arg[i]:sub(3):gsub("-(.)",function(x) return x:upper() end)
    if not arg[i+1] or arg[i+1]:match('^%-%-') then 
     eja.opt[k]=''
    else
     eja.opt[k]=arg[i+1]   
    end
   end
  end
  if arg[1]:match('^[^%-%-]') then
   if ejaFileStat(arg[1]) then
    ejaVmFileLoad(arg[1])
   else
    ejaVmFileLoad(eja.pathBin..arg[1])
   end
  end
  ejaRun(eja.opt)
 else
  ejaHelp() 
 end
 
end


ejaLoad();

-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.opt.logFile='/dev/stderr'
eja.opt.logLevel=0
eja.help.logFile='log file {stderr}'
eja.help.logLevel='log level'


function ejaLog(level,message)
 local fd=io.open(eja.opt.logFile,'a')
 fd:write(os.date("%Y-%m-%d %T")..' '..level..' '..message..'\n')
 fd:close()
end


function ejaError(value,...)
 if ejaNumber(eja.opt.logLevel) >= 1 then
  ejaLog("E",ejaSprintf(value,...))
 end
end


function ejaWarn(value,...)
 if ejaNumber(eja.opt.logLevel) >= 2 then 
  ejaLog("W",ejaSprintf(value,...))
 end
end


function ejaInfo(value,...)
 if ejaNumber(eja.opt.logLevel) >= 3 then 
  ejaLog("I",ejaSprintf(value,...))
 end
end


function ejaDebug(value,...)
 if ejaNumber(eja.opt.logLevel) >= 4 then 
  ejaLog("D",ejaSprintf(value,...))
 end
end


function ejaTrace(value,...)
 if ejaNumber(eja.opt.logLevel) >= 5 then 
  ejaLog("T",ejaSprintf(value,...))
 end
end


-- Copyright (C) 2018-2021 by Ubaldo Porcheddu <ubaldo@eja.it>
--
-- die Räubertochter


eja.maria = {
 timeout=10
}


function ejaMariaOpen(host, port, user, pass, database, charset, size)
 local db=ejaMaria():new()
 db:connect({
  host=host or "127.0.0.1",
  port=port or 3306,
  user=user,
  password=pass,
  database=database,
  charset=charset or "utf8",
  max_packet_size=size or (1024*1024)
 })
 if db and ejaNumber(db.state) > 0 then
  eja.maria.db=db
  return true
 else
  return false
 end
end


function ejaMariaQuery(...)
 local a={...}
 local query=nil
 if eja.maria.db then
  if #a > 1 then
   query,err=eja.maria.db:query(ejaSprintf(...)) 
  else
   query,err=eja.maria.db:query(a[1]) 
  end
  if not query and err then 
   ejaError("[maria] query error: %s",err)
   ejaTrace("[maria] query: %s",q)
  end
 end

 return query
end


function ejaMariaClose()
 return eja.maria.db:close()
end


function ejaMaria()
 package.loaded['bit']=bit32
 local ngx={
  say=function() 
   return nil 
  end,
  config={
   ngx_lua_version=9999
  },
  socket={
   tcp=function()
   
    local sock={}
    
    sock.send=function(fd,buf)
     if type(fd)=="table" then fd=eja.maria.fd end
     return ejaSocketWrite(fd,buf),0
    end

    sock.receive=function(fd,count)
     if type(fd)=="table" then fd=eja.maria.fd end
     return ejaSocketRead(fd,count),0
    end
 
    sock.connect=function(self,host,port,pool)
     local fd
     local res=ejaSocketGetAddrInfo(host, port, {family=AF_INET, socktype=SOCK_STREAM})
     if res then
      fd=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
      if fd and ejaSocketConnect(fd,res[1]) then
       ejaSocketOptionSet(fd,SOL_SOCKET,SO_RCVTIMEO,eja.maria.timeout,0)
       ejaSocketOptionSet(fd,SOL_SOCKET,SO_SNDTIMEO,eja.maria.timeout,0)
      end
     end
     eja.maria.fd=fd
     return fd,0
    end
    
    sock.close=function(self)
     if eja.maria.fd then 
      return ejaSocketClose(eja.maria.fd)
     else
      return nil
     end
    end
 
    sock.getreusedtimes=function(self)
     return 0
    end
  
    return sock,0
   end
  },
  sha1_bin=function(val) 
   return ejaSha1(val):gsub('..', function(hexval)
    return string.char(tonumber(hexval, 16));
   end)
  end,
 }


 -- adapted from https://github.com/openresty/lua-resty-mysql/blob/master/lib/resty/mysql.lua
 -- Copyright (C) Yichun Zhang (agentzh)

 
 local bit = require "bit"
 local sub = string.sub
 local tcp = ngx.socket.tcp
 local strbyte = string.byte
 local strchar = string.char
 local strfind = string.find
 local format = string.format
 local strrep = string.rep
 local null = ngx.null
 local band = bit.band
 local bxor = bit.bxor
 local bor = bit.bor
 local lshift = bit.lshift
 local rshift = bit.rshift
 local tohex = bit.tohex
 local sha1 = ngx.sha1_bin
 local concat = table.concat
 local unpack = unpack
 local setmetatable = setmetatable
 local error = error
 local tonumber = tonumber
 
 
 if not ngx.config
    or not ngx.config.ngx_lua_version
    or ngx.config.ngx_lua_version < 9011
 then
     error("ngx_lua 0.9.11+ required")
 end
 
 
 local ok, new_tab = pcall(require, "table.new")
 if not ok then
     new_tab = function (narr, nrec) return {} end
 end
 
 
 local _M = { _VERSION = '0.20' }
 
 
 -- constants
 
 local STATE_CONNECTED = 1
 local STATE_COMMAND_SENT = 2
 
 local COM_QUIT = 0x01
 local COM_QUERY = 0x03
 local CLIENT_SSL = 0x0800
 
 local SERVER_MORE_RESULTS_EXISTS = 8
 
 -- 16MB - 1, the default max allowed packet size used by libmysqlclient
 local FULL_PACKET_SIZE = 16777215
 
 -- the following charset map is generated from the following mysql query:
 --   SELECT CHARACTER_SET_NAME, ID
 --   FROM information_schema.collations
 --   WHERE IS_DEFAULT = 'Yes' ORDER BY id;
 local CHARSET_MAP = {
     _default  = 0,
     big5      = 1,
     dec8      = 3,
     cp850     = 4,
     hp8       = 6,
     koi8r     = 7,
     latin1    = 8,
     latin2    = 9,
     swe7      = 10,
     ascii     = 11,
     ujis      = 12,
     sjis      = 13,
     hebrew    = 16,
     tis620    = 18,
     euckr     = 19,
     koi8u     = 22,
     gb2312    = 24,
     greek     = 25,
     cp1250    = 26,
     gbk       = 28,
     latin5    = 30,
     armscii8  = 32,
     utf8      = 33,
     ucs2      = 35,
     cp866     = 36,
     keybcs2   = 37,
     macce     = 38,
     macroman  = 39,
     cp852     = 40,
     latin7    = 41,
     utf8mb4   = 45,
     cp1251    = 51,
     utf16     = 54,
     utf16le   = 56,
     cp1256    = 57,
     cp1257    = 59,
     utf32     = 60,
     binary    = 63,
     geostd8   = 92,
     cp932     = 95,
     eucjpms   = 97,
     gb18030   = 248
 }
 
 local mt = { __index = _M }
 
 
 -- mysql field value type converters
 local converters = new_tab(0, 9)
 
 for i = 0x01, 0x05 do
     -- tiny, short, long, float, double
     converters[i] = tonumber
 end
 converters[0x00] = tonumber  -- decimal
 -- converters[0x08] = tonumber  -- long long
 converters[0x09] = tonumber  -- int24
 converters[0x0d] = tonumber  -- year
 converters[0xf6] = tonumber  -- newdecimal
 
 
 local function _get_byte2(data, i)
     local a, b = strbyte(data, i, i + 1)
     return bor(a, lshift(b, 8)), i + 2
 end
 
 
 local function _get_byte3(data, i)
     local a, b, c = strbyte(data, i, i + 2)
     return bor(a, lshift(b, 8), lshift(c, 16)), i + 3
 end
 
 
 local function _get_byte4(data, i)
     local a, b, c, d = strbyte(data, i, i + 3)
     return bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24)), i + 4
 end
 
 
 local function _get_byte8(data, i)
     local a, b, c, d, e, f, g, h = strbyte(data, i, i + 7)
 
     -- XXX workaround for the lack of 64-bit support in bitop:
     local lo = bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24))
     local hi = bor(e, lshift(f, 8), lshift(g, 16), lshift(h, 24))
     return lo + hi * 4294967296, i + 8
 
     -- return bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24), lshift(e, 32),
                -- lshift(f, 40), lshift(g, 48), lshift(h, 56)), i + 8
 end
 
 
 local function _set_byte2(n)
     return strchar(band(n, 0xff), band(rshift(n, 8), 0xff))
 end
 
 
 local function _set_byte3(n)
     return strchar(band(n, 0xff),
                    band(rshift(n, 8), 0xff),
                    band(rshift(n, 16), 0xff))
 end
 
 
 local function _set_byte4(n)
     return strchar(band(n, 0xff),
                    band(rshift(n, 8), 0xff),
                    band(rshift(n, 16), 0xff),
                    band(rshift(n, 24), 0xff))
 end
 
 
 local function _from_cstring(data, i)
     local last = strfind(data, "\0", i, true)
     if not last then
         return nil, nil
     end
 
     return sub(data, i, last), last + 1
 end
 
 
 local function _to_cstring(data)
     return data .. "\0"
 end
 
 
 local function _to_binary_coded_string(data)
     return strchar(#data) .. data
 end
 
 
 local function _dump(data)
     local len = #data
     local bytes = new_tab(len, 0)
     for i = 1, len do
         bytes[i] = format("%x", strbyte(data, i))
     end
     return concat(bytes, " ")
 end
 
 
 local function _dumphex(data)
     local len = #data
     local bytes = new_tab(len, 0)
     for i = 1, len do
         bytes[i] = tohex(strbyte(data, i), 2)
     end
     return concat(bytes, " ")
 end
 
 
 local function _compute_token(password, scramble)
     if password == "" then
         return ""
     end
 
     local stage1 = sha1(password)
     local stage2 = sha1(stage1)
     local stage3 = sha1(scramble .. stage2)
     local n = #stage1
     local bytes = new_tab(n, 0)
     for i = 1, n do
          bytes[i] = strchar(bxor(strbyte(stage3, i), strbyte(stage1, i)))
     end
 
     return concat(bytes)
 end
 
 
 local function _send_packet(self, req, size)
     local sock = self.sock
 
     self.packet_no = self.packet_no + 1
 
     ngx.say("packet no: ", self.packet_no)
 
     local packet = _set_byte3(size) .. strchar(band(self.packet_no, 255)) .. req
 
     ngx.say("sending packet: ", _dump(packet))
 
     ngx.say("sending packet... of size " .. #packet)
 
     return sock:send(packet)
 end
 
 
 local function _recv_packet(self)
     local sock = self.sock
 
     local data, err = sock:receive(4) -- packet header
     if not data then
         return nil, nil, "failed to receive packet header: " .. err
     end
 
     ngx.say("packet header: ", _dump(data))
 
     local len, pos = _get_byte3(data, 1)
 
     ngx.say("packet length: ", len)
 
     if len == 0 then
         return nil, nil, "empty packet"
     end
 
     if len > self._max_packet_size then
         return nil, nil, "packet size too big: " .. len
     end
 
     local num = strbyte(data, pos)
 
     ngx.say("recv packet: packet no: ", num)
 
     self.packet_no = num
 
     data, err = sock:receive(len)
 
     ngx.say("receive returned")
 
     if not data then
         return nil, nil, "failed to read packet content: " .. err
     end
 
     ngx.say("packet content: ", _dump(data))
     ngx.say("packet content (ascii): ", data)
 
     local field_count = strbyte(data, 1)
 
     local typ
     if field_count == 0x00 then
         typ = "OK"
     elseif field_count == 0xff then
         typ = "ERR"
     elseif field_count == 0xfe then
         typ = "EOF"
     elseif field_count <= 250 then
         typ = "DATA"
     end
 
     return data, typ
 end
 
 
 local function _from_length_coded_bin(data, pos)
     local first = strbyte(data, pos)
 
     ngx.say("LCB: first: ", first)
 
     if not first then
         return nil, pos
     end
 
     if first >= 0 and first <= 250 then
         return first, pos + 1
     end
 
     if first == 251 then
         return null, pos + 1
     end
 
     if first == 252 then
         pos = pos + 1
         return _get_byte2(data, pos)
     end
 
     if first == 253 then
         pos = pos + 1
         return _get_byte3(data, pos)
     end
 
     if first == 254 then
         pos = pos + 1
         return _get_byte8(data, pos)
     end
 
     return nil, pos + 1
 end
 
 
 local function _from_length_coded_str(data, pos)
     local len
     len, pos = _from_length_coded_bin(data, pos)
     if not len or len == null then
         return null, pos
     end
 
     return sub(data, pos, pos + len - 1), pos + len
 end
 
 
 local function _parse_ok_packet(packet)
     local res = new_tab(0, 5)
     local pos
 
     res.affected_rows, pos = _from_length_coded_bin(packet, 2)
 
     ngx.say("affected rows: ", res.affected_rows, ", pos:", pos)
 
     res.insert_id, pos = _from_length_coded_bin(packet, pos)
 
     ngx.say("insert id: ", res.insert_id, ", pos:", pos)
 
     res.server_status, pos = _get_byte2(packet, pos)
 
     ngx.say("server status: ", res.server_status, ", pos:", pos)
 
     res.warning_count, pos = _get_byte2(packet, pos)
 
     ngx.say("warning count: ", res.warning_count, ", pos: ", pos)
 
     local message = _from_length_coded_str(packet, pos)
     if message and message ~= null then
         res.message = message
     end
 
     ngx.say("message: ", res.message, ", pos:", pos)
 
     return res
 end
 
 
 local function _parse_eof_packet(packet)
     local pos = 2
 
     local warning_count, pos = _get_byte2(packet, pos)
     local status_flags = _get_byte2(packet, pos)
 
     return warning_count, status_flags
 end
 
 
 local function _parse_err_packet(packet)
     local errno, pos = _get_byte2(packet, 2)
     local marker = sub(packet, pos, pos)
     local sqlstate
     if marker == '#' then
         -- with sqlstate
         pos = pos + 1
         sqlstate = sub(packet, pos, pos + 5 - 1)
         pos = pos + 5
     end
 
     local message = sub(packet, pos)
     return errno, message, sqlstate
 end
 
 
 local function _parse_result_set_header_packet(packet)
     local field_count, pos = _from_length_coded_bin(packet, 1)
 
     local extra
     extra = _from_length_coded_bin(packet, pos)
 
     return field_count, extra
 end
 
 
 local function _parse_field_packet(data)
     local col = new_tab(0, 2)
     local catalog, db, table, orig_table, orig_name, charsetnr, length
     local pos
     catalog, pos = _from_length_coded_str(data, 1)
 
     ngx.say("catalog: ", col.catalog, ", pos:", pos)
 
     db, pos = _from_length_coded_str(data, pos)
     table, pos = _from_length_coded_str(data, pos)
     orig_table, pos = _from_length_coded_str(data, pos)
     col.name, pos = _from_length_coded_str(data, pos)
 
     orig_name, pos = _from_length_coded_str(data, pos)
 
     pos = pos + 1 -- ignore the filler
 
     charsetnr, pos = _get_byte2(data, pos)
 
     length, pos = _get_byte4(data, pos)
 
     col.type = strbyte(data, pos)
 
     --[[
     pos = pos + 1
 
     col.flags, pos = _get_byte2(data, pos)
 
     col.decimals = strbyte(data, pos)
     pos = pos + 1
 
     local default = sub(data, pos + 2)
     if default and default ~= "" then
         col.default = default
     end
     --]]
 
     return col
 end
 
 
 local function _parse_row_data_packet(data, cols, compact)
     local pos = 1
     local ncols = #cols
     local row
     if compact then
         row = new_tab(ncols, 0)
     else
         row = new_tab(0, ncols)
     end
     for i = 1, ncols do
         local value
         value, pos = _from_length_coded_str(data, pos)
         local col = cols[i]
         local typ = col.type
         local name = col.name
 
         ngx.say("row field value: ", value, ", type: ", typ)
 
         if value ~= null then
             local conv = converters[typ]
             if conv then
                 value = conv(value)
             end
         end
 
         if compact then
             row[i] = value
 
         else
             row[name] = value
         end
     end
 
     return row
 end
 
 
 local function _recv_field_packet(self)
     local packet, typ, err = _recv_packet(self)
     if not packet then
         return nil, err
     end
 
     if typ == "ERR" then
         local errno, msg, sqlstate = _parse_err_packet(packet)
         return nil, msg, errno, sqlstate
     end
 
     if typ ~= 'DATA' then
         return nil, "bad field packet type: " .. typ
     end
 
     -- typ == 'DATA'
 
     return _parse_field_packet(packet)
 end
 
 
 function _M.new(self)
     local sock, err = tcp()
     if not sock then
         return nil, err
     end
     return setmetatable({ sock = sock }, mt)
 end
 
 
 function _M.set_timeout(self, timeout)
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     return sock:settimeout(timeout)
 end
 
 
 function _M.connect(self, opts)
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     local max_packet_size = opts.max_packet_size
     if not max_packet_size then
         max_packet_size = 1024 * 1024 -- default 1 MB
     end
     self._max_packet_size = max_packet_size
 
     local ok, err
 
     self.compact = opts.compact_arrays
 
     local database = opts.database or ""
     local user = opts.user or ""
 
     local charset = CHARSET_MAP[opts.charset or "_default"]
     if not charset then
         return nil, "charset '" .. opts.charset .. "' is not supported"
     end
 
     local pool = opts.pool
 
     local host = opts.host
     if host then
         local port = opts.port or 3306
         if not pool then
             pool = user .. ":" .. database .. ":" .. host .. ":" .. port
         end
 
         ok, err = sock:connect(host, port, { pool = pool })
 
     else
         local path = opts.path
         if not path then
             return nil, 'neither "host" nor "path" options are specified'
         end
 
         if not pool then
             pool = user .. ":" .. database .. ":" .. path
         end
 
         ok, err = sock:connect("unix:" .. path, { pool = pool })
     end
 
     if not ok then
         return nil, 'failed to connect: ' .. err
     end
 
     local reused = sock:getreusedtimes()
 
     if reused and reused > 0 then
         self.state = STATE_CONNECTED
         return 1
     end
 
     local packet, typ, err = _recv_packet(self)
     if not packet then
         return nil, err
     end
 
     if typ == "ERR" then
         local errno, msg, sqlstate = _parse_err_packet(packet)
         return nil, msg, errno, sqlstate
     end
 
     self.protocol_ver = strbyte(packet)
 
     ngx.say("protocol version: ", self.protocol_ver)
 
     local server_ver, pos = _from_cstring(packet, 2)
     if not server_ver then
         return nil, "bad handshake initialization packet: bad server version"
     end
 
     ngx.say("server version: ", server_ver)
 
     self._server_ver = server_ver
 
     local thread_id, pos = _get_byte4(packet, pos)
 
     ngx.say("thread id: ", thread_id)
 
     local scramble = sub(packet, pos, pos + 8 - 1)
     if not scramble then
         return nil, "1st part of scramble not found"
     end
 
     pos = pos + 9 -- skip filler
 
     -- two lower bytes
     local capabilities  -- server capabilities
     capabilities, pos = _get_byte2(packet, pos)
 
     ngx.say(format("server capabilities: %#x", capabilities))
 
     self._server_lang = strbyte(packet, pos)
     pos = pos + 1
 
     ngx.say("server lang: ", self._server_lang)
 
     self._server_status, pos = _get_byte2(packet, pos)
 
     ngx.say("server status: ", self._server_status)
 
     local more_capabilities
     more_capabilities, pos = _get_byte2(packet, pos)
 
     capabilities = bor(capabilities, lshift(more_capabilities, 16))
 
     ngx.say("server capabilities: ", capabilities)
 
     -- local len = strbyte(packet, pos)
     local len = 21 - 8 - 1
 
     ngx.say("scramble len: ", len)
 
     pos = pos + 1 + 10
 
     local scramble_part2 = sub(packet, pos, pos + len - 1)
     if not scramble_part2 then
         return nil, "2nd part of scramble not found"
     end
 
     scramble = scramble .. scramble_part2
     ngx.say("scramble: ", _dump(scramble))
 
     local client_flags = 0x3f7cf;
 
     local ssl_verify = opts.ssl_verify
     local use_ssl = opts.ssl or ssl_verify
 
     if use_ssl then
         if band(capabilities, CLIENT_SSL) == 0 then
             return nil, "ssl disabled on server"
         end
 
         -- send a SSL Request Packet
         local req = _set_byte4(bor(client_flags, CLIENT_SSL))
                     .. _set_byte4(self._max_packet_size)
                     .. strchar(charset)
                     .. strrep("\0", 23)
 
         local packet_len = 4 + 4 + 1 + 23
         local bytes, err = _send_packet(self, req, packet_len)
         if not bytes then
             return nil, "failed to send client authentication packet: " .. err
         end
 
         local ok, err = sock:sslhandshake(false, nil, ssl_verify)
         if not ok then
             return nil, "failed to do ssl handshake: " .. (err or "")
         end
     end
 
     local password = opts.password or ""
 
     local token = _compute_token(password, scramble)
 
     ngx.say("token: ", _dump(token))
 
     local req = _set_byte4(client_flags)
                 .. _set_byte4(self._max_packet_size)
                 .. strchar(charset)
                 .. strrep("\0", 23)
                 .. _to_cstring(user)
                 .. _to_binary_coded_string(token)
                 .. _to_cstring(database)
 
     local packet_len = 4 + 4 + 1 + 23 + #user + 1
         + #token + 1 + #database + 1
 
     ngx.say("packet content length: ", packet_len)
 --    ngx.say("packet content: ", _dump(concat(req, "")))
 
     local bytes, err = _send_packet(self, req, packet_len)
     if not bytes then
         return nil, "failed to send client authentication packet: " .. err
     end
 
     ngx.say("packet sent ", bytes, " bytes")
 
     local packet, typ, err = _recv_packet(self)
     if not packet then
         return nil, "failed to receive the result packet: " .. err
     end
 
     if typ == 'ERR' then
         local errno, msg, sqlstate = _parse_err_packet(packet)
         return nil, msg, errno, sqlstate
     end
 
     if typ == 'EOF' then
         return nil, "old pre-4.1 authentication protocol not supported"
     end
 
     if typ ~= 'OK' then
         return nil, "bad packet type: " .. typ
     end
 
     self.state = STATE_CONNECTED
 
     return 1
 end
 
 
 function _M.set_keepalive(self, ...)
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     if self.state ~= STATE_CONNECTED then
         return nil, "cannot be reused in the current connection state: "
                     .. (self.state or "nil")
     end
 
     self.state = nil
     return sock:setkeepalive(...)
 end
 
 
 function _M.get_reused_times(self)
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     return sock:getreusedtimes()
 end
 
 
 function _M.close(self)
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     self.state = nil
 
     local bytes, err = _send_packet(self, strchar(COM_QUIT), 1)
     if not bytes then
         return nil, err
     end
 
     return sock:close()
 end
 
 
 function _M.server_ver(self)
     return self._server_ver
 end
 
 
 local function send_query(self, query)
     if self.state ~= STATE_CONNECTED then
         return nil, "cannot send query in the current context: "
                     .. (self.state or "nil")
     end
 
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     self.packet_no = -1
 
     local cmd_packet = strchar(COM_QUERY) .. query
     local packet_len = 1 + #query
 
     local bytes, err = _send_packet(self, cmd_packet, packet_len)
     if not bytes then
         return nil, err
     end
 
     self.state = STATE_COMMAND_SENT
 
     ngx.say("packet sent ", bytes, " bytes")
 
     return bytes
 end
 _M.send_query = send_query
 
 
 local function read_result(self, est_nrows)
     if self.state ~= STATE_COMMAND_SENT then
         return nil, "cannot read result in the current context: "
                     .. (self.state or "nil")
     end
 
     local sock = self.sock
     if not sock then
         return nil, "not initialized"
     end
 
     local packet, typ, err = _recv_packet(self)
     if not packet then
         return nil, err
     end
 
     if typ == "ERR" then
         self.state = STATE_CONNECTED
 
         local errno, msg, sqlstate = _parse_err_packet(packet)
         return nil, msg, errno, sqlstate
     end
 
     if typ == 'OK' then
         local res = _parse_ok_packet(packet)
         if res and band(res.server_status, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
             return res, "again"
         end
 
         self.state = STATE_CONNECTED
         return res
     end
 
     if typ ~= 'DATA' then
         self.state = STATE_CONNECTED
 
         return nil, "packet type " .. typ .. " not supported"
     end
 
     -- typ == 'DATA'
 
     ngx.say("read the result set header packet")
 
     local field_count, extra = _parse_result_set_header_packet(packet)
 
     ngx.say("field count: ", field_count)
 
     local cols = new_tab(field_count, 0)
     for i = 1, field_count do
         local col, err, errno, sqlstate = _recv_field_packet(self)
         if not col then
             return nil, err, errno, sqlstate
         end
 
         cols[i] = col
     end
 
     local packet, typ, err = _recv_packet(self)
     if not packet then
         return nil, err
     end
 
     if typ ~= 'EOF' then
         return nil, "unexpected packet type " .. typ .. " while eof packet is "
             .. "expected"
     end
 
     -- typ == 'EOF'
 
     local compact = self.compact
 
     local rows = new_tab(est_nrows or 4, 0)
     local i = 0
     while true do
         ngx.say("reading a row")
 
         packet, typ, err = _recv_packet(self)
         if not packet then
             return nil, err
         end
 
         if typ == 'EOF' then
             local warning_count, status_flags = _parse_eof_packet(packet)
 
             ngx.say("status flags: ", status_flags)
 
             if band(status_flags, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
                 return rows, "again"
             end
 
             break
         end
 
         -- if typ ~= 'DATA' then
             -- return nil, 'bad row packet type: ' .. typ
         -- end
 
         -- typ == 'DATA'
 
         local row = _parse_row_data_packet(packet, cols, compact)
         i = i + 1
         rows[i] = row
     end
 
     self.state = STATE_CONNECTED

     setmetatable(rows,cols)
 
     return rows
 end
 _M.read_result = read_result
 
 
 function _M.query(self, query, est_nrows)
     local bytes, err = send_query(self, query)
     if not bytes then
         return nil, "failed to send query: " .. err
     end
 
     return read_result(self, est_nrows)
 end
 
 
 function _M.set_compact_arrays(self, value)
     self.compact = value
 end
 
 
 return _M
end
-- Copyright (C) 2007-2013 by Ubaldo Porcheddu <ubaldo@eja.it>
--
-- awk '!/^#/{for(i=2;i<=NF;i++){printf("eja.mime[\"%s\"] =\t\"%s\"\n",$i,$1)}}' /etc/mime.types

eja.mime["ez"] =	"application/andrew-inset"
eja.mime["anx"] =	"application/annodex"
eja.mime["atom"] =	"application/atom+xml"
eja.mime["atomcat"] =	"application/atomcat+xml"
eja.mime["atomsrv"] =	"application/atomserv+xml"
eja.mime["lin"] =	"application/bbolin"
eja.mime["cap"] =	"application/cap"
eja.mime["pcap"] =	"application/cap"
eja.mime["cu"] =	"application/cu-seeme"
eja.mime["davmount"] =	"application/davmount+xml"
eja.mime["tsp"] =	"application/dsptype"
eja.mime["es"] =	"application/ecmascript"
eja.mime["spl"] =	"application/futuresplash"
eja.mime["hta"] =	"application/hta"
eja.mime["jar"] =	"application/java-archive"
eja.mime["ser"] =	"application/java-serialized-object"
eja.mime["class"] =	"application/java-vm"
eja.mime["js"] =	"application/javascript"
eja.mime["json"] =	"application/json"
eja.mime["m3g"] =	"application/m3g"
eja.mime["hqx"] =	"application/mac-binhex40"
eja.mime["cpt"] =	"application/mac-compactpro"
eja.mime["nb"] =	"application/mathematica"
eja.mime["nbp"] =	"application/mathematica"
eja.mime["mdb"] =	"application/msaccess"
eja.mime["doc"] =	"application/msword"
eja.mime["dot"] =	"application/msword"
eja.mime["mxf"] =	"application/mxf"
eja.mime["bin"] =	"application/octet-stream"
eja.mime["oda"] =	"application/oda"
eja.mime["ogx"] =	"application/ogg"
eja.mime["one"] =	"application/onenote"
eja.mime["onetoc2"] =	"application/onenote"
eja.mime["onetmp"] =	"application/onenote"
eja.mime["onepkg"] =	"application/onenote"
eja.mime["pdf"] =	"application/pdf"
eja.mime["key"] =	"application/pgp-keys"
eja.mime["pgp"] =	"application/pgp-signature"
eja.mime["prf"] =	"application/pics-rules"
eja.mime["ps"] =	"application/postscript"
eja.mime["ai"] =	"application/postscript"
eja.mime["eps"] =	"application/postscript"
eja.mime["epsi"] =	"application/postscript"
eja.mime["epsf"] =	"application/postscript"
eja.mime["eps2"] =	"application/postscript"
eja.mime["eps3"] =	"application/postscript"
eja.mime["rar"] =	"application/rar"
eja.mime["rdf"] =	"application/rdf+xml"
eja.mime["rss"] =	"application/rss+xml"
eja.mime["rtf"] =	"application/rtf"
eja.mime["stl"] =	"application/sla"
eja.mime["smi"] =	"application/smil"
eja.mime["smil"] =	"application/smil"
eja.mime["xhtml"] =	"application/xhtml+xml"
eja.mime["xht"] =	"application/xhtml+xml"
eja.mime["xml"] =	"application/xml"
eja.mime["xsl"] =	"application/xml"
eja.mime["xsd"] =	"application/xml"
eja.mime["xspf"] =	"application/xspf+xml"
eja.mime["zip"] =	"application/zip"
eja.mime["apk"] =	"application/vnd.android.package-archive"
eja.mime["cdy"] =	"application/vnd.cinderella"
eja.mime["kml"] =	"application/vnd.google-earth.kml+xml"
eja.mime["kmz"] =	"application/vnd.google-earth.kmz"
eja.mime["xul"] =	"application/vnd.mozilla.xul+xml"
eja.mime["xls"] =	"application/vnd.ms-excel"
eja.mime["xlb"] =	"application/vnd.ms-excel"
eja.mime["xlt"] =	"application/vnd.ms-excel"
eja.mime["xlam"] =	"application/vnd.ms-excel.addin.macroEnabled.12"
eja.mime["xlsb"] =	"application/vnd.ms-excel.sheet.binary.macroEnabled.12"
eja.mime["xlsm"] =	"application/vnd.ms-excel.sheet.macroEnabled.12"
eja.mime["xltm"] =	"application/vnd.ms-excel.template.macroEnabled.12"
eja.mime["thmx"] =	"application/vnd.ms-officetheme"
eja.mime["cat"] =	"application/vnd.ms-pki.seccat"
eja.mime["ppt"] =	"application/vnd.ms-powerpoint"
eja.mime["pps"] =	"application/vnd.ms-powerpoint"
eja.mime["ppam"] =	"application/vnd.ms-powerpoint.addin.macroEnabled.12"
eja.mime["pptm"] =	"application/vnd.ms-powerpoint.presentation.macroEnabled.12"
eja.mime["sldm"] =	"application/vnd.ms-powerpoint.slide.macroEnabled.12"
eja.mime["ppsm"] =	"application/vnd.ms-powerpoint.slideshow.macroEnabled.12"
eja.mime["potm"] =	"application/vnd.ms-powerpoint.template.macroEnabled.12"
eja.mime["docm"] =	"application/vnd.ms-word.document.macroEnabled.12"
eja.mime["dotm"] =	"application/vnd.ms-word.template.macroEnabled.12"
eja.mime["odc"] =	"application/vnd.oasis.opendocument.chart"
eja.mime["odb"] =	"application/vnd.oasis.opendocument.database"
eja.mime["odf"] =	"application/vnd.oasis.opendocument.formula"
eja.mime["odg"] =	"application/vnd.oasis.opendocument.graphics"
eja.mime["otg"] =	"application/vnd.oasis.opendocument.graphics-template"
eja.mime["odi"] =	"application/vnd.oasis.opendocument.image"
eja.mime["odp"] =	"application/vnd.oasis.opendocument.presentation"
eja.mime["otp"] =	"application/vnd.oasis.opendocument.presentation-template"
eja.mime["ods"] =	"application/vnd.oasis.opendocument.spreadsheet"
eja.mime["ots"] =	"application/vnd.oasis.opendocument.spreadsheet-template"
eja.mime["odt"] =	"application/vnd.oasis.opendocument.text"
eja.mime["odm"] =	"application/vnd.oasis.opendocument.text-master"
eja.mime["ott"] =	"application/vnd.oasis.opendocument.text-template"
eja.mime["oth"] =	"application/vnd.oasis.opendocument.text-web"
eja.mime["pptx"] =	"application/vnd.openxmlformats-officedocument.presentationml.presentation"
eja.mime["sldx"] =	"application/vnd.openxmlformats-officedocument.presentationml.slide"
eja.mime["ppsx"] =	"application/vnd.openxmlformats-officedocument.presentationml.slideshow"
eja.mime["potx"] =	"application/vnd.openxmlformats-officedocument.presentationml.template"
eja.mime["xlsx"] =	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
eja.mime["xlsx"] =	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
eja.mime["xltx"] =	"application/vnd.openxmlformats-officedocument.spreadsheetml.template"
eja.mime["xltx"] =	"application/vnd.openxmlformats-officedocument.spreadsheetml.template"
eja.mime["docx"] =	"application/vnd.openxmlformats-officedocument.wordprocessingml.document"
eja.mime["dotx"] =	"application/vnd.openxmlformats-officedocument.wordprocessingml.template"
eja.mime["cod"] =	"application/vnd.rim.cod"
eja.mime["mmf"] =	"application/vnd.smaf"
eja.mime["sdc"] =	"application/vnd.stardivision.calc"
eja.mime["sds"] =	"application/vnd.stardivision.chart"
eja.mime["sda"] =	"application/vnd.stardivision.draw"
eja.mime["sdd"] =	"application/vnd.stardivision.impress"
eja.mime["sdf"] =	"application/vnd.stardivision.math"
eja.mime["sdw"] =	"application/vnd.stardivision.writer"
eja.mime["sgl"] =	"application/vnd.stardivision.writer-global"
eja.mime["sxc"] =	"application/vnd.sun.xml.calc"
eja.mime["stc"] =	"application/vnd.sun.xml.calc.template"
eja.mime["sxd"] =	"application/vnd.sun.xml.draw"
eja.mime["std"] =	"application/vnd.sun.xml.draw.template"
eja.mime["sxi"] =	"application/vnd.sun.xml.impress"
eja.mime["sti"] =	"application/vnd.sun.xml.impress.template"
eja.mime["sxm"] =	"application/vnd.sun.xml.math"
eja.mime["sxw"] =	"application/vnd.sun.xml.writer"
eja.mime["sxg"] =	"application/vnd.sun.xml.writer.global"
eja.mime["stw"] =	"application/vnd.sun.xml.writer.template"
eja.mime["sis"] =	"application/vnd.symbian.install"
eja.mime["vsd"] =	"application/vnd.visio"
eja.mime["wbxml"] =	"application/vnd.wap.wbxml"
eja.mime["wmlc"] =	"application/vnd.wap.wmlc"
eja.mime["wmlsc"] =	"application/vnd.wap.wmlscriptc"
eja.mime["wpd"] =	"application/vnd.wordperfect"
eja.mime["wp5"] =	"application/vnd.wordperfect5.1"
eja.mime["wk"] =	"application/x-123"
eja.mime["7z"] =	"application/x-7z-compressed"
eja.mime["abw"] =	"application/x-abiword"
eja.mime["dmg"] =	"application/x-apple-diskimage"
eja.mime["bcpio"] =	"application/x-bcpio"
eja.mime["torrent"] =	"application/x-bittorrent"
eja.mime["cab"] =	"application/x-cab"
eja.mime["cbr"] =	"application/x-cbr"
eja.mime["cbz"] =	"application/x-cbz"
eja.mime["cdf"] =	"application/x-cdf"
eja.mime["cda"] =	"application/x-cdf"
eja.mime["vcd"] =	"application/x-cdlink"
eja.mime["pgn"] =	"application/x-chess-pgn"
eja.mime["mph"] =	"application/x-comsol"
eja.mime["cpio"] =	"application/x-cpio"
eja.mime["csh"] =	"application/x-csh"
eja.mime["deb"] =	"application/x-debian-package"
eja.mime["udeb"] =	"application/x-debian-package"
eja.mime["dcr"] =	"application/x-director"
eja.mime["dir"] =	"application/x-director"
eja.mime["dxr"] =	"application/x-director"
eja.mime["dms"] =	"application/x-dms"
eja.mime["wad"] =	"application/x-doom"
eja.mime["dvi"] =	"application/x-dvi"
eja.mime["pfa"] =	"application/x-font"
eja.mime["pfb"] =	"application/x-font"
eja.mime["gsf"] =	"application/x-font"
eja.mime["pcf"] =	"application/x-font"
eja.mime["pcf.Z"] =	"application/x-font"
eja.mime["mm"] =	"application/x-freemind"
eja.mime["spl"] =	"application/x-futuresplash"
eja.mime["gan"] =	"application/x-ganttproject"
eja.mime["gnumeric"] =	"application/x-gnumeric"
eja.mime["sgf"] =	"application/x-go-sgf"
eja.mime["gcf"] =	"application/x-graphing-calculator"
eja.mime["gtar"] =	"application/x-gtar"
eja.mime["tgz"] =	"application/x-gtar-compressed"
eja.mime["taz"] =	"application/x-gtar-compressed"
eja.mime["hdf"] =	"application/x-hdf"
eja.mime["rhtml"] =	"application/x-httpd-eruby"
eja.mime["phtml"] =	"application/x-httpd-php"
eja.mime["pht"] =	"application/x-httpd-php"
eja.mime["php"] =	"application/x-httpd-php"
eja.mime["phps"] =	"application/x-httpd-php-source"
eja.mime["php3"] =	"application/x-httpd-php3"
eja.mime["php3p"] =	"application/x-httpd-php3-preprocessed"
eja.mime["php4"] =	"application/x-httpd-php4"
eja.mime["php5"] =	"application/x-httpd-php5"
eja.mime["ica"] =	"application/x-ica"
eja.mime["info"] =	"application/x-info"
eja.mime["ins"] =	"application/x-internet-signup"
eja.mime["isp"] =	"application/x-internet-signup"
eja.mime["iii"] =	"application/x-iphone"
eja.mime["iso"] =	"application/x-iso9660-image"
eja.mime["jam"] =	"application/x-jam"
eja.mime["jnlp"] =	"application/x-java-jnlp-file"
eja.mime["jmz"] =	"application/x-jmol"
eja.mime["chrt"] =	"application/x-kchart"
eja.mime["kil"] =	"application/x-killustrator"
eja.mime["skp"] =	"application/x-koan"
eja.mime["skd"] =	"application/x-koan"
eja.mime["skt"] =	"application/x-koan"
eja.mime["skm"] =	"application/x-koan"
eja.mime["kpr"] =	"application/x-kpresenter"
eja.mime["kpt"] =	"application/x-kpresenter"
eja.mime["ksp"] =	"application/x-kspread"
eja.mime["kwd"] =	"application/x-kword"
eja.mime["kwt"] =	"application/x-kword"
eja.mime["latex"] =	"application/x-latex"
eja.mime["lha"] =	"application/x-lha"
eja.mime["lyx"] =	"application/x-lyx"
eja.mime["lzh"] =	"application/x-lzh"
eja.mime["lzx"] =	"application/x-lzx"
eja.mime["frm"] =	"application/x-maker"
eja.mime["maker"] =	"application/x-maker"
eja.mime["frame"] =	"application/x-maker"
eja.mime["fm"] =	"application/x-maker"
eja.mime["fb"] =	"application/x-maker"
eja.mime["book"] =	"application/x-maker"
eja.mime["fbdoc"] =	"application/x-maker"
eja.mime["mif"] =	"application/x-mif"
eja.mime["m3u8"] =	"application/x-mpegURL"
eja.mime["wmd"] =	"application/x-ms-wmd"
eja.mime["wmz"] =	"application/x-ms-wmz"
eja.mime["com"] =	"application/x-msdos-program"
eja.mime["exe"] =	"application/x-msdos-program"
eja.mime["bat"] =	"application/x-msdos-program"
eja.mime["dll"] =	"application/x-msdos-program"
eja.mime["msi"] =	"application/x-msi"
eja.mime["nc"] =	"application/x-netcdf"
eja.mime["pac"] =	"application/x-ns-proxy-autoconfig"
eja.mime["dat"] =	"application/x-ns-proxy-autoconfig"
eja.mime["nwc"] =	"application/x-nwc"
eja.mime["o"] =	"application/x-object"
eja.mime["oza"] =	"application/x-oz-application"
eja.mime["p7r"] =	"application/x-pkcs7-certreqresp"
eja.mime["crl"] =	"application/x-pkcs7-crl"
eja.mime["pyc"] =	"application/x-python-code"
eja.mime["pyo"] =	"application/x-python-code"
eja.mime["qgs"] =	"application/x-qgis"
eja.mime["shp"] =	"application/x-qgis"
eja.mime["shx"] =	"application/x-qgis"
eja.mime["qtl"] =	"application/x-quicktimeplayer"
eja.mime["rdp"] =	"application/x-rdp"
eja.mime["rpm"] =	"application/x-redhat-package-manager"
eja.mime["rb"] =	"application/x-ruby"
eja.mime["sci"] =	"application/x-scilab"
eja.mime["sce"] =	"application/x-scilab"
eja.mime["sh"] =	"application/x-sh"
eja.mime["shar"] =	"application/x-shar"
eja.mime["swf"] =	"application/x-shockwave-flash"
eja.mime["swfl"] =	"application/x-shockwave-flash"
eja.mime["scr"] =	"application/x-silverlight"
eja.mime["sql"] =	"application/x-sql"
eja.mime["sit"] =	"application/x-stuffit"
eja.mime["sitx"] =	"application/x-stuffit"
eja.mime["sv4cpio"] =	"application/x-sv4cpio"
eja.mime["sv4crc"] =	"application/x-sv4crc"
eja.mime["tar"] =	"application/x-tar"
eja.mime["tcl"] =	"application/x-tcl"
eja.mime["gf"] =	"application/x-tex-gf"
eja.mime["pk"] =	"application/x-tex-pk"
eja.mime["texinfo"] =	"application/x-texinfo"
eja.mime["texi"] =	"application/x-texinfo"
eja.mime["~"] =	"application/x-trash"
eja.mime["%"] =	"application/x-trash"
eja.mime["bak"] =	"application/x-trash"
eja.mime["old"] =	"application/x-trash"
eja.mime["sik"] =	"application/x-trash"
eja.mime["t"] =	"application/x-troff"
eja.mime["tr"] =	"application/x-troff"
eja.mime["roff"] =	"application/x-troff"
eja.mime["man"] =	"application/x-troff-man"
eja.mime["me"] =	"application/x-troff-me"
eja.mime["ms"] =	"application/x-troff-ms"
eja.mime["ustar"] =	"application/x-ustar"
eja.mime["src"] =	"application/x-wais-source"
eja.mime["wz"] =	"application/x-wingz"
eja.mime["crt"] =	"application/x-x509-ca-cert"
eja.mime["xcf"] =	"application/x-xcf"
eja.mime["fig"] =	"application/x-xfig"
eja.mime["xpi"] =	"application/x-xpinstall"
eja.mime["amr"] =	"audio/amr"
eja.mime["awb"] =	"audio/amr-wb"
eja.mime["amr"] =	"audio/amr"
eja.mime["awb"] =	"audio/amr-wb"
eja.mime["axa"] =	"audio/annodex"
eja.mime["au"] =	"audio/basic"
eja.mime["snd"] =	"audio/basic"
eja.mime["csd"] =	"audio/csound"
eja.mime["orc"] =	"audio/csound"
eja.mime["sco"] =	"audio/csound"
eja.mime["flac"] =	"audio/flac"
eja.mime["mid"] =	"audio/midi"
eja.mime["midi"] =	"audio/midi"
eja.mime["kar"] =	"audio/midi"
eja.mime["mpga"] =	"audio/mpeg"
eja.mime["mpega"] =	"audio/mpeg"
eja.mime["mp2"] =	"audio/mpeg"
eja.mime["mp3"] =	"audio/mpeg"
eja.mime["m4a"] =	"audio/mpeg"
eja.mime["m3u"] =	"audio/mpegurl"
eja.mime["oga"] =	"audio/ogg"
eja.mime["ogg"] =	"audio/ogg"
eja.mime["spx"] =	"audio/ogg"
eja.mime["sid"] =	"audio/prs.sid"
eja.mime["aif"] =	"audio/x-aiff"
eja.mime["aiff"] =	"audio/x-aiff"
eja.mime["aifc"] =	"audio/x-aiff"
eja.mime["gsm"] =	"audio/x-gsm"
eja.mime["m3u"] =	"audio/x-mpegurl"
eja.mime["wma"] =	"audio/x-ms-wma"
eja.mime["wax"] =	"audio/x-ms-wax"
eja.mime["ra"] =	"audio/x-pn-realaudio"
eja.mime["rm"] =	"audio/x-pn-realaudio"
eja.mime["ram"] =	"audio/x-pn-realaudio"
eja.mime["ra"] =	"audio/x-realaudio"
eja.mime["pls"] =	"audio/x-scpls"
eja.mime["sd2"] =	"audio/x-sd2"
eja.mime["wav"] =	"audio/x-wav"
eja.mime["alc"] =	"chemical/x-alchemy"
eja.mime["cac"] =	"chemical/x-cache"
eja.mime["cache"] =	"chemical/x-cache"
eja.mime["csf"] =	"chemical/x-cache-csf"
eja.mime["cbin"] =	"chemical/x-cactvs-binary"
eja.mime["cascii"] =	"chemical/x-cactvs-binary"
eja.mime["ctab"] =	"chemical/x-cactvs-binary"
eja.mime["cdx"] =	"chemical/x-cdx"
eja.mime["cer"] =	"chemical/x-cerius"
eja.mime["c3d"] =	"chemical/x-chem3d"
eja.mime["chm"] =	"chemical/x-chemdraw"
eja.mime["cif"] =	"chemical/x-cif"
eja.mime["cmdf"] =	"chemical/x-cmdf"
eja.mime["cml"] =	"chemical/x-cml"
eja.mime["cpa"] =	"chemical/x-compass"
eja.mime["bsd"] =	"chemical/x-crossfire"
eja.mime["csml"] =	"chemical/x-csml"
eja.mime["csm"] =	"chemical/x-csml"
eja.mime["ctx"] =	"chemical/x-ctx"
eja.mime["cxf"] =	"chemical/x-cxf"
eja.mime["cef"] =	"chemical/x-cxf"
eja.mime["emb"] =	"chemical/x-embl-dl-nucleotide"
eja.mime["embl"] =	"chemical/x-embl-dl-nucleotide"
eja.mime["spc"] =	"chemical/x-galactic-spc"
eja.mime["inp"] =	"chemical/x-gamess-input"
eja.mime["gam"] =	"chemical/x-gamess-input"
eja.mime["gamin"] =	"chemical/x-gamess-input"
eja.mime["fch"] =	"chemical/x-gaussian-checkpoint"
eja.mime["fchk"] =	"chemical/x-gaussian-checkpoint"
eja.mime["cub"] =	"chemical/x-gaussian-cube"
eja.mime["gau"] =	"chemical/x-gaussian-input"
eja.mime["gjc"] =	"chemical/x-gaussian-input"
eja.mime["gjf"] =	"chemical/x-gaussian-input"
eja.mime["gal"] =	"chemical/x-gaussian-log"
eja.mime["gcg"] =	"chemical/x-gcg8-sequence"
eja.mime["gen"] =	"chemical/x-genbank"
eja.mime["hin"] =	"chemical/x-hin"
eja.mime["istr"] =	"chemical/x-isostar"
eja.mime["ist"] =	"chemical/x-isostar"
eja.mime["jdx"] =	"chemical/x-jcamp-dx"
eja.mime["dx"] =	"chemical/x-jcamp-dx"
eja.mime["kin"] =	"chemical/x-kinemage"
eja.mime["mcm"] =	"chemical/x-macmolecule"
eja.mime["mmd"] =	"chemical/x-macromodel-input"
eja.mime["mmod"] =	"chemical/x-macromodel-input"
eja.mime["mol"] =	"chemical/x-mdl-molfile"
eja.mime["rd"] =	"chemical/x-mdl-rdfile"
eja.mime["rxn"] =	"chemical/x-mdl-rxnfile"
eja.mime["sd"] =	"chemical/x-mdl-sdfile"
eja.mime["sdf"] =	"chemical/x-mdl-sdfile"
eja.mime["tgf"] =	"chemical/x-mdl-tgf"
eja.mime["mcif"] =	"chemical/x-mmcif"
eja.mime["mol2"] =	"chemical/x-mol2"
eja.mime["b"] =	"chemical/x-molconn-Z"
eja.mime["gpt"] =	"chemical/x-mopac-graph"
eja.mime["mop"] =	"chemical/x-mopac-input"
eja.mime["mopcrt"] =	"chemical/x-mopac-input"
eja.mime["mpc"] =	"chemical/x-mopac-input"
eja.mime["zmt"] =	"chemical/x-mopac-input"
eja.mime["moo"] =	"chemical/x-mopac-out"
eja.mime["mvb"] =	"chemical/x-mopac-vib"
eja.mime["asn"] =	"chemical/x-ncbi-asn1"
eja.mime["prt"] =	"chemical/x-ncbi-asn1-ascii"
eja.mime["ent"] =	"chemical/x-ncbi-asn1-ascii"
eja.mime["val"] =	"chemical/x-ncbi-asn1-binary"
eja.mime["aso"] =	"chemical/x-ncbi-asn1-binary"
eja.mime["asn"] =	"chemical/x-ncbi-asn1-spec"
eja.mime["pdb"] =	"chemical/x-pdb"
eja.mime["ent"] =	"chemical/x-pdb"
eja.mime["ros"] =	"chemical/x-rosdal"
eja.mime["sw"] =	"chemical/x-swissprot"
eja.mime["vms"] =	"chemical/x-vamas-iso14976"
eja.mime["vmd"] =	"chemical/x-vmd"
eja.mime["xtel"] =	"chemical/x-xtel"
eja.mime["xyz"] =	"chemical/x-xyz"
eja.mime["gif"] =	"image/gif"
eja.mime["ief"] =	"image/ief"
eja.mime["jpeg"] =	"image/jpeg"
eja.mime["jpg"] =	"image/jpeg"
eja.mime["jpe"] =	"image/jpeg"
eja.mime["pcx"] =	"image/pcx"
eja.mime["png"] =	"image/png"
eja.mime["svg"] =	"image/svg+xml"
eja.mime["svgz"] =	"image/svg+xml"
eja.mime["tiff"] =	"image/tiff"
eja.mime["tif"] =	"image/tiff"
eja.mime["djvu"] =	"image/vnd.djvu"
eja.mime["djv"] =	"image/vnd.djvu"
eja.mime["wbmp"] =	"image/vnd.wap.wbmp"
eja.mime["cr2"] =	"image/x-canon-cr2"
eja.mime["crw"] =	"image/x-canon-crw"
eja.mime["ras"] =	"image/x-cmu-raster"
eja.mime["cdr"] =	"image/x-coreldraw"
eja.mime["pat"] =	"image/x-coreldrawpattern"
eja.mime["cdt"] =	"image/x-coreldrawtemplate"
eja.mime["cpt"] =	"image/x-corelphotopaint"
eja.mime["erf"] =	"image/x-epson-erf"
eja.mime["ico"] =	"image/x-icon"
eja.mime["art"] =	"image/x-jg"
eja.mime["jng"] =	"image/x-jng"
eja.mime["bmp"] =	"image/x-ms-bmp"
eja.mime["nef"] =	"image/x-nikon-nef"
eja.mime["orf"] =	"image/x-olympus-orf"
eja.mime["psd"] =	"image/x-photoshop"
eja.mime["pnm"] =	"image/x-portable-anymap"
eja.mime["pbm"] =	"image/x-portable-bitmap"
eja.mime["pgm"] =	"image/x-portable-graymap"
eja.mime["ppm"] =	"image/x-portable-pixmap"
eja.mime["rgb"] =	"image/x-rgb"
eja.mime["xbm"] =	"image/x-xbitmap"
eja.mime["xpm"] =	"image/x-xpixmap"
eja.mime["xwd"] =	"image/x-xwindowdump"
eja.mime["eml"] =	"message/rfc822"
eja.mime["igs"] =	"model/iges"
eja.mime["iges"] =	"model/iges"
eja.mime["msh"] =	"model/mesh"
eja.mime["mesh"] =	"model/mesh"
eja.mime["silo"] =	"model/mesh"
eja.mime["wrl"] =	"model/vrml"
eja.mime["vrml"] =	"model/vrml"
eja.mime["x3dv"] =	"model/x3d+vrml"
eja.mime["x3d"] =	"model/x3d+xml"
eja.mime["x3db"] =	"model/x3d+binary"
eja.mime["manifest"] =	"text/cache-manifest"
eja.mime["ics"] =	"text/calendar"
eja.mime["icz"] =	"text/calendar"
eja.mime["css"] =	"text/css"
eja.mime["csv"] =	"text/csv"
eja.mime["323"] =	"text/h323"
eja.mime["html"] =	"text/html"
eja.mime["htm"] =	"text/html"
eja.mime["shtml"] =	"text/html"
eja.mime["uls"] =	"text/iuls"
eja.mime["mml"] =	"text/mathml"
eja.mime["asc"] =	"text/plain"
eja.mime["txt"] =	"text/plain"
eja.mime["text"] =	"text/plain"
eja.mime["pot"] =	"text/plain"
eja.mime["brf"] =	"text/plain"
eja.mime["rtx"] =	"text/richtext"
eja.mime["sct"] =	"text/scriptlet"
eja.mime["wsc"] =	"text/scriptlet"
eja.mime["tm"] =	"text/texmacs"
eja.mime["tsv"] =	"text/tab-separated-values"
eja.mime["jad"] =	"text/vnd.sun.j2me.app-descriptor"
eja.mime["wml"] =	"text/vnd.wap.wml"
eja.mime["wmls"] =	"text/vnd.wap.wmlscript"
eja.mime["bib"] =	"text/x-bibtex"
eja.mime["boo"] =	"text/x-boo"
eja.mime["h++"] =	"text/x-c++hdr"
eja.mime["hpp"] =	"text/x-c++hdr"
eja.mime["hxx"] =	"text/x-c++hdr"
eja.mime["hh"] =	"text/x-c++hdr"
eja.mime["c++"] =	"text/x-c++src"
eja.mime["cpp"] =	"text/x-c++src"
eja.mime["cxx"] =	"text/x-c++src"
eja.mime["cc"] =	"text/x-c++src"
eja.mime["h"] =	"text/x-chdr"
eja.mime["htc"] =	"text/x-component"
eja.mime["csh"] =	"text/x-csh"
eja.mime["c"] =	"text/x-csrc"
eja.mime["d"] =	"text/x-dsrc"
eja.mime["diff"] =	"text/x-diff"
eja.mime["patch"] =	"text/x-diff"
eja.mime["hs"] =	"text/x-haskell"
eja.mime["java"] =	"text/x-java"
eja.mime["lhs"] =	"text/x-literate-haskell"
eja.mime["moc"] =	"text/x-moc"
eja.mime["p"] =	"text/x-pascal"
eja.mime["pas"] =	"text/x-pascal"
eja.mime["gcd"] =	"text/x-pcs-gcd"
eja.mime["pl"] =	"text/x-perl"
eja.mime["pm"] =	"text/x-perl"
eja.mime["py"] =	"text/x-python"
eja.mime["scala"] =	"text/x-scala"
eja.mime["etx"] =	"text/x-setext"
eja.mime["sfv"] =	"text/x-sfv"
eja.mime["sh"] =	"text/x-sh"
eja.mime["tcl"] =	"text/x-tcl"
eja.mime["tk"] =	"text/x-tcl"
eja.mime["tex"] =	"text/x-tex"
eja.mime["ltx"] =	"text/x-tex"
eja.mime["sty"] =	"text/x-tex"
eja.mime["cls"] =	"text/x-tex"
eja.mime["vcs"] =	"text/x-vcalendar"
eja.mime["vcf"] =	"text/x-vcard"
eja.mime["3gp"] =	"video/3gpp"
eja.mime["axv"] =	"video/annodex"
eja.mime["dl"] =	"video/dl"
eja.mime["dif"] =	"video/dv"
eja.mime["dv"] =	"video/dv"
eja.mime["fli"] =	"video/fli"
eja.mime["gl"] =	"video/gl"
eja.mime["mpeg"] =	"video/mpeg"
eja.mime["mpg"] =	"video/mpeg"
eja.mime["mpe"] =	"video/mpeg"
eja.mime["ts"] =	"video/MP2T"
eja.mime["mp4"] =	"video/mp4"
eja.mime["qt"] =	"video/quicktime"
eja.mime["mov"] =	"video/quicktime"
eja.mime["ogv"] =	"video/ogg"
eja.mime["webm"] =	"video/webm"
eja.mime["mxu"] =	"video/vnd.mpegurl"
eja.mime["flv"] =	"video/x-flv"
eja.mime["lsf"] =	"video/x-la-asf"
eja.mime["lsx"] =	"video/x-la-asf"
eja.mime["mng"] =	"video/x-mng"
eja.mime["asf"] =	"video/x-ms-asf"
eja.mime["asx"] =	"video/x-ms-asf"
eja.mime["wm"] =	"video/x-ms-wm"
eja.mime["wmv"] =	"video/x-ms-wmv"
eja.mime["wmx"] =	"video/x-ms-wmx"
eja.mime["wvx"] =	"video/x-ms-wvx"
eja.mime["avi"] =	"video/x-msvideo"
eja.mime["movie"] =	"video/x-sgi-movie"
eja.mime["mpv"] =	"video/x-matroska"
eja.mime["mkv"] =	"video/x-matroska"
eja.mime["ice"] =	"x-conference/x-cooltalk"
eja.mime["sisx"] =	"x-epoc/x-sisx-app"
eja.mime["vrm"] =	"x-world/x-vrml"
eja.mime["vrml"] =	"x-world/x-vrml"
eja.mime["wrl"] =	"x-world/x-vrml"
-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaNumber(i) 
 return tonumber(i) or 0
end


function ejaString(v)
 if type(v) == "number" then 
  return tostring(v) 
 elseif type(v) == "string" then 
  return v 
 else 
  return "" 
 end
end


function ejaSprintf(...)
 --[[!bug: %%%%010d, still not reliable
 local a={...}
 local tag="eJaSpRiNtF_"
 if a[1] then 
  a[1]=a[1]:gsub('%%([-+ #]?[%d]*[%.]?[%d]*[fdiouxXeEfgG])',tag..'%1')
  a[1]=a[1]:gsub('%%([-+ #]?[%d]*[scq])',tag..'%1')
  a[1]=a[1]:gsub('%%','%%%%')
  a[1]=a[1]:gsub(tag,'%%')
  return string.format(table.unpack(a))
 else 
  return "";
 end
 ]]
 return string.format(...)
end


function ejaPrintf(...)
 print(ejaSprintf(...))
end


function ejaXmlEncode(str) 
 if str then 
  return string.gsub(str, "([^%w%s])", function(c) return string.format("&#x%02X;", string.byte(c)) end)
 else 
  return ""
 end
end


function ejaUrlDecode(url)
 return ejaString(url):gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end )
end


function ejaCheck(a,b)    
 if a then
  if b then
   if tonumber(b) then
    return tonumber(a) == tonumber(b)
   else 
    return tostring(a) == tostring(b)
   end
  else --b doesn't exist   
   if type(a) == "table" then
    local i=0;
    for k,v in next,a do i=i+1 end
    if i > 0 then 
     return true 
    else 
     return false
    end
   else
    if tonumber(a) then
     return tonumber(a) > 0
    else
     return a ~= ""
    end
   end 
  end  
 else  
  return false
 end
end 


function ejaOct2Dec(s)
 local z=0;
 for i=#s,1,-1 do
  z=z+tonumber(s:sub(i,i))*8^(#s-i)
 end
 return z;
end


function ejaReadLine(value,...)
 if value then 
  io.write(string.format(value,...)) 
 end
 return io.read('*l')
end


function ejaTime()
 local fd=io.popen('date +%N')
 local tm=ejaNumber(fd:read('*l'))
 fd:close()
 return os.time()+(tm/1000000000)
end
-- Copyright (C) 2007-2014 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaPidWrite(name,pid)
 if not pid then
  pid=ejaPid()
 end
 ejaFileWrite(eja.pathLock..'eja.pid.'..name,pid)
end


function ejaPidKill(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  if ejaKill(pid,9) == 0 then
   ejaFileRemove(eja.pathLock..'eja.pid.'..name)
   ejaTrace('[kill] %d %s',pid,name)
  end
 end
end


function ejaPidKillTree(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  local pidTable=ejaProcPidChildren(pid)
  if ejaKill(pid,9) == 0 then
   for k,v in next,pidTable do 
    ejaTrace('[ejaPidKillTree] kill %d',v)
    ejaKill(v,9) 
   end
   ejaFileRemove(eja.pathLock..'eja.pid.'..name)
   ejaTrace('[ejaPidKillTree] %d %s',pid,name)
  end
 end
end


function ejaPidKillTreeSub(name) 
 local pid=ejaFileRead(eja.pathLock..'eja.pid.'..name)
 if pid and tonumber(pid) > 0 then 
  local pidTable=ejaProcPidChildren(pid)
  for k,v in next,pidTable do 
   ejaTrace('[ejaPidKillTreeSub] kill %d',v)
   ejaKill(v,9) 
  end
 end
end


-- Copyright (C) 2007-2016 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaProcCpuCount()
 local cpuCount=0
 local cpuInfo=ejaFileRead('/sys/devices/system/cpu/present')
 if cpuInfo then
  cpuCount=ejaNumber(cpuInfo:match('[^%d](%d+)'))+1
 else
  cpuInfo=ejaFileRead('/proc/cpuinfo')
  if cpuInfo then
   _,cpuCount=cpuInfo:gsub('processor','')
  end
 end
 return cpuCount
end


function ejaProcCpuSum()
 local procStat=ejaFileRead('/proc/stat')
 local procCpu=0
 if procStat then
  local user,nice,system,idle=procStat:match('[^%d]+ ([%d]+) ([%d]+) ([%d]+) ([%d]+)')
  procCpu=user+nice+system+idle
 end
 return procCpu
end


function ejaProcCpuSumPid(pid)
 local procPidStat=ejaFileRead('/proc/'..pid..'/stat')
 local procPidCpu=0
 local procPidName=''
 if procPidStat then
  local pid,comm,state,ppid,pgrp,session,tty_nr,tpgid,flags,minflt,cminflt,majflt,cmajflt,utime,stime,cutime,cstime=procPidStat:gsub(' +',' '):match('([^ ]+) ([^ ]+) ([^ ]) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)')
  procPidCpu=utime+stime
  procPidName=comm
 end
 return procPidCpu,procPidName
end


function ejaProcCpuCheck(name)
 local a={}
 local procPidList=ejaDirList('/proc/')
 a.sum=ejaProcCpuSum()
 a.time=os.time()
 for _,pid in next,procPidList do
  if pid:match('[%d]+') then
   local pidCpu,pidName=ejaProcCpuSumPid(pid)
   if pidName:match(name) then
    a[pid]=pidCpu
   end
  end
 end
 return a
end


function ejaProcPidChildren(pidCheck, count)
 if not count then count=5 else count=count-1 end
 if count < 1 then return {} end
 local a={}
 local procPidList=ejaDirList('/proc/')
 for _,pid in next,procPidList do
  if pid:match('[%d]+') then
   local data=ejaFileRead('/proc/'..pid..'/stat')
   if data then
    local pidParent=data:gsub(' +',' '):match('[^ ]+ [^ ]+ [^ ] ([^ ]+)')
    if ejaNumber(pidParent) == ejaNumber(pidCheck) then
     a[#a+1]=pid
     local t1=ejaProcPidChildren(pid,count)
     if #t1 > 0 then
      for k,v in next,t1 do
       if not a[v] then a[#a+1]=v end
      end
     end
    end
   end
  end
 end
 return a
end


function ejaProcPidStat(pid)
 local a={}
 local stat=ejaFileRead('/proc/'..ejaNumber(pid)..'/stat') or ''
 for v in stat:gmatch('([^ ]+) ?') do
  a[#a+1]=v
 end
 return a
end


function ejaGetELF()
 local x=io.open('/proc/self/exe','r')
 local out=''
 if x then
  local data=x:read(24)
  if data then out=data:gsub("(.)",function(h) return ejaSprintf('%02X',string.byte(h)) end ) end
  x:close()
 end
 return out
end


function ejaGetMAC(ip)
 local mac=nil
 if ip then 
  local data=ejaFileRead('/proc/net/arp')
  if data then
   for aIp,aMac in data:gmatch('\n(%d+.%d+.%d+.%d+)%s+[^%s]+%s+[^%s]+%s+([^%s]*)') do
    if aIp==ip then mac=aMac; break; end
   end
  end 
 else
  for k,v in next,ejaDirTableSort('/sys/class/net') do
   local arphdr=ejaFileRead('/sys/class/net/'..v..'/type')
   if not mac and ejaNumber(arphdr)==1 then
    mac=ejaFileRead('/sys/class/net/'..v..'/address')
    if mac then
     mac=mac:gsub('\n','')
    end
   end
  end
 end
 return mac or ''
end


-- Copyright (C) 2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaRock()
 local fcntl  		= require 'posix.fcntl'
 local stat  		= require 'posix.sys.stat'
 local dirent 	 	= require 'posix.dirent'
 local unistd 		= require 'posix.unistd'
 local wait		= require 'posix.sys.wait'
 local signal		= require 'posix.signal'
 local sock		= require 'posix.sys.socket'
 
 function ejaFileStat(file)
  local a={}
  local fd=fcntl.open(file,fcntl.O_RDONLY)
  if fd then 
   local x=stat.fstat(fd)
   for k,v in next,x do a[k:sub(4)]=v end
   return a
  else
   return nil
  end
 end
 
 function ejaDirList(path)
  local x,files=pcall(dirent.dir,path)
  if x then 
   return files
  else
   return {}
  end
 end
 
 function ejaFork()
  return unistd.fork()
 end
 
 function ejaForkClean()
  return wait.wait(-1,WNOHANG)
 end
 
 function ejaPid()
  return unistd.getpid()
 end
 
 function ejaKill(pid,sig)
  return signal.kill(pid,sig)
 end
 
 function ejaSleep(t)
  return unistd.sleep(t)
 end
 
 function ejaDirCreate(path,mode) 
  if stat.mkdir(path,mode) == 0 then 
   return true
  else
   return nil
  end
 end
 
 function ejaSocketOpen(domain,type,protocol)
  return sock.socket(domain,type,protocol)
 end
 
 function ejaSocketClose(fd)
  return unistd.close(fd)
 end
 
 function ejaSocketListen(fd,backlog)
  if sock.listen(fd,backlog) == 0 then
   return true
  else
   return nil
  end
 end
 
 function ejaSocketConnect(fd,addr)
  if sock.connect(fd,addr) == 0 then 
   return true
  else
   return nil
  end
 end
 
 function ejaSocketBind(fd,addr)
  if sock.bind(fd,addr) == 0 then
   return true
  else
   return nil
  end
 end
 
 function ejaSocketAccept(fd)
  return sock.accept(fd) 
 end
 
 function ejaSocketRead(fd,count)
  return sock.recv(fd,count)
 end
 
 function ejaSocketWrite(fd,buffer)
  return sock.send(fd,buffer)
 end
 
 function ejaSocketGetAddrInfo(host,service,protocol)
  return sock.getaddrinfo(host,service,protocol)
 end
 
 function ejaSocketReceive(fd,count)
  return sock.recv(fd,count)
 end
 
 function ejaSocketSend(fd,buffer)
  return sock.send(fd,buffer)
 end
 
 function ejaSocketOptionSet(fd,level,optname,val,len)
  if len then 
   return sock.setsockopt (fd,level,optname,val,len)
  else
   return sock.setsockopt (fd,level,optname,val)
  end
 end
 
 for k,v in next,sock do
  if type(v) == "number" then _G[k]=v end
 end
 
end
-- Copyright (C) 2007-2015 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.scan='ejaScan'
eja.help.scan='scanning script {R=record, F=fields}'
eja.help.scanPattern='scanning Lua pattern {%S+}'
eja.help.scanFile='scanning input file {stdin}'
eja.help.scanRecord='scanning input record separator {\\n}'


function ejaScan(script, pattern, file, record)
 local script=script or eja.opt.scanScript or eja.opt.scan or nil
 local pattern=pattern or eja.opt.scanPattern or '%S+'
 local record=record or eja.opt.scanRecord or '\n'
 local file=file or eja.opt.scanFile or '/dev/stdin'

 local tp,ts=script:match('^/(.+)/{?([^}]*)}?$')
 if tp then 
  pattern=tp 
  if #ts < 1 then ts='print(R)' end 
  script='if F and #F>0 then '..ts..' end' 
 end
 if ejaString(script) == '' then script='print(R)' end
 local fx,fe=loadstring('local R,F=...;'..script)

 if fx then
  local fd=io.open(file)
  while fd do
   local row=''
   local c=''
   while c do
    c=fd:read(1)
    if c and (row..c):match(record..'$') then 
     break 
    else
     if c then 
      row=row..c 
     else
      fd:close()
      fd=nil
     end
    end
   end
   if row then
    local fields={} 
    for v in row:gmatch('('..pattern..')') do table.insert(fields,v) end
    fx(row,fields) 
   end
  end
 else
  print(fe)  
 end 
end

-- adapted from http://lua-users.org/wiki/SecureHashAlgorithm


function ejaSha256(value)
 
 value=tostring(value)
 -- Initialize table of round constants
 -- (first 32 bits of the fractional parts of the cube roots of the first
 -- 64 primes 2..311):
 local k = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
   0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
   0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
   0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
   0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
   0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
   0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
   0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
   0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
 }


 -- transform a string of bytes in a string of hexadecimal digits
 local function str2hexa (s)
   local h = string.gsub(s, ".", function(c)
               return string.format("%02x", string.byte(c))
             end)
  return h 
 end


 -- transform number 'l' in a big-endian sequence of 'n' bytes
 -- (coded as a string)
 local function num2s (l, n)
  local s = ""
  for i = 1, n do
    local rem = l % 256
    s = string.char(rem) .. s
    l = (l - rem) / 256
  end
  return s
 end

 -- transform the big-endian sequence of four bytes starting at
 -- index 'i' in 's' into a number
 local function s232num (s, i)
  local n = 0
  for i = i, i + 3 do
    n = n*256 + string.byte(s, i)
  end
  return n
 end


 -- append the bit '1' to the message
 -- append k bits '0', where k is the minimum number >= 0 such that the
 -- resulting message length (in bits) is congruent to 448 (mod 512)
 -- append length of message (before pre-processing), in bits, as 64-bit
 -- big-endian integer
 local function preproc (msg, len)
  local extra = 64 - ((len + 1 + 8) % 64)
  len = num2s(8 * len, 8)    -- original len in bits, coded
  msg = msg .. "\128" .. string.rep("\0", extra) .. len
  assert(#msg % 64 == 0)
  return msg
 end


 local function initH256 (H)
  -- (first 32 bits of the fractional parts of the square roots of the
  -- first 8 primes 2..19):
  H[1] = 0x6a09e667
  H[2] = 0xbb67ae85
  H[3] = 0x3c6ef372
  H[4] = 0xa54ff53a
  H[5] = 0x510e527f
  H[6] = 0x9b05688c
  H[7] = 0x1f83d9ab
  H[8] = 0x5be0cd19
  return H
 end


 local function digestblock (msg, i, H)

    -- break chunk into sixteen 32-bit big-endian words w[1..16]
    local w = {}
    for j = 1, 16 do
      w[j] = s232num(msg, i + (j - 1)*4)
    end

    -- Extend the sixteen 32-bit words into sixty-four 32-bit words:
    for j = 17, 64 do
      local v = w[j - 15]
      local s0 = bit32.bxor(bit32.rrotate(v, 7), bit32.rrotate(v, 18), bit32.rshift(v, 3))
      v = w[j - 2]
      local s1 = bit32.bxor(bit32.rrotate(v, 17), bit32.rrotate(v, 19), bit32.rshift(v, 10))
      w[j] = w[j - 16] + s0 + w[j - 7] + s1
    end

    -- Initialize hash value for this chunk:
    local a, b, c, d, e, f, g, h =
        H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

    -- Main loop:
    for i = 1, 64 do
      local s0 = bit32.bxor(bit32.rrotate(a, 2), bit32.rrotate(a, 13), bit32.rrotate(a, 22))
      local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
      local t2 = s0 + maj
      local s1 = bit32.bxor(bit32.rrotate(e, 6), bit32.rrotate(e, 11), bit32.rrotate(e, 25))
      local ch = bit32.bxor (bit32.band(e, f), bit32.band(bit32.bnot(e), g))
      local t1 = h + s1 + ch + k[i] + w[i]

      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    end

    -- Add (mod 2^32) this chunk's hash to result so far:
    H[1] = bit32.band(H[1] + a)
    H[2] = bit32.band(H[2] + b)
    H[3] = bit32.band(H[3] + c)
    H[4] = bit32.band(H[4] + d)
    H[5] = bit32.band(H[5] + e)
    H[6] = bit32.band(H[6] + f)
    H[7] = bit32.band(H[7] + g)
    H[8] = bit32.band(H[8] + h)

 end


 local function finalresult256 (H)
  -- Produce the final hash value (big-endian):
  return
    str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..
             num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4)..num2s(H[8], 4))
 end


 value = preproc(value, #value)
 local H = initH256({})
 for i = 1, #value, 64 do
  digestblock(value, i, H)
 end

 return finalresult256(H)
end


-- adapted from http://regex.info/blog/lua/sha1


function ejaSha1(value)

 -- Copyright 2009 Jeffrey Friedl
 -- jfriedl@yahoo.com

 --
 -- Return a W32 object for the number zero
 --
 local function ZERO()
    return {
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
       false, false, false, false,     false, false, false, false, 
    }
 end
 
 local hex_to_bits = {
    ["0"] = { false, false, false, false },
    ["1"] = { false, false, false, true  },
    ["2"] = { false, false, true,  false },
    ["3"] = { false, false, true,  true  },
 
    ["4"] = { false, true,  false, false },
    ["5"] = { false, true,  false, true  },
    ["6"] = { false, true,  true,  false },
    ["7"] = { false, true,  true,  true  },
 
    ["8"] = { true,  false, false, false },
    ["9"] = { true,  false, false, true  },
    ["A"] = { true,  false, true,  false },
    ["B"] = { true,  false, true,  true  },
 
    ["C"] = { true,  true,  false, false },
    ["D"] = { true,  true,  false, true  },
    ["E"] = { true,  true,  true,  false },
    ["F"] = { true,  true,  true,  true  },
 
    ["a"] = { true,  false, true,  false },
    ["b"] = { true,  false, true,  true  },
    ["c"] = { true,  true,  false, false },
    ["d"] = { true,  true,  false, true  },
    ["e"] = { true,  true,  true,  false },
    ["f"] = { true,  true,  true,  true  },
 }
 
 --
 -- Given a string of 8 hex digits, return a W32 object representing that number
 --
 local function from_hex(hex)
 
    assert(type(hex) == 'string')
    assert(hex:match('^[0123456789abcdefABCDEF]+$'))
    assert(#hex == 8)
 
    local W32 = { }
 
    for letter in hex:gmatch('.') do
       local b = hex_to_bits[letter]
       assert(b)
       table.insert(W32, 1, b[1])
       table.insert(W32, 1, b[2])
       table.insert(W32, 1, b[3])
       table.insert(W32, 1, b[4])
    end
 
    return W32
 end
 
 local function COPY(old)
    local W32 = { }
    for k,v in pairs(old) do
       W32[k] = v
    end
 
    return W32
 end
 
 local function ADD(first, ...)
 
    local a = COPY(first)
 
    local C, b, sum
 
    for v = 1, select('#', ...) do
       b = select(v, ...)
       C = 0
 
       for i = 1, #a do
          sum = (a[i] and 1 or 0)
              + (b[i] and 1 or 0)
              + C
 
          if sum == 0 then
             a[i] = false
             C    = 0
          elseif sum == 1 then
             a[i] = true
             C    = 0
          elseif sum == 2 then
             a[i] = false
             C    = 1
          else
             a[i] = true
             C    = 1
          end
       end
       -- we drop any ending carry
 
    end
 
    return a
 end
 
 local function XOR(first, ...)
 
    local a = COPY(first)
    local b
    for v = 1, select('#', ...) do
       b = select(v, ...)
       for i = 1, #a do
          a[i] = a[i] ~= b[i]
       end
    end
 
    return a
 
 end
 
 local function AND(a, b)
 
    local c = ZERO()
 
    for i = 1, #a do
       -- only need to set true bits; other bits remain false
       if  a[i] and b[i] then
          c[i] = true
       end
    end
 
    return c
 end
 
 local function OR(a, b)
 
    local c = ZERO()
 
    for i = 1, #a do
       -- only need to set true bits; other bits remain false
       if  a[i] or b[i] then
          c[i] = true
       end
    end
 
    return c
 end
 
 local function OR3(a, b, c)
 
    local d = ZERO()
 
    for i = 1, #a do
       -- only need to set true bits; other bits remain false
       if a[i] or b[i] or c[i] then
          d[i] = true
       end
    end
 
    return d
 end
 
 local function NOT(a)
 
    local b = ZERO()
 
    for i = 1, #a do
       -- only need to set true bits; other bits remain false
       if not a[i] then
          b[i] = true
       end
    end
 
    return b
 end
 
 local function ROTATE(bits, a)
 
    local b = COPY(a)
 
    while bits > 0 do
       bits = bits - 1
       table.insert(b, 1, table.remove(b))
    end
 
    return b
 
 end
 
 
 local binary_to_hex = {
    ["0000"] = "0",
    ["0001"] = "1",
    ["0010"] = "2",
    ["0011"] = "3",
    ["0100"] = "4",
    ["0101"] = "5",
    ["0110"] = "6",
    ["0111"] = "7",
    ["1000"] = "8",
    ["1001"] = "9",
    ["1010"] = "a",
    ["1011"] = "b",
    ["1100"] = "c",
    ["1101"] = "d",
    ["1110"] = "e",
    ["1111"] = "f",
 }
 
 function asHEX(a)
 
    local hex = ""
    local i = 1
    while i < #a do
       local binary = (a[i + 3] and '1' or '0')
                      ..
                      (a[i + 2] and '1' or '0')
                      ..
                      (a[i + 1] and '1' or '0')
                      ..
                      (a[i + 0] and '1' or '0')
 
       hex = binary_to_hex[binary] .. hex
 
       i = i + 4
    end
 
    return hex
 
 end
 
 local x67452301 = from_hex("67452301")
 local xEFCDAB89 = from_hex("EFCDAB89")
 local x98BADCFE = from_hex("98BADCFE")
 local x10325476 = from_hex("10325476")
 local xC3D2E1F0 = from_hex("C3D2E1F0")
 
 local x5A827999 = from_hex("5A827999")
 local x6ED9EBA1 = from_hex("6ED9EBA1")
 local x8F1BBCDC = from_hex("8F1BBCDC")
 local xCA62C1D6 = from_hex("CA62C1D6")
 
 
 function sha1(msg)
 
    assert(type(msg) == 'string')
    assert(#msg < 0x7FFFFFFF) -- have no idea what would happen if it were large
 
    local H0 = x67452301
    local H1 = xEFCDAB89
    local H2 = x98BADCFE
    local H3 = x10325476
    local H4 = xC3D2E1F0
 
    local msg_len_in_bits = #msg * 8
 
    local first_append = string.char(0x80) -- append a '1' bit plus seven '0' bits
 
    local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
    local current_mod = non_zero_message_bytes % 64
    local second_append = ""
    if current_mod ~= 0 then
       second_append = string.rep(string.char(0), 64 - current_mod)
    end
 
    -- now to append the length as a 64-bit number.
    local B1, R1 = math.modf(msg_len_in_bits  / 0x01000000)
    local B2, R2 = math.modf( 0x01000000 * R1 / 0x00010000)
    local B3, R3 = math.modf( 0x00010000 * R2 / 0x00000100)
    local B4     =            0x00000100 * R3
 
    local L64 = string.char( 0) .. string.char( 0) .. string.char( 0) .. string.char( 0) -- high 32 bits
             .. string.char(B1) .. string.char(B2) .. string.char(B3) .. string.char(B4) --  low 32 bits
 
 
 
    msg = msg .. first_append .. second_append .. L64         
 
    assert(#msg % 64 == 0)
 
    --local fd = io.open("/tmp/msg", "wb")
    --fd:write(msg)
    --fd:close()
 
    local chunks = #msg / 64
 
    local W = { }
    local start, A, B, C, D, E, f, K, TEMP
    local chunk = 0
 
    while chunk < chunks do
       --
       -- break chunk up into W[0] through W[15]
       --
       start = chunk * 64 + 1
       chunk = chunk + 1
 
       for t = 0, 15 do
          W[t] = from_hex(string.format("%02x%02x%02x%02x", msg:byte(start, start + 3)))
          start = start + 4
       end
 
       --
       -- build W[16] through W[79]
       --
       for t = 16, 79 do
          -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16). 
          W[t] = ROTATE(1, XOR(W[t-3], W[t-8], W[t-14], W[t-16]))
       end
 
       A = H0
       B = H1
       C = H2
       D = H3
       E = H4
 
       for t = 0, 79 do
          if t <= 19 then
             -- (B AND C) OR ((NOT B) AND D)
             f = OR(AND(B, C), AND(NOT(B), D))
             K = x5A827999
          elseif t <= 39 then
             -- B XOR C XOR D
             f = XOR(B, C, D)
             K = x6ED9EBA1
          elseif t <= 59 then
             -- (B AND C) OR (B AND D) OR (C AND D
             f = OR3(AND(B, C), AND(B, D), AND(C, D))
             K = x8F1BBCDC
          else
             -- B XOR C XOR D
             f = XOR(B, C, D)
             K = xCA62C1D6
          end
 
          -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt; 
          TEMP = ADD(ROTATE(5, A), f, E, W[t], K)
 
          --E = D; 　　D = C; 　　　C = S30(B);　　 B = A; 　　A = TEMP;
          E = D
          D = C
          C = ROTATE(30, B)
          B = A
          A = TEMP
 
          --printf("t = %2d: %s  %s  %s  %s  %s", t, A:HEX(), B:HEX(), C:HEX(), D:HEX(), E:HEX())
       end
 
       -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E. 
       H0 = ADD(H0, A)
       H1 = ADD(H1, B)
       H2 = ADD(H2, C)
       H3 = ADD(H3, D)
       H4 = ADD(H4, E)
    end
 
    return asHEX(H0) .. asHEX(H1) .. asHEX(H2) .. asHEX(H3) .. asHEX(H4)
 end
 
 local function hex_to_binary(hex)
    return hex:gsub('..', function(hexval)
                             return string.char(tonumber(hexval, 16))
                          end)
 end
 
 function sha1_binary(msg)
    return hex_to_binary(sha1(msg))
 end
 
 local xor_with_0x5c = {
    [string.char(  0)] = string.char( 92),   [string.char(  1)] = string.char( 93),
    [string.char(  2)] = string.char( 94),   [string.char(  3)] = string.char( 95),
    [string.char(  4)] = string.char( 88),   [string.char(  5)] = string.char( 89),
    [string.char(  6)] = string.char( 90),   [string.char(  7)] = string.char( 91),
    [string.char(  8)] = string.char( 84),   [string.char(  9)] = string.char( 85),
    [string.char( 10)] = string.char( 86),   [string.char( 11)] = string.char( 87),
    [string.char( 12)] = string.char( 80),   [string.char( 13)] = string.char( 81),
    [string.char( 14)] = string.char( 82),   [string.char( 15)] = string.char( 83),
    [string.char( 16)] = string.char( 76),   [string.char( 17)] = string.char( 77),
    [string.char( 18)] = string.char( 78),   [string.char( 19)] = string.char( 79),
    [string.char( 20)] = string.char( 72),   [string.char( 21)] = string.char( 73),
    [string.char( 22)] = string.char( 74),   [string.char( 23)] = string.char( 75),
    [string.char( 24)] = string.char( 68),   [string.char( 25)] = string.char( 69),
    [string.char( 26)] = string.char( 70),   [string.char( 27)] = string.char( 71),
    [string.char( 28)] = string.char( 64),   [string.char( 29)] = string.char( 65),
    [string.char( 30)] = string.char( 66),   [string.char( 31)] = string.char( 67),
    [string.char( 32)] = string.char(124),   [string.char( 33)] = string.char(125),
    [string.char( 34)] = string.char(126),   [string.char( 35)] = string.char(127),
    [string.char( 36)] = string.char(120),   [string.char( 37)] = string.char(121),
    [string.char( 38)] = string.char(122),   [string.char( 39)] = string.char(123),
    [string.char( 40)] = string.char(116),   [string.char( 41)] = string.char(117),
    [string.char( 42)] = string.char(118),   [string.char( 43)] = string.char(119),
    [string.char( 44)] = string.char(112),   [string.char( 45)] = string.char(113),
    [string.char( 46)] = string.char(114),   [string.char( 47)] = string.char(115),
    [string.char( 48)] = string.char(108),   [string.char( 49)] = string.char(109),
    [string.char( 50)] = string.char(110),   [string.char( 51)] = string.char(111),
    [string.char( 52)] = string.char(104),   [string.char( 53)] = string.char(105),
    [string.char( 54)] = string.char(106),   [string.char( 55)] = string.char(107),
    [string.char( 56)] = string.char(100),   [string.char( 57)] = string.char(101),
    [string.char( 58)] = string.char(102),   [string.char( 59)] = string.char(103),
    [string.char( 60)] = string.char( 96),   [string.char( 61)] = string.char( 97),
    [string.char( 62)] = string.char( 98),   [string.char( 63)] = string.char( 99),
    [string.char( 64)] = string.char( 28),   [string.char( 65)] = string.char( 29),
    [string.char( 66)] = string.char( 30),   [string.char( 67)] = string.char( 31),
    [string.char( 68)] = string.char( 24),   [string.char( 69)] = string.char( 25),
    [string.char( 70)] = string.char( 26),   [string.char( 71)] = string.char( 27),
    [string.char( 72)] = string.char( 20),   [string.char( 73)] = string.char( 21),
    [string.char( 74)] = string.char( 22),   [string.char( 75)] = string.char( 23),
    [string.char( 76)] = string.char( 16),   [string.char( 77)] = string.char( 17),
    [string.char( 78)] = string.char( 18),   [string.char( 79)] = string.char( 19),
    [string.char( 80)] = string.char( 12),   [string.char( 81)] = string.char( 13),
    [string.char( 82)] = string.char( 14),   [string.char( 83)] = string.char( 15),
    [string.char( 84)] = string.char(  8),   [string.char( 85)] = string.char(  9),
    [string.char( 86)] = string.char( 10),   [string.char( 87)] = string.char( 11),
    [string.char( 88)] = string.char(  4),   [string.char( 89)] = string.char(  5),
    [string.char( 90)] = string.char(  6),   [string.char( 91)] = string.char(  7),
    [string.char( 92)] = string.char(  0),   [string.char( 93)] = string.char(  1),
    [string.char( 94)] = string.char(  2),   [string.char( 95)] = string.char(  3),
    [string.char( 96)] = string.char( 60),   [string.char( 97)] = string.char( 61),
    [string.char( 98)] = string.char( 62),   [string.char( 99)] = string.char( 63),
    [string.char(100)] = string.char( 56),   [string.char(101)] = string.char( 57),
    [string.char(102)] = string.char( 58),   [string.char(103)] = string.char( 59),
    [string.char(104)] = string.char( 52),   [string.char(105)] = string.char( 53),
    [string.char(106)] = string.char( 54),   [string.char(107)] = string.char( 55),
    [string.char(108)] = string.char( 48),   [string.char(109)] = string.char( 49),
    [string.char(110)] = string.char( 50),   [string.char(111)] = string.char( 51),
    [string.char(112)] = string.char( 44),   [string.char(113)] = string.char( 45),
    [string.char(114)] = string.char( 46),   [string.char(115)] = string.char( 47),
    [string.char(116)] = string.char( 40),   [string.char(117)] = string.char( 41),
    [string.char(118)] = string.char( 42),   [string.char(119)] = string.char( 43),
    [string.char(120)] = string.char( 36),   [string.char(121)] = string.char( 37),
    [string.char(122)] = string.char( 38),   [string.char(123)] = string.char( 39),
    [string.char(124)] = string.char( 32),   [string.char(125)] = string.char( 33),
    [string.char(126)] = string.char( 34),   [string.char(127)] = string.char( 35),
    [string.char(128)] = string.char(220),   [string.char(129)] = string.char(221),
    [string.char(130)] = string.char(222),   [string.char(131)] = string.char(223),
    [string.char(132)] = string.char(216),   [string.char(133)] = string.char(217),
    [string.char(134)] = string.char(218),   [string.char(135)] = string.char(219),
    [string.char(136)] = string.char(212),   [string.char(137)] = string.char(213),
    [string.char(138)] = string.char(214),   [string.char(139)] = string.char(215),
    [string.char(140)] = string.char(208),   [string.char(141)] = string.char(209),
    [string.char(142)] = string.char(210),   [string.char(143)] = string.char(211),
    [string.char(144)] = string.char(204),   [string.char(145)] = string.char(205),
    [string.char(146)] = string.char(206),   [string.char(147)] = string.char(207),
    [string.char(148)] = string.char(200),   [string.char(149)] = string.char(201),
    [string.char(150)] = string.char(202),   [string.char(151)] = string.char(203),
    [string.char(152)] = string.char(196),   [string.char(153)] = string.char(197),
    [string.char(154)] = string.char(198),   [string.char(155)] = string.char(199),
    [string.char(156)] = string.char(192),   [string.char(157)] = string.char(193),
    [string.char(158)] = string.char(194),   [string.char(159)] = string.char(195),
    [string.char(160)] = string.char(252),   [string.char(161)] = string.char(253),
    [string.char(162)] = string.char(254),   [string.char(163)] = string.char(255),
    [string.char(164)] = string.char(248),   [string.char(165)] = string.char(249),
    [string.char(166)] = string.char(250),   [string.char(167)] = string.char(251),
    [string.char(168)] = string.char(244),   [string.char(169)] = string.char(245),
    [string.char(170)] = string.char(246),   [string.char(171)] = string.char(247),
    [string.char(172)] = string.char(240),   [string.char(173)] = string.char(241),
    [string.char(174)] = string.char(242),   [string.char(175)] = string.char(243),
    [string.char(176)] = string.char(236),   [string.char(177)] = string.char(237),
    [string.char(178)] = string.char(238),   [string.char(179)] = string.char(239),
    [string.char(180)] = string.char(232),   [string.char(181)] = string.char(233),
    [string.char(182)] = string.char(234),   [string.char(183)] = string.char(235),
    [string.char(184)] = string.char(228),   [string.char(185)] = string.char(229),
    [string.char(186)] = string.char(230),   [string.char(187)] = string.char(231),
    [string.char(188)] = string.char(224),   [string.char(189)] = string.char(225),
    [string.char(190)] = string.char(226),   [string.char(191)] = string.char(227),
    [string.char(192)] = string.char(156),   [string.char(193)] = string.char(157),
    [string.char(194)] = string.char(158),   [string.char(195)] = string.char(159),
    [string.char(196)] = string.char(152),   [string.char(197)] = string.char(153),
    [string.char(198)] = string.char(154),   [string.char(199)] = string.char(155),
    [string.char(200)] = string.char(148),   [string.char(201)] = string.char(149),
    [string.char(202)] = string.char(150),   [string.char(203)] = string.char(151),
    [string.char(204)] = string.char(144),   [string.char(205)] = string.char(145),
    [string.char(206)] = string.char(146),   [string.char(207)] = string.char(147),
    [string.char(208)] = string.char(140),   [string.char(209)] = string.char(141),
    [string.char(210)] = string.char(142),   [string.char(211)] = string.char(143),
    [string.char(212)] = string.char(136),   [string.char(213)] = string.char(137),
    [string.char(214)] = string.char(138),   [string.char(215)] = string.char(139),
    [string.char(216)] = string.char(132),   [string.char(217)] = string.char(133),
    [string.char(218)] = string.char(134),   [string.char(219)] = string.char(135),
    [string.char(220)] = string.char(128),   [string.char(221)] = string.char(129),
    [string.char(222)] = string.char(130),   [string.char(223)] = string.char(131),
    [string.char(224)] = string.char(188),   [string.char(225)] = string.char(189),
    [string.char(226)] = string.char(190),   [string.char(227)] = string.char(191),
    [string.char(228)] = string.char(184),   [string.char(229)] = string.char(185),
    [string.char(230)] = string.char(186),   [string.char(231)] = string.char(187),
    [string.char(232)] = string.char(180),   [string.char(233)] = string.char(181),
    [string.char(234)] = string.char(182),   [string.char(235)] = string.char(183),
    [string.char(236)] = string.char(176),   [string.char(237)] = string.char(177),
    [string.char(238)] = string.char(178),   [string.char(239)] = string.char(179),
    [string.char(240)] = string.char(172),   [string.char(241)] = string.char(173),
    [string.char(242)] = string.char(174),   [string.char(243)] = string.char(175),
    [string.char(244)] = string.char(168),   [string.char(245)] = string.char(169),
    [string.char(246)] = string.char(170),   [string.char(247)] = string.char(171),
    [string.char(248)] = string.char(164),   [string.char(249)] = string.char(165),
    [string.char(250)] = string.char(166),   [string.char(251)] = string.char(167),
    [string.char(252)] = string.char(160),   [string.char(253)] = string.char(161),
    [string.char(254)] = string.char(162),   [string.char(255)] = string.char(163),
 }
 
 local xor_with_0x36 = {
    [string.char(  0)] = string.char( 54),   [string.char(  1)] = string.char( 55),
    [string.char(  2)] = string.char( 52),   [string.char(  3)] = string.char( 53),
    [string.char(  4)] = string.char( 50),   [string.char(  5)] = string.char( 51),
    [string.char(  6)] = string.char( 48),   [string.char(  7)] = string.char( 49),
    [string.char(  8)] = string.char( 62),   [string.char(  9)] = string.char( 63),
    [string.char( 10)] = string.char( 60),   [string.char( 11)] = string.char( 61),
    [string.char( 12)] = string.char( 58),   [string.char( 13)] = string.char( 59),
    [string.char( 14)] = string.char( 56),   [string.char( 15)] = string.char( 57),
    [string.char( 16)] = string.char( 38),   [string.char( 17)] = string.char( 39),
    [string.char( 18)] = string.char( 36),   [string.char( 19)] = string.char( 37),
    [string.char( 20)] = string.char( 34),   [string.char( 21)] = string.char( 35),
    [string.char( 22)] = string.char( 32),   [string.char( 23)] = string.char( 33),
    [string.char( 24)] = string.char( 46),   [string.char( 25)] = string.char( 47),
    [string.char( 26)] = string.char( 44),   [string.char( 27)] = string.char( 45),
    [string.char( 28)] = string.char( 42),   [string.char( 29)] = string.char( 43),
    [string.char( 30)] = string.char( 40),   [string.char( 31)] = string.char( 41),
    [string.char( 32)] = string.char( 22),   [string.char( 33)] = string.char( 23),
    [string.char( 34)] = string.char( 20),   [string.char( 35)] = string.char( 21),
    [string.char( 36)] = string.char( 18),   [string.char( 37)] = string.char( 19),
    [string.char( 38)] = string.char( 16),   [string.char( 39)] = string.char( 17),
    [string.char( 40)] = string.char( 30),   [string.char( 41)] = string.char( 31),
    [string.char( 42)] = string.char( 28),   [string.char( 43)] = string.char( 29),
    [string.char( 44)] = string.char( 26),   [string.char( 45)] = string.char( 27),
    [string.char( 46)] = string.char( 24),   [string.char( 47)] = string.char( 25),
    [string.char( 48)] = string.char(  6),   [string.char( 49)] = string.char(  7),
    [string.char( 50)] = string.char(  4),   [string.char( 51)] = string.char(  5),
    [string.char( 52)] = string.char(  2),   [string.char( 53)] = string.char(  3),
    [string.char( 54)] = string.char(  0),   [string.char( 55)] = string.char(  1),
    [string.char( 56)] = string.char( 14),   [string.char( 57)] = string.char( 15),
    [string.char( 58)] = string.char( 12),   [string.char( 59)] = string.char( 13),
    [string.char( 60)] = string.char( 10),   [string.char( 61)] = string.char( 11),
    [string.char( 62)] = string.char(  8),   [string.char( 63)] = string.char(  9),
    [string.char( 64)] = string.char(118),   [string.char( 65)] = string.char(119),
    [string.char( 66)] = string.char(116),   [string.char( 67)] = string.char(117),
    [string.char( 68)] = string.char(114),   [string.char( 69)] = string.char(115),
    [string.char( 70)] = string.char(112),   [string.char( 71)] = string.char(113),
    [string.char( 72)] = string.char(126),   [string.char( 73)] = string.char(127),
    [string.char( 74)] = string.char(124),   [string.char( 75)] = string.char(125),
    [string.char( 76)] = string.char(122),   [string.char( 77)] = string.char(123),
    [string.char( 78)] = string.char(120),   [string.char( 79)] = string.char(121),
    [string.char( 80)] = string.char(102),   [string.char( 81)] = string.char(103),
    [string.char( 82)] = string.char(100),   [string.char( 83)] = string.char(101),
    [string.char( 84)] = string.char( 98),   [string.char( 85)] = string.char( 99),
    [string.char( 86)] = string.char( 96),   [string.char( 87)] = string.char( 97),
    [string.char( 88)] = string.char(110),   [string.char( 89)] = string.char(111),
    [string.char( 90)] = string.char(108),   [string.char( 91)] = string.char(109),
    [string.char( 92)] = string.char(106),   [string.char( 93)] = string.char(107),
    [string.char( 94)] = string.char(104),   [string.char( 95)] = string.char(105),
    [string.char( 96)] = string.char( 86),   [string.char( 97)] = string.char( 87),
    [string.char( 98)] = string.char( 84),   [string.char( 99)] = string.char( 85),
    [string.char(100)] = string.char( 82),   [string.char(101)] = string.char( 83),
    [string.char(102)] = string.char( 80),   [string.char(103)] = string.char( 81),
    [string.char(104)] = string.char( 94),   [string.char(105)] = string.char( 95),
    [string.char(106)] = string.char( 92),   [string.char(107)] = string.char( 93),
    [string.char(108)] = string.char( 90),   [string.char(109)] = string.char( 91),
    [string.char(110)] = string.char( 88),   [string.char(111)] = string.char( 89),
    [string.char(112)] = string.char( 70),   [string.char(113)] = string.char( 71),
    [string.char(114)] = string.char( 68),   [string.char(115)] = string.char( 69),
    [string.char(116)] = string.char( 66),   [string.char(117)] = string.char( 67),
    [string.char(118)] = string.char( 64),   [string.char(119)] = string.char( 65),
    [string.char(120)] = string.char( 78),   [string.char(121)] = string.char( 79),
    [string.char(122)] = string.char( 76),   [string.char(123)] = string.char( 77),
    [string.char(124)] = string.char( 74),   [string.char(125)] = string.char( 75),
    [string.char(126)] = string.char( 72),   [string.char(127)] = string.char( 73),
    [string.char(128)] = string.char(182),   [string.char(129)] = string.char(183),
    [string.char(130)] = string.char(180),   [string.char(131)] = string.char(181),
    [string.char(132)] = string.char(178),   [string.char(133)] = string.char(179),
    [string.char(134)] = string.char(176),   [string.char(135)] = string.char(177),
    [string.char(136)] = string.char(190),   [string.char(137)] = string.char(191),
    [string.char(138)] = string.char(188),   [string.char(139)] = string.char(189),
    [string.char(140)] = string.char(186),   [string.char(141)] = string.char(187),
    [string.char(142)] = string.char(184),   [string.char(143)] = string.char(185),
    [string.char(144)] = string.char(166),   [string.char(145)] = string.char(167),
    [string.char(146)] = string.char(164),   [string.char(147)] = string.char(165),
    [string.char(148)] = string.char(162),   [string.char(149)] = string.char(163),
    [string.char(150)] = string.char(160),   [string.char(151)] = string.char(161),
    [string.char(152)] = string.char(174),   [string.char(153)] = string.char(175),
    [string.char(154)] = string.char(172),   [string.char(155)] = string.char(173),
    [string.char(156)] = string.char(170),   [string.char(157)] = string.char(171),
    [string.char(158)] = string.char(168),   [string.char(159)] = string.char(169),
    [string.char(160)] = string.char(150),   [string.char(161)] = string.char(151),
    [string.char(162)] = string.char(148),   [string.char(163)] = string.char(149),
    [string.char(164)] = string.char(146),   [string.char(165)] = string.char(147),
    [string.char(166)] = string.char(144),   [string.char(167)] = string.char(145),
    [string.char(168)] = string.char(158),   [string.char(169)] = string.char(159),
    [string.char(170)] = string.char(156),   [string.char(171)] = string.char(157),
    [string.char(172)] = string.char(154),   [string.char(173)] = string.char(155),
    [string.char(174)] = string.char(152),   [string.char(175)] = string.char(153),
    [string.char(176)] = string.char(134),   [string.char(177)] = string.char(135),
    [string.char(178)] = string.char(132),   [string.char(179)] = string.char(133),
    [string.char(180)] = string.char(130),   [string.char(181)] = string.char(131),
    [string.char(182)] = string.char(128),   [string.char(183)] = string.char(129),
    [string.char(184)] = string.char(142),   [string.char(185)] = string.char(143),
    [string.char(186)] = string.char(140),   [string.char(187)] = string.char(141),
    [string.char(188)] = string.char(138),   [string.char(189)] = string.char(139),
    [string.char(190)] = string.char(136),   [string.char(191)] = string.char(137),
    [string.char(192)] = string.char(246),   [string.char(193)] = string.char(247),
    [string.char(194)] = string.char(244),   [string.char(195)] = string.char(245),
    [string.char(196)] = string.char(242),   [string.char(197)] = string.char(243),
    [string.char(198)] = string.char(240),   [string.char(199)] = string.char(241),
    [string.char(200)] = string.char(254),   [string.char(201)] = string.char(255),
    [string.char(202)] = string.char(252),   [string.char(203)] = string.char(253),
    [string.char(204)] = string.char(250),   [string.char(205)] = string.char(251),
    [string.char(206)] = string.char(248),   [string.char(207)] = string.char(249),
    [string.char(208)] = string.char(230),   [string.char(209)] = string.char(231),
    [string.char(210)] = string.char(228),   [string.char(211)] = string.char(229),
    [string.char(212)] = string.char(226),   [string.char(213)] = string.char(227),
    [string.char(214)] = string.char(224),   [string.char(215)] = string.char(225),
    [string.char(216)] = string.char(238),   [string.char(217)] = string.char(239),
    [string.char(218)] = string.char(236),   [string.char(219)] = string.char(237),
    [string.char(220)] = string.char(234),   [string.char(221)] = string.char(235),
    [string.char(222)] = string.char(232),   [string.char(223)] = string.char(233),
    [string.char(224)] = string.char(214),   [string.char(225)] = string.char(215),
    [string.char(226)] = string.char(212),   [string.char(227)] = string.char(213),
    [string.char(228)] = string.char(210),   [string.char(229)] = string.char(211),
    [string.char(230)] = string.char(208),   [string.char(231)] = string.char(209),
    [string.char(232)] = string.char(222),   [string.char(233)] = string.char(223),
    [string.char(234)] = string.char(220),   [string.char(235)] = string.char(221),
    [string.char(236)] = string.char(218),   [string.char(237)] = string.char(219),
    [string.char(238)] = string.char(216),   [string.char(239)] = string.char(217),
    [string.char(240)] = string.char(198),   [string.char(241)] = string.char(199),
    [string.char(242)] = string.char(196),   [string.char(243)] = string.char(197),
    [string.char(244)] = string.char(194),   [string.char(245)] = string.char(195),
    [string.char(246)] = string.char(192),   [string.char(247)] = string.char(193),
    [string.char(248)] = string.char(206),   [string.char(249)] = string.char(207),
    [string.char(250)] = string.char(204),   [string.char(251)] = string.char(205),
    [string.char(252)] = string.char(202),   [string.char(253)] = string.char(203),
    [string.char(254)] = string.char(200),   [string.char(255)] = string.char(201),
 }
 
 
 local blocksize = 64 -- 512 bits
 
 function hmac_sha1(key, text)
    assert(type(key)  == 'string', "key passed to hmac_sha1 should be a string")
    assert(type(text) == 'string', "text passed to hmac_sha1 should be a string")
 
    if #key > blocksize then
       key = sha1_binary(key)
    end
 
    local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
    local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)
 
    return sha1(key_xord_with_0x5c .. sha1_binary(key_xord_with_0x36 .. text))
 end
 
 function hmac_sha1_binary(key, text)
    return hex_to_binary(hmac_sha1(key, text))
 end
 
 return sha1(value)
 
end 
 
-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>	


eja.lib.shell='ejaShell'	
eja.help.shell='interactive lua shell'	


function ejaShell()	
 if eja.opt.shell == '' then
  print("Lua 5.2 Interactive Shell");
  while true do 	
   io.stderr:write("> ");	
   local ejaShellInput=io.read()	
   if ejaShellInput and ejaShellInput ~= ".quit" then	
    loadstring(ejaShellInput)()	
   else 	
    break	
   end	
  end	
 else	
  loadstring(eja.opt.shell)()	
 end	
end-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.help='ejaHelp'
eja.lib.update='ejaLibraryUpdate'
eja.lib.install='ejaLibraryUpdate'
eja.lib.remove="ejaLibraryRemove"
eja.lib.setup='ejaSetup'
eja.lib.init='ejaInit'
eja.help.update='update library {self}'
eja.help.install='install library'
eja.help.remove='remove library'
eja.help.setup='system setup'
eja.help.init='load init configuration {eja.init}'


function ejaHelp()      
 ejaPrintf('Copyright: 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>\nVersion:   %s\nUsage:     eja [script] [options]\n',eja.version)
 if eja.opt.help and eja.opt.help == '' then eja.opt.help=nil end
 if not eja.opt.help or eja.opt.help == 'full' then
  for k,v in next,ejaTableKeys(ejaTableSort(eja.help)) do
   ejaPrintf(' --%-16s %s',v:gsub("([%u])",function(x) return '-'..x:lower() end),eja.help[v])
  end
  ejaPrintf(' --%-16s this help','help')
 end
 if eja.helpFull then
  if not eja.opt.help then ejaPrintf(' --%-16s full help','help full') end
  for k,v in next,eja.helpFull do
   if #k > 0 and (not eja.opt.help or eja.opt.help == 'full') then ejaPrintf(' --%-16s %s help','help '..k,k) end
   for kk,vv in next,ejaTableKeys(ejaTableSort(eja.helpFull[k])) do
    if eja.opt.help == 'full' or eja.opt.help == k then
     ejaPrintf(' --%-16s %s',vv:gsub("([%u])",function(x) return '-'..x:lower() end),v[vv])
    end
   end
  end
 end
 print('')
end 


function ejaRun(opt)
 local a={}
 for k,v in next,opt do
  if eja.lib[k] and type(_G[eja.lib[k]]) == 'function' then 
   if tonumber(v) then
    a[v]=k;
   else
    a[#a+1]=k;
   end
  end 
 end
 for k,v in next,a do
  ejaTrace('[eja] running function %s with id %s',v,k);
  _G[eja.lib[v]]()
 end
end


function ejaLibraryUpdate(libName)
 local libName=libName or eja.opt.update or eja.opt.install or ''
 local libFile
 if libName:match('^https?%://') then 
  ejaTrace('[eja] library check on: %s',libName)
  libFile=ejaWebGet(libName)
  libName=libName:match('^.+/(.+)%.eja$')
 else
  ejaTrace('[eja] library check on: eja.it')     
  libFile=ejaWebGet('http://update.eja.it/?version=%s&lib=%s',eja.version,libName)
  if ejaString(libFile) == "" then    
   ejaTrace('[eja] library check on: github.com')  
   if ejaString(libName) ~= "" then gitName=libName else gitName="eja" end   
   libFile=ejaWebGet('https://raw.githubusercontent.com/eja/%s/master/%s.eja',gitName,gitName)
  end
 end
 if libName and libFile and #libFile>0 then 
  if not ejaFileStat(eja.pathLib) then ejaDirCreate(eja.pathLib) end
  if ejaFileWrite(eja.pathLib..libName..'.eja',libFile) then
   ejaInfo("[eja] library updated")
  else
   ejaError("[eja] library not updated")
  end
 else
  ejaWarn("[eja] library not found")
 end
end


function ejaLibraryRemove(libName)
 local libName=libName or eja.opt.remove or nil
 if libName and ejaFileRemove(eja.pathLib..libName..'.eja') then
  ejaInfo("[eja] library removed")
 else
  ejaWarn("[eja] library doesn't exist or cannot be removed")
 end
end


function ejaUpdate()
 ejaLibraryUpdate()
 ejaVmFileLoad(eja.pathLib..'.eja')
end


function ejaSetup()
 local webPath=eja.opt.webPath or eja.pathVar..'/web/'
 local webFile=webPath..'/index.eja'
 local webPort=eja.opt.webPort or 35248
 local webHost=eja.opt.webHost or '0.0.0.0'
 local etcFile=eja.pathEtc..'/eja.init'
 if not ejaFileStat(eja.pathBin) then ejaDirCreatePath(eja.pathBin) end
 if not ejaFileStat(eja.pathEtc) then ejaDirCreatePath(eja.pathEtc) end
 if not ejaFileStat(eja.pathLib) then ejaDirCreatePath(eja.pathLib) end  
 if not ejaFileStat(eja.pathVar) then ejaDirCreatePath(eja.pathVar) end  
 if not ejaFileStat(eja.pathTmp) then ejaDirCreatePath(eja.pathTmp) end  
 if not ejaFileStat(eja.pathLock) then ejaDirCreatePath(eja.pathLock) end
 if not ejaFileStat(webPath) then ejaDirCreatePath(webPath) end  
 if not ejaFileStat(etcFile) then
  ejaFileWrite(etcFile,ejaSprintf('eja.opt.web=1;\neja.opt.webPort=%s;\neja.opt.webHost="%s";\neja.opt.webPath="%s";\neja.opt.logFile="%s/eja.log";\neja.opt.logLevel=3;\n',webPort,webHost,webPath,eja.pathTmp))
  ejaInfo('[eja] init script installed')
 end
 if not ejaFileStat(webFile) then
  ejaFileWrite(webFile,'web=...;\nweb.data="<html><body><h1>eja! :)</h1></body></html>";\nreturn web;\n')
  ejaInfo('[eja] web demo installed')
 end
 if not ejaFileStat('/etc/systemd/system/eja.service') then
  ejaFileWrite('/etc/systemd/system/eja.service',string.format([[[Unit]
Description=eja init
After=network.target

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStart=%s/eja --init

[Install]
WantedBy=multi-user.target
]],eja.pathBin))

  ejaExecute('ln -s /etc/systemd/system/eja.service /etc/systemd/system/multi-user.target.wants/eja.service')
  ejaInfo('[eja] systemd installed')
 end
end


function ejaExecute(v,...)
 os.execute(string.format(v,...))
end


function ejaInit(file)
 local file=file or eja.opt.init or ''
 if ejaFileCheck(eja.pathEtc) then
  if file ~= '' then file='.'..file end
  if ejaFileCheck(eja.pathEtc..'/eja.init'..file) then
   ejaVmFileLoad(eja.pathEtc..'/eja.init'..file)
   eja.opt.init=nil
   ejaRun(eja.opt)
  else
   ejaError('[eja] init file not found')
  end
 end
end


function ejaModuleCheck(name)
 for _,x in next,(package.searchers or package.loaders) do 
  local check=x(name)
  if type(check) == "function" then return true end
 end

 return false
end


function ejaModuleLoad(name)
 if ejaModuleCheck(name) then
  return require(name)
 else
  return false
 end
end


-- Copyright (C) 2007-2019 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaTable(t)
 if t and type(t) == "table" then 
  return t
 else
  return {}
 end
end


function ejaTableGet(array, index)
 local b=getmetatable(array)
 if index and index>0 then index=index-1 else index=0 end
 if index < 1 then index=nil end
 local _,key=next(b,index)
 return key,array[key]
end


function ejaTablePut(array, key, value, index)
 if not array then array={} end
 local b=getmetatable(array) or {}
 if key then
  if not array[key] then 
   if tonumber(index) then
    b[tonumber(index)]=key
   else 
    b[#b+1]=key 
   end
  end
  array[key]=value
 end
 setmetatable(array,b)
 return array
end


function ejaTableCount(array)
 local i=0
 for k,v in next,ejaTable(array) do i=i+1 end
 return i
end


function ejaTableMerge(old, new)
 if old and new and #new > 1 then
  for i=1,ejaTableLen(old) do
   k,v=ejaTableGet(old,i)
   ejaTablePut(old,k,new[i])
  end
  return true
 else
  return false
 end
end


function ejaTableSort(t)
 a={}
 for k,v in next,t do
  table.insert(a,k)
 end
 table.sort(a)
 setmetatable(t,a)
 return t
end


function ejaTableValues(t)
 local a={}
 for k,v in next,getmetatable(t) do
  a[#a+1]=t[v]
 end
 return a
end


function ejaTableKeys(t)
 local a={}
 for k,v in next,getmetatable(t) do
  a[#a+1]=v
 end
 return a
end

function ejaTableUnpack(a)
 return table.unpack(a)
end


function ejaTablePack(...)
 local a=table.pack(...)
 a['n']=nil
 return a
end
-- Copyright (C) 2007-2016 by Ubaldo Porcheddu <ubaldo@eja.it>


function ejaUntar(fileIn, dirOut)
 local i=-1
 local size=512
 local path=""
 local fd=io.open(fileIn, "r")
 if fd then 
  i=0
  if dirOut then 
   path=dirOut..'/' 
   if not ejaDirList(path) then
    if not ejaDirCreatePath(path) then 
     i=-2
    end
   end
  end
  while i >= 0 do
   local block=fd:read(size)
   if not block then 
    break
   else
    local h={}
    h.name=path..block:sub(1,100):match('^[^%z]*')
    h.mode=block:sub(101,108):match('^[^%z]*')
    h.type=ejaNumber(block:sub(157,157))
    h.size=ejaOct2Dec(block:sub(125,136):match('^[^%z]*'))
    h.time=ejaOct2Dec(block:sub(137,148):match('^[^%z]*'))	--?
    h.link=block:sub(158,257):match('^[^%z]*')
    if h.name ~= path then
     ejaTrace('[untar] %s %11s %s %s %s %s %s', fileIn, h.size, h.time, h.mode, h.type, h.name, h.link)
    end
    if h.type == 5 then		--dir
     ejaDirCreatePath(h.name)
     ejaExecute('chmod %s %s',h.mode,h.name)
    elseif h.type == 2 then	--symlink
     ejaExecute('ln -s %s %s', h.link, h.name)
    elseif h.size > 0 then	--anything else
     local data=fd:read(math.ceil(h.size/size)*size)
     if data and #data > 0 then 
      data=data:sub(1,h.size)
      ejaFileWrite(h.name,data)
      ejaExecute('chmod %s %s',h.mode,h.name)
     end
    end
    i=i+1
   end
  end
  fd:close()
 end

 return i
end

eja.version='14.0622'
-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.export='ejaVmFileExport'
eja.lib.exportLua='ejaVmExportLua'
eja.help.export='input text eja/lua file to export into eja bytecode'
eja.help.exportName='exported file name'
eja.help.exportLua='export plain text eja file to lua'


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
  o[#o+1]=ejaVmInstr2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.Instr-1)));	p=p+h.Instr;		--instruction
 end

 if debug then o[#o+1]='\nconst\n' end	
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(z);							p=p+h.int;	--length of constant
 for n=1,z do
  local cType=d:byte(p);
  o[#o+1]=ejaVmByte2Hex(cType);						p=p+1;			--const type
  if cType == 4 then
   local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   o[#o+1]=ejaVmSize2Hex(l);						p=p+h.size;		--string length
   if l > 0 then
    o[#o+1]=ejaVmString2Hex(d:sub(p,p+l-1));				p=p+l;			--string
   end
  end
  if cType == 3 then
   o[#o+1]=ejaVmNum2Hex(ejaVmByte2Int(h.endian,d:sub(p,p+h.num-1)));	p=p+h.num;		--number
  end
  if cType == 1 then
   o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;			--boolean
  end
  if cType == 0 then end									--nil
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
  o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;			--stack
  o[#o+1]=ejaVmByte2Hex(d:byte(p));					p=p+1;			--idx
 end

 if debug then o[#o+1]='\nsource\n' end	
 l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
 o[#o+1]=ejaVmSize2Hex(0);							p=p+h.size;	--string length
 if l > 0 then
  p=p+l;											--string
 end
 
 if debug then o[#o+1]='\nline info\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of line
 for n=1,z do
  p=p+h.int;											--begin
 end

  
 if debug then o[#o+1]='\nlocals\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of local vars
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
   p=p+h.size;											--string length
  if l > 0 then
   p=p+l;											--string
  end
  p=p+h.int;											--begin
  p=p+h.int;											--end
 end

 if debug then o[#o+1]='\nupvalues\n' end
 z=ejaVmByte2Int(h.endian,d:sub(p,p+h.int-1));
 o[#o+1]=ejaVmInt2Hex(0);							p=p+h.int;	--length of upvalues
 for n=1,z do
  local l=ejaVmByte2Int(h.endian,d:sub(p,p+h.size-1));
  p=p+h.size;											--string length
  p=p+l;											--string
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
 local out=nil
 if data:sub(0,5) == 'ejaVM' then
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
  if data:sub(0,9) == "--[[lua]]" then
   return data
  else
   return ejaVmToLua(data)
  end
 end
end


function ejaVmExportLua(inputFile,outputName)
 local outputName=outputName or eja.opt.exportName or nil
 local inputFile=inputFile or eja.opt.exportLua
 local data=ejaFileRead(inputFile)
 if data then
  if outputName then
   ejaFileWrite(outputName..".lua",ejaVmToLua(data))
  else
   print(ejaVmToLua(data))
  end
 else
  ejaError('[eja] vm, input file not found.')
 end
end


function ejaVmFileExport(inputFile,outputName)
 local outputName=outputName or eja.opt.exportName or eja.opt.export or nil
 local inputFile=inputFile or eja.opt.export
 if outputName then
  local data=ejaFileRead(inputFile) 
  if data then
   if outputName:match('%.lua$') then 
    outputName=outputName:sub(1,-5) 
    data=ejaVmExport(string.dump(load(data)))			--lua
   elseif not data:sub(0,5) == 'ejaVM' then			--eja (no bytecode)
    data=ejaVmExport(string.dump(load(ejaVmToLua(data))))
   else
    ejaWarn('[eja] vm, input file not supported or already in eja bytecode.')
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
  if not fileName:match('%.eja$') or dataIn:sub(0,9) == "--[[lua]]" then
   ff,ee=load(dataIn)
   if not ff then
    ejaError('[eja] vm, lua syntax error: %s',ee)
   end
  else
   if dataIn:sub(0,5) == 'ejaVM' then
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
 local repeatArray={}; repeatArray[0]=0; repeatCount=0; 
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
     if v.data:match("};$") or v.data:match("%){$") or v.data:match(";}$") then
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
  v.src=line;
  
  --check without whitespace
  if (v.type == "keyword" and v.data=="else" and aIn[k+1] and aIn[k+1].type == "keyword" and aIn[k+1].data == "if") then
   line=""
   aIn[k+1].data="elseif";
  end
  
  if (v.type == "operator" and aIn[k-1] and aIn[k-1].type == "ident") then
   if v.data == "+=" then 	line="="..aIn[k-1].data.."+"; 	end 
   if v.data == "-=" then 	line="="..aIn[k-1].data.."-"; 	end 
   if v.data == "*=" then 	line="="..aIn[k-1].data.."*"; 	end 
   if v.data == "/=" then 	line="="..aIn[k-1].data.."/"; 	end 
  end
  
  
  --function
  if (functionArray[functionCount] >= 2 and v.type == "symbol" and v.data == "}") then
   functionArray[functionCount]=functionArray[functionCount]-1;
   if functionArray[functionCount] == 1 then 
    functionArray[functionCount]=0
    functionCount=functionCount-1
    line=" end ";
   end
  end
  if (functionArray[functionCount] >= 1 and v.type == "symbol" and v.data == "{") then 
   functionArray[functionCount] = functionArray[functionCount] + 1;
   if (functionArray[functionCount] == 2) then 
    line="";
   end
  end
  if (v.type == "keyword" and v.data == "function") then
   functionCount=functionCount+1;
   functionArray[functionCount]=1;
  end

  --repeat
  if (repeatArray[repeatCount] >= 2 and v.type == "symbol" and v.data == "}") then
   repeatArray[repeatCount]=repeatArray[repeatCount]-1;
   if repeatArray[repeatCount] == 1 then 
    repeatArray[repeatCount]=0
    repeatCount=repeatCount-1
    line="";
   end
  end
  if (repeatArray[repeatCount] >= 1 and v.type == "symbol" and v.data == "{") then 
   repeatArray[repeatCount] = repeatArray[repeatCount] + 1;
   if (repeatArray[repeatCount] == 2) then 
    line="";
   end
  end
  if (v.type == "keyword" and v.data == "repeat") then
   repeatCount=repeatCount+1;
   repeatArray[repeatCount]=1;
  end

  --while
  if (whileArray[whileCount] >= 2 and v.type == "symbol" and v.data == "}") then
   whileArray[whileCount]=whileArray[whileCount]-1;
   if whileArray[whileCount] == 1 then 
    whileArray[whileCount]=0
    whileCount=whileCount-1
    line=" end ";
   end
  end
  if (whileArray[whileCount] >= 1 and v.type == "symbol" and v.data == "{") then 
   whileArray[whileCount] = whileArray[whileCount] + 1;
   if (whileArray[whileCount] == 2) then 
    line=" do ";
   end
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
    if aIn[k+1] and (aIn[k+1].data == "else" or aIn[k+1].data == "elseif") then
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
   ejaTrace('[eja] lexer syntax check: %010d %010d % 10s\t%s\t%s',ejaNumber(v.row),k,v.type,v.src,line)
  end
 end
 local out=table.concat(aOut);
 ejaDebug('[eja] lexer dump:\n%s',out);
 return out;
end

-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.lib.web='ejaWeb'
eja.lib.webStart='ejaWebStart'
eja.lib.webStop='ejaWebStop'
eja.help.webStart='web server start'
eja.help.webStop='web server stop'
eja.help.webPort='web server port {35248}'
eja.help.webHost='web server ip {0.0.0.0}'
eja.help.webPath='web server path'
eja.help.webSize='web buffer size {8192}'
eja.help.webList='directory list mode [y/n] {n}'
eja.help.web='web server start in foreground {current path, directory list}'


function ejaWeb()
 eja.web={}
 eja.web.count=0
 eja.web.timeout=100
 eja.web.list=eja.opt.webList or nil
 eja.web.host=eja.opt.webHost or '0.0.0.0'
 eja.web.port=eja.opt.webPort or 35248
 eja.web.path=eja.opt.webPath or eja.pathVar..'/web/'

 if ejaString(eja.opt.webList) ~= "y" then 
  eja.web.list=false; 
 else 
  eja.web.list=true;
 end

 if eja.opt.web then
  if not eja.opt.webPath then eja.web.path="./"; end
  if ejaString(eja.opt.webList) ~= "n" then eja.web.list=true; end
 end

 ejaInfo("[web] daemon on port %d and path %s",eja.web.port, eja.web.path);
 ejaDebug("[web] host: %s, directory list: %s", eja.web.host, eja.web.list);

 local client=nil  
 local s=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
 ejaSocketOptionSet(s,SOL_SOCKET,SO_REUSEADDR,1) 
 ejaSocketBind(s,{ family=AF_INET, addr=eja.web.host, port=eja.web.port },0)
 ejaSocketListen(s,5) 
 while s do
  client,t=ejaSocketAccept(s)
  if client then
   eja.web.count=eja.web.count+1
   local forkPid=ejaFork()
   if forkPid and forkPid == 0 then 
    ejaSocketClose(s)
    while client do
     ejaSocketOptionSet(client,SOL_SOCKET,SO_RCVTIMEO,eja.web.timeout,0)
     if ejaWebThread(client,t.addr,t.port) < 1 then 
      break 
     end
    end
    ejaSocketClose(client)
    break
   else
    ejaSocketClose(client)
    ejaForkClean()
   end
  end
 end

end


function ejaWebStart(...)
 ejaWebStop()
 eja.pid.web=ejaFork()
 if eja.pid.web and eja.pid.web == 0 then
  ejaWeb(...)
 else
  ejaPidWrite(ejaSprintf('web_%d',eja.opt.webPort or 35248),eja.pid.web)
 end
end


function ejaWebStop()
 ejaPidKill(ejaSprintf('web_%d',tonumber(eja.opt.webStop) or eja.opt.webPort or 35248))
end


function ejaWebThread(client,ip,port)
 local web={}
 web.bufferSize=8192
 web.timeStart=os.time()
 web.socket=client
 web.remoteIp=ip or 'null'
 web.remotePort=tonumber(port) or 0
 web.method=''
 web.request=''
 web.postFile=''
 web.response=''
 web.auth=0
 web.data=''
 web.file=''
 web.query=''
 web.opt={}
 web.status='200 OK' 
 web.range=-1
 web.protocolOut='HTTP/1.1'
 web.headerIn={}
 web.headerOut={}
 web.headerOut['Content-Type']='text/html'
 web.headerOut['Connection']='Close'
 web.headerSent=false

 if ejaNumber(eja.opt.webSize) > 0 then web.bufferSize=ejaNumber(eja.opt.webSize) end
 
 local body=''
 local data=ejaSocketRead(client,web.bufferSize)
 if data then
  body=data:match('\r\n\r\n(.+)') or data:match('\n\n(.+)') or ''
  web.request=data:match('(.-)\r\n\r\n') or data:match('(.-)\n\n') or data
 end
 if web.request and web.request ~= '' then
  web.request=web.request:gsub('\r','')
  web.method,web.uri,web.protocolIn=web.request:match('(%w+) (.-) (.+)[\n]?')
  if web.uri then web.uri=web.uri:gsub('/+','/') end
  if web.method then
   web.method=web.method:lower()
   if web.request:match('\n.+') then
    for k,v in web.request:match('\n(.+)'):gmatch('(.-)%: ([^\n]+)') do
     local key=k:lower():gsub('\n','')
     local value=v:gsub('\n','')
     web.headerIn[key]=value
    end
   end
  end
 end
 if web.headerIn['connection'] and web.headerIn['connection']:lower() == 'keep-alive' then 
  if web.headerIn['user-agent'] and not web.headerIn['user-agent']:find('%(iP') then	--avoid iOS Keep-Alive bug
   web.headerOut['Connection']='Keep-Alive'
  end
 end
 
 if web.headerIn['range'] then 
  web.range=tonumber( web.headerIn['range']:match("=([0-9]+)") )
 end
 
 if web.uri then 
  web.path=web.uri:gsub("\\.\\.",""):match('([^?|#]+)')
  web.query=web.uri:match('%?([^#]+)') 
 end

 if web.method == 'post' and ejaNumber(web.headerIn['content-length']) > 0 then
  if web.headerIn['content-type']:match('application/x%-www%-form%-urlencoded') then 
   if ejaNumber(web.headerIn['content-length']) < web.bufferSize then
    while ejaNumber(web.headerIn['content-length']) > #body do
     local data=ejaSocketRead(client,web.bufferSize)
     if data then 
      body=body..data
     else
      break
     end     
    end
    web.query=body
   else
    web.status='413 Request Entity Too Large'
   end
  else
   web.postFile=eja.pathTmp..'eja.postFile-'..web.remoteIp:gsub('.','')..web.remotePort
   local fileLength=tonumber(web.headerIn['content-length'])
   local fd=io.open(web.postFile,'w')
   if body ~= '' then 
    fd:write(body) 
    fileLength=fileLength-#body
   end
   while fileLength > 0 do
    local data=ejaSocketRead(client,web.bufferSize)
    if data then
     fd:write(data)
     fileLength=fileLength-#data
    else
     break 
    end   
   end
   fd:close()
  end
 end
 
 --web query options
 if web.query and web.query ~= '' then
  web.query=web.query:gsub("&amp;", "&")
  web.query=web.query:gsub("&lt;", "<")
  web.query=web.query:gsub("&gt;", ">")
  web.query=web.query:gsub("+", " ")
  for k,v in web.query:gmatch('([^&=]+)=([^&=]*)&?') do
   web.opt[k]=ejaUrlDecode(v)
  end
 end
 
 --web path
 if web.path and web.path ~= '' then
  web=ejaWebAuth(web)
  if web.auth < 0 then
   web.status='401 Unauthorized'
  else
   if web.path:sub(-1) == "/" then 
    if ejaFileCheck(eja.web.path..web.path..'index.eja') then
     web.path = web.path.."index.eja" 
    elseif ejaFileCheck(eja.web.path..web.path..'index.lua') then
     web.path = web.path.."index.lua"
    else
     web.path = web.path.."index.html" 
    end
   end
   local ext=web.path:match("([^.]+)$")
   web.headerOut['Content-Type']=eja.mime[ext]
   if ext == "eja" then web.headerOut['Content-Type']="application/eja" end
   if ext == "lua" then web.headerOut['Content-Type']="application/lua" end
   if not web.headerOut['Content-Type'] then web.headerOut['Content-Type']="application/octet-stream" end
   if web.headerOut['Content-Type']=="application/eja" or web.headerOut['Content-Type']=="application/lua" then
    local run=nil
    local file=ejaSprintf("%s%s",eja.web.path,web.path:sub(2))
    if ejaFileCheck(file) then
     local data=ejaFileRead(file)
     if data then
      if web.headerOut['Content-Type']=="application/lua" then
       load(data)(web)
      else
       load(ejaVmImport(data))(web)
      end
     end
     web.headerOut['Content-Type']="text/html"
    else
     web.status='500 Internal Server Error'
    end
   elseif eja.mimeApp[web.headerOut['Content-Type']] then
    web=_G[eja.mimeApp[web.headerOut['Content-Type']]](web)
   else
    if eja.opt.webCns then web=ejaWebCns(web) end
    if not web.cns then
     web.file=ejaSprintf('%s/%s',eja.web.path,web.path)
     local stat=ejaFileStat(web.file)
     if stat then
      if ejaSprintf('%o',stat.mode):sub(-5,1)=='4' then 
       web.file=ejaSprintf('%s/%s/index.html',eja.web.path,web.path)
       if not ejaFileStat(web.file) then 
        web.file=nil
       else
        web.headerOut['Content-Type']="text/html"
       end
      end
     end
     if not stat or not web.file then
      if eja.web.list and (stat or web.file:match('index.html$')) then
	web.data=ejaWebList(eja.web.path, web.path);       
      else
       web.status='404 Not Found'
      end
      web.file=''  
     else
      web.headerOut['Cache-Control']='max-age=3600'
     end
    end
   end
      
  end
 else
  web.status='501 Not Implemented'  
  if os.time()-web.timeStart >= eja.web.timeout then
   web.status='408 Request Timeout'  
  end
 end

 --4XX
 if web.status:sub(1,1) == '4' then
  local status=web.status:sub(1,3)
  local file4xxPath=ejaSprintf('%s/%s',eja.web.path,status)
  if ejaFileStat(file4xxPath..'.eja') then
   load(ejaVmImport(ejaFileRead(file4xxPath..'.eja')))(web)
  elseif ejaFileStat(file4xxPath..'.lua') then
   loadfile(file4xxPath..'.lua')(web)
  elseif ejaFileCheck(ejaSprintf('%s/%s.html',eja.web.path,status)) then 
   web.status='301 Moved Permanently'
   web.headerOut['Location']=ejaSprintf('/%s.html',status)
  end
 end
 
 if web.file ~= '' then 
  web.headerOut['Content-Length'] = ejaFileSize(web.file)
  if web.headerOut['Content-Length'] < 1 then web.file='' end
 end
  
 if web.file == '' and web.data and #web.data then 
  web.headerOut['Content-Length'] = #web.data 
 end
 
 if web.range > 0 then
  web.headerOut['Content-Range']=ejaSprintf("bytes %d-%d/%d",web.range,web.headerOut['Content-Length']-1,web.headerOut['Content-Length'])
  web.headerOut['Content-Length']=web.headerOut['Content-Length']-web.range
  web.status='206 Partial Content'
 end
 
 if not web.headerOut['Content-Length'] or web.headerOut['Content-Length'] < 1 then
  web.headerOut['Content-Length']=nil
  web.headerOut['Content-Type']=nil
 end
 
 if web.status:sub(1,1) ~= '2' then web.headerOut['Connection']='Close' end
 
 if not web.headerSent then
  ejaSocketWrite(client,ejaWebHeader(web.headerOut,web.status,web.protocolOut))
 end

 if ejaString(web.file) ~= '' then
  local fd=io.open(web.file,'r')
  if fd then
   if web.range > 0 then 
    fd:seek('set',web.range) 
   end
   local data=''
   while data do
    data=fd:read(web.bufferSize)
    if data then 
     ejaSocketWrite(client,data)
    else
     break
    end
   end
   fd:close()
  end
 elseif ejaString(web.data) ~= '' then
  ejaSocketWrite(client,web.data)  
 end

 ejaDebug('[web] %s\t%s\t%s\t%s\t%s\t%s',web.remoteIp,web.status:match("[^ ]+"),os.time()-web.timeStart,web.headerOut['Content-Length'],web.auth,web.uri)
 ejaTrace('\n<--\n%s\n-->\n%s\n',web.request,web.response)
 
 if web.headerOut['Connection']=='Keep-Alive' then 
  return 1
 else 
  return 0
 end
end


function ejaWebOpen(host,port,timeout)
 timeout=timeout or 5
 if ejaNumber(port) < 1 then port=80 end
 local res,err=ejaSocketGetAddrInfo(host, port, {family=AF_INET, socktype=SOCK_STREAM})    
 if res then
  local fd=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
  if fd and ejaSocketConnect(fd,res[1]) then
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_RCVTIMEO,timeout,0)
   ejaSocketOptionSet(fd,SOL_SOCKET,SO_SNDTIMEO,timeout,0)
   return fd
  end
 end
 return nil;
end


function ejaWebWrite(fd,value)
 return ejaSocketWrite(fd,value)
end


function ejaWebRead(fd,size)
 return ejaSocketRead(fd,size)
end


function ejaWebClose(fd)
 return ejaSocketClose(fd)
end


function ejaWebGetOpen(value,...)
 url=string.format(value,...)
 local protocol,host,port,path=url:match('(.-)://([^/:]+):?([^/]*)/?(.*)')
 if ejaNumber(port) < 1 then port=80 end
 local fd=ejaWebOpen(host,port)
 if fd then
  ejaWebWrite(fd,ejaSprintf('GET /%s HTTP/1.0\r\nHost: %s\r\nUser-Agent: eja %s\r\nAccept: */*\r\nConnection: Close\r\n\r\n',path,host,eja.version))
  return fd
 else
  return nil
 end 
end


function ejaWebGet(value,...)
 local url=string.format(value,...)
 local data=nil
 local header=nil
 if url:match('^https') then
  local file=ejaFileTmp()
  ejaExecute([[curl -s "%s" > %s]],url,file);
  data=ejaFileRead(file);
  if data then
   header="console: curl"
  else
   ejaExecute([[wget -qO %s "%s"]],file,url);
   data=ejaFileRead(file);
   if data then
    header="console: wget"
   end
  end
  if data then 
   ejaFileRemove(file)
  end
 else 
  local t={}
  local fd=ejaWebGetOpen(url)
  if fd then
   while true do
    local buf=ejaWebRead(fd,1024)
    if not buf or #buf == 0 then break end
    t[#t+1]=buf
   end
   ejaWebClose(fd)
   header,data=table.concat(t):match('(.-)\r?\n\r?\n(.*)')
  end
 end
 return data,header
end


function ejaWebHeader(header,status,protocol)
 local protocol=protocol or 'HTTP/1.1'
 local status=status or '200 OK'
 local header=header or {}
 local out=ejaSprintf('%s %s\r\nDate: %s\r\nServer: eja %s\r\n',protocol,status,os.date(),eja.version)
 header['Content-Type']= header['Content-Type'] or 'text/html'
 header['Connection']=header['Connection'] or 'Close'
 for k,v in next,header do
  out=out..k..': '..v..'\r\n'
 end
 return out..'\r\n'
end


function ejaWebSocketProxy(lHost, lPort, rHost, rPort, inMode, outMode, lTimeout, rTimeout)
 local bSize=8192 
 local lTimeout=lTimeout or 5
 local rTimeout=rTimeout or 100
 local inMode=inMode or '' or 'b64' or 'hex'
 local outMode=outMode or '' or 'b64' or 'hex'
 local lSocket=nil
 local rSocket=nil
 if lHost and lPort and rHost and rPort then
  local res,err=ejaSocketGetAddrInfo(rHost, rPort, {family=AF_INET, socktype=SOCK_STREAM})    
  if res then
   local rSocket=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
   if rSocket and ejaSocketConnect(rSocket,res[1]) then
    ejaSocketOptionSet(rSocket,SOL_SOCKET,SO_RCVTIMEO,lTimeout,0)
    ejaSocketOptionSet(rSocket,SOL_SOCKET,SO_SNDTIMEO,lTimeout,0)
    local s=ejaSocketOpen(AF_INET,SOCK_STREAM,0)
    ejaSocketOptionSet(s,SOL_SOCKET,SO_REUSEADDR,1) 
    ejaSocketBind(s,{ family=AF_INET, addr=lHost, port=lPort },0)
    ejaSocketListen(s,lTimeout) 
    if s then
     while true do
      lSocket,t=ejaSocketAccept(s)
      if lSocket then
       ejaSocketOptionSet(lSocket,SOL_SOCKET,SO_RCVTIMEO,lTimeout,0)
       ejaSocketOptionSet(lSocket,SOL_SOCKET,SO_SNDTIMEO,lTimeout,0)
       local dataIn=ejaSocketRead(lSocket,bSize)
       if dataIn then 
        local query=dataIn:match("^GET /%?([^ ]+) ") 
        if query then
         if inMode=='b64' then 
          local tmp=ejaBase64Decode(query); query=tmp;
         end
         if inMode=='hex' then
          local tmp,_=query:gsub("..",function(x)return string.char(tonumber(x,16)) end); query=tmp; 
         end
         ejaSocketWrite(rSocket,query) 
        end
       end
       local dataOut=ejaSocketRead(rSocket,bSize) or ""
       if outMode=='b64' then local tmp=ejaBase64Encode(dataOut); dataOut=tmp; end
       if outMode=='hex' then local tmp=dataOut:gsub(".",function(x)return string.format("%02X",string.byte(x)) end); dataOut=tmp; end
       ejaSocketWrite(lSocket,'HTTP/1.0 200 OK\r\nDate: '..os.date()..'\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: '..#dataOut..'\r\nConnection: close\r\n\r\n'..dataOut) 
      end
      ejaSocketClose(lSocket)
     end
    end
    ejaSocketClose(rSocket)
   end
  end
 end
end


function ejaWebList(pathLocal, pathWeb)
 local a={}
 local path=pathLocal..ejaString(pathWeb):gsub("index.html$","")..("/"):gsub("//","");
 
 a[#a+1]='<html><body><ul>\n';
 for k,v in next,ejaDirTableSort(path) do
  local file=(path.."/"..v):gsub("//","/"):gsub("//","/"):gsub("//","/"); 
  if ejaDirCheck(file) then v=v..'/'; end
  a[#a+1]=ejaSprintf('<li><a href="%s">%s</a></li>\n',v,v);
 end
 a[#a+1]='</ul></body></html>';

 return table.concat(a);
end
-- Copyright (C) 2007-2021 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.help.webAuth="web hash check {1}";	-- 0 no auth check, 1 auth check enabled, 2 allow remote ip to be passed by proxy as X-Real-IP


function ejaWebAuthHashCheck(key, path, ip, hash)
 local auth=-1;
 local path=path or "";
 local hash=hash or "";
 local key=key or "";
 local ip=ip or "";
 for i=10,5,-1 do
  timeN=ejaString(os.time()):sub(0, i);
  timeA=ejaNumber(timeN)-1;
  timeZ=ejaNumber(timeN)+1;
  if ejaSha256(key..ip..timeN..path) == hash or ejaSha256(key..ip..timeA..path) == hash or ejaSha256(key..ip..timeZ..path) == hash then
   auth=i-4;
   break;
  end
 end
 if auth < 1 and ejaSha256(key..ip..path) == hash then
  auth=1;
 end
 return auth;
end


function ejaWebAuthHashCreate(key, path, ip, power)
 local path=path or "";
 local key=key or "";
 local ip=ip or "";
 return ejaSha256(key..ip..ejaString(os.time()):sub(1, ejaNumber(power))..path);
end


function ejaWebAuth(web)
 local level=tonumber(eja.opt.webAuth) or 1;
 if level > 0 then
  local auth,path=web.path:match('^/('..string.rep('%x',64)..')(/.*)$');
  if auth and path then
   web.auth=-1;
   web.path=path;
   local powerMax=5;
   local authData=ejaFileRead(eja.pathEtc..'eja.web');
   local ip=web.remoteIp;
   local ipProxy=ejaString(web.headerIn["x-real-ip"]);
   if authData then
    for k,v in authData:gmatch('([%x]+) ?([0-9]*)\n?') do
     if ejaNumber(v) > powerMax then powerMax=v; end
     local value=ejaWebAuthHashCheck(k, path, ip, auth);
     if value < 1 and level >= 2 and ipProxy ~= "" then     
      value=ejaWebAuthHashCheck(k, path, ipProxy, auth);
     end
     if value > 0 then
      web.auth=value*v;
      web.authKey=k;
      break;
     end
    end
   end
  end
 end
 return web
end

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

-- Copyright (C) 2007-2017 by Ubaldo Porcheddu <ubaldo@eja.it>


eja.mime.taz='application/taz'
eja.mimeApp[eja.mime.taz]='ejaWebTaz'
eja.help.webTaz='taz max size {65535}'


function ejaWebTazList(size)
 local a={}
 for k,v in next,ejaDirTable(eja.pathTmp) do
  if v:match('^eja.taz.') then 
   local stat=ejaFileStat(eja.pathTmp..'/'..v)
   a[#a+1]={ ["name"]=v:sub(9), ["size"]=stat.size, ["time"]=stat.mtime }
  end
 end
 table.sort(a,function(l,r) return l.time>r.time end)
 for k,v in next,a do
  size=size-v.size
  if size < 0 then
   a[k]=nil
   ejaFileRemove(eja.pathTmp..'/eja.taz.'..v.name)
  end  
 end 
 return a
end


function ejaWebTaz(web)
 web.data=''
 web.headerOut['Content-Type']='application/json'
 if eja.opt.webTaz then
  local size=tonumber(eja.opt.webTaz) or 65535
  local file=web.path:match("^/(.-).taz$")
  local aData={ ["time"]=os.time(), ["size"]=size, ["ip"]=web.remoteIp, ["data"]=ejaWebTazList(size) }  
  if file=="" or file=='index' then
   web.data=ejaJsonEncode(aData)
  else
   if ejaString(web.query) ~= "" or ejaString(web.postFile) ~= "" then
    local fileName=ejaSha256(file)
    local filePath=eja.pathTmp..'/eja.taz.'..fileName
    local fileLength=#web.query
    if ejaString(web.postFile) ~= "" then
     local stat=ejaFileStat(web.postFile)
     if stat and ejaNumber(stat.size) > size then
      web.status='413 Request Entity Too Large'
     else
      ejaFileMove(web.postFile,filePath)
     end
    else
     ejaFileWrite(filePath,web.query)         
    end    
    local stat=ejaFileStat(filePath)
    if stat then
     web.data=ejaJsonEncode({["name"]=fileName, ["time"]=stat.mtime, ["size"]=stat.size })
    else
     web.status='500 Internal Server Error'
    end
   else
    local file256=ejaSha256(file)
    for k,v in next,aData.data do
     if v.name == file256 then
      web.file=eja.pathTmp..'/eja.taz.'..v.name
     end
    end
    if ejaString(web.file) == "" then
     web.status='404 Not Found'
    end
   end
  end
 else
  web.status='501 Not Implemented'
 end
 return web
end
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
 
-- Copyright (C) 2007-2020 by Ubaldo Porcheddu <ubaldo@eja.it>


if not eja then

 eja={}
 eja.opt={}
 eja.lib={} 
 eja.pid={}
 eja.help={}
 eja.mime={} 
 eja.mimeApp={}
end


function ejaLoad()

 if not eja.load then 
  eja.load=1
 else
  eja.load=eja.load+1
 end

 if eja.path or eja.load ~= 3 then return end

 if not _G['ejaPid'] then
  if ejaModuleCheck("posix") then
   ejaRock()
  else
   print("Please use eja or install luaposix.")
   os.exit()
  end
 end

 eja.path=_eja_path or '/'
 eja.pathBin=_eja_path_bin or eja.path..'/usr/bin/'
 eja.pathEtc=_eja_path_etc or eja.path..'/etc/eja/'
 eja.pathLib=_eja_path_lib or eja.path..'/usr/lib/eja/'
 eja.pathVar=_eja_path_var or eja.path..'/var/eja/'
 eja.pathTmp=_eja_path_tmp or eja.path..'/tmp/'
 eja.pathLock=_eja_path_lock or eja.path..'/var/lock/'
 
 package.cpath=eja.pathLib..'?.so;'..package.cpath
 
 t=ejaDirList(eja.pathLib)
 if t then 
  local help=eja.help
  eja.helpFull={}
  table.sort(t)
  for k,v in next,t do
   if v:match('.eja$') then
    eja.help={}
    ejaVmFileLoad(eja.pathLib..v)
    eja.helpFull[v:sub(0,-5)]=eja.help
   end
  end
  eja.help=help
 end

 if #arg > 0 then
  for i in next,arg do
   if arg[i]:match('^%-%-') then
    local k=arg[i]:sub(3):gsub("-(.)",function(x) return x:upper() end)
    if not arg[i+1] or arg[i+1]:match('^%-%-') then 
     eja.opt[k]=''
    else
     eja.opt[k]=arg[i+1]   
    end
   end
  end
  if arg[1]:match('^[^%-%-]') then
   if ejaFileStat(arg[1]) then
    ejaVmFileLoad(arg[1])
   else
    ejaVmFileLoad(eja.pathBin..arg[1])
   end
  end
  ejaRun(eja.opt)
 else
  ejaHelp() 
 end
 
end


ejaLoad();

