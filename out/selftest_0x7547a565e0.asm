0x7547a565e0  00 0c 40 f9              ldr      x0, [x0, #0x18]
0x7547a565e4  c0 03 5f d6              ret      
0x7547a565e8  68 19 80 52              mov      w8, #0xcb
0x7547a565ec  1f 01 09 6b              cmp      w8, w9
0x7547a565f0  e0 17 9f 1a              cset     w0, eq
0x7547a565f4  28 00 80 52              mov      w8, #1
0x7547a565f8  08 05 00 11              add      w8, w8, #1
0x7547a565fc  08 10 00 b9              str      w8, [x0, #0x10]
