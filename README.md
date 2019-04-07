# SimpleCPU

Warren's simple CPU. It's purpose is solely to help Warren understand
how to deal with block RAM/ROM which is clocked, as against RAM/ROM
which is purely combinational. The high-level datapath design is:

```
                 8
  ROM -----------/---------------------
   ^        |        |        |       ^
   |        V        V        V       |
  8/        AR       IR       X-------+
   |        |        |
   |<-------+        V
   |              Decoder <--- uSeq
   V
   PC
```

The CPU is microsequenced. On phase zero of each high-level
instruction, IR is fetched from ROM[PC++] and uSeq is incremented.
Further phases can: load the address register (AR), load the X
register from ROM[PC] or ROM[AR], write the X register to ROM[AR],
or write AR to PC (so as to jump the PC).

There are a few generic components: register, counter, memory.
The main ROM has 256 8-bit locations; ditto the Decoder ROM.
The low nibble of the IR is combined with the low nibble of the uSeq
phase to index the Decoder ROM. Thus: only 16 possible high-level
instructions, each of which can have up to 16 microinstructions.
The current instructions are:

```
0 NOP: IRload PCincr         Do nothing except increment the PC
       uSreset
1 LCX: IRload PCincr         Load X with byte after instruction
       Xload uSreset
2 LDX: IRload PCincr         Load X with ROM[byte after instruction]
       ARload PCincr
       ARena Xload uSreset
3 STX: IRload PCincr         Store X to ROM[byte after instruction]
       ARload PCincr                 OK, so ROM is also RAM-like!
       ARena Xena uSreset
4 JMP: IRload PCincr         Jump: set PC's value to byte after instruction
       ARload PCincr
       ARena PCload uSreset
```

The rom.hex file has this short machine code program:

```
  00: LCX $23        01 23
  02: STX $40        03 40   Store 0x23 into memory location 0x40
  04: LCX $56        01 56
  06: STX $41        03 41   Store 0x56 into memory location 0x41
  08: JMP $0C        04 0C   Skip over some instructions
  0A: NOP            00
  0B: NOP            00
  0C: LDX $40        02 40   Load X from mem location 0x40, should get 0x23
  0E: LDX $41        02 41   Load X from mem location 0x41, should get 0x56
  10: NOP            00
  11: JMP $10        04 10   Jump back to the NOP at location 0x10
```
