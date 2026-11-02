0x754342a684  fe 0f 1b f8              str      x30, [sp, #-0x50]!
0x754342a688  fa 67 01 a9              stp      x26, x25, [sp, #0x10]
0x754342a68c  f8 5f 02 a9              stp      x24, x23, [sp, #0x20]
0x754342a690  f6 57 03 a9              stp      x22, x21, [sp, #0x30]
0x754342a694  f4 4f 04 a9              stp      x20, x19, [sp, #0x40]
0x754342a698  88 1c 40 f9              ldr      x8, [x4, #0x38]
0x754342a69c  f5 03 04 aa              mov      x21, x4
0x754342a6a0  f8 03 03 aa              mov      x24, x3
0x754342a6a4  f6 03 02 aa              mov      x22, x2
0x754342a6a8  f7 03 01 aa              mov      x23, x1
0x754342a6ac  f4 03 00 aa              mov      x20, x0
0x754342a6b0  68 01 00 b5              cbnz     x8, #0x754342a6dc
0x754342a6b4  20 d3 02 90              adrp     x0, #0x7548e8e000
0x754342a6b8  00 d0 42 f9              ldr      x0, [x0, #0x5a0]
0x754342a6bc  3e 1c db 97              bl       #0x7542af17b4
0x754342a6c0  20 d3 02 90              adrp     x0, #0x7548e8e000
0x754342a6c4  00 dc 42 f9              ldr      x0, [x0, #0x5b8]
0x754342a6c8  3b 1c db 97              bl       #0x7542af17b4
0x754342a6cc  a8 1e 40 f9              ldr      x8, [x21, #0x38]
0x754342a6d0  68 00 00 b5              cbnz     x8, #0x754342a6dc
0x754342a6d4  e0 03 15 aa              mov      x0, x21
0x754342a6d8  7c e6 d9 97              bl       #0x7542aa40c8
0x754342a6dc  14 13 00 b4              cbz      x20, #0x754342a93c
0x754342a6e0  57 13 00 b4              cbz      x23, #0x754342a948
0x754342a6e4  96 13 00 b4              cbz      x22, #0x754342a954
0x754342a6e8  a8 1e 40 f9              ldr      x8, [x21, #0x38]
0x754342a6ec  00 11 40 f9              ldr      x0, [x8, #0x20]
0x754342a6f0  08 d4 44 39              ldrb     w8, [x0, #0x135]
0x754342a6f4  48 00 00 37              tbnz     w8, #0, #0x754342a6fc
0x754342a6f8  5d e6 d9 97              bl       #0x7542aa406c
0x754342a6fc  b4 1c db 97              bl       #0x7542af19cc
0x754342a700  a8 1e 40 f9              ldr      x8, [x21, #0x38]
0x754342a704  e1 03 18 aa              mov      x1, x24
0x754342a708  f3 03 00 aa              mov      x19, x0
0x754342a70c  02 15 40 f9              ldr      x2, [x8, #0x28]
0x754342a710  5c ac 4f 94              bl       #0x7544815880
0x754342a714  a8 1e 40 f9              ldr      x8, [x21, #0x38]
0x754342a718  01 01 40 f9              ldr      x1, [x8]
0x754342a71c  28 d4 44 39              ldrb     w8, [x1, #0x135]
0x754342a720  88 00 00 37              tbnz     w8, #0, #0x754342a730
0x754342a724  e0 03 01 aa              mov      x0, x1
0x754342a728  51 e6 d9 97              bl       #0x7542aa406c
0x754342a72c  e1 03 00 aa              mov      x1, x0
0x754342a730  88 02 40 f9              ldr      x8, [x20]
0x754342a734  09 5d 42 79              ldrh     w9, [x8, #0x12e]
0x754342a738  29 01 00 b4              cbz      x9, #0x754342a75c
0x754342a73c  0a 59 40 f9              ldr      x10, [x8, #0xb0]
0x754342a740  4a 21 00 91              add      x10, x10, #8
0x754342a744  4b 81 5f f8              ldur     x11, [x10, #-8]
0x754342a748  7f 01 01 eb              cmp      x11, x1
0x754342a74c  00 01 00 54              b.eq     #0x754342a76c
0x754342a750  29 05 00 f1              subs     x9, x9, #1
0x754342a754  4a 41 00 91              add      x10, x10, #0x10
0x754342a758  61 ff ff 54              b.ne     #0x754342a744
0x754342a75c  e0 03 14 aa              mov      x0, x20
0x754342a760  e2 03 1f 2a              mov      w2, wzr
0x754342a764  83 e6 d9 97              bl       #0x7542aa4170
0x754342a768  04 00 00 14              b        #0x754342a778
0x754342a76c  49 01 80 b9              ldrsw    x9, [x10]
0x754342a770  08 11 09 8b              add      x8, x8, x9, lsl #4
0x754342a774  00 e1 04 91              add      x0, x8, #0x138
0x754342a778  08 04 40 a9              ldp      x8, x1, [x0]
0x754342a77c  e0 03 14 aa              mov      x0, x20
0x754342a780  00 01 3f d6              blr      x8
