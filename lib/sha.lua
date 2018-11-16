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
 
