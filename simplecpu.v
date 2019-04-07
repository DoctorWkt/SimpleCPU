// Warren's simple CPU. It's purpose is solely to help Warren understand
// how to deal with block RAM/ROM which is clocked, as against RAM/ROM
// which is purely combinational. The high-level datapath design is:
//
//                 8
//  ROM -----------/---------------------
//   ^        |        |        |       ^
//   |        V        V        V       |
//  8/        AR       IR       X-------+
//   |        |        |
//   |<-------+        V
//   |              Decoder <--- uSeq
//   V
//   PC
//
// The CPU is microsequenced. On phase zero of each high-level
// instruction, IR is fetched from ROM[PC++] and uSeq is incremented.
// Further phases can: load the address register (AR), load the X
// register from ROM[PC] or ROM[AR], write the X register to ROM[AR],
// or write AR to PC (so as to jump the PC).
//
// There are a few generic components: register, counter, memory.
// The main ROM has 256 8-bit locations; ditto the Decoder ROM.
// The low nibble of the IR is combined with the low nibble of the uSeq
// phase to index the Decoder ROM. Thus: only 16 possible high-level
// instructions, each of which can have up to 16 microinstructions.
// The current instructions are:
//
// 0 NOP: IRload PCincr		Do nothing except increment the PC
// 	  uSreset
// 1 LCX: IRload PCincr		Load X with byte after instruction
//  	  Xload uSreset
// 2 LDX: IRload PCincr		Load X with ROM[byte after instruction]
//	  ARload PCincr
//	  ARena Xload uSreset
// 3 STX: IRload PCincr		Store X to ROM[byte after instruction]
//	  ARload PCincr			OK, so ROM is also RAM-like!
//	  ARena Xena uSreset
// 4 JMP: IRload PCincr		Jump: set PC's value to byte after instruction
//	  ARload PCincr
//	  ARena PCload uSreset
//
// The rom.hex file has this short machine code program:
//   00: LCX $23	01 23
//   02: STX $40	03 40	Store 0x23 into memory location 0x40
//   04: LCX $56	01 56
//   06: STX $41	03 41	Store 0x56 into memory location 0x41
//   08: JMP $0C	04 0C	Skip over some instructions
//   0A: NOP		00
//   0B: NOP		00
//   0C: LDX $40	02 40	Load X from mem location 0x40, should get 0x23
//   0E: LDX $41	02 41	Load X from mem location 0x41, should get 0x56
//   10: NOP		00
//   11: JMP $10	04 10	Jump back to the NOP at location 0x10


// Register component
module register (i_clk, wr_stb, data, result);
  input       i_clk;		// Do updates on rising i_clk
  input       wr_stb;		// Update register if high
  input  [7:0] data;		// Input data
  output [7:0] result;		// Output register value

  reg [7:0] internal_value=0;	// Register's internal value
  assign result= internal_value;

  always @(posedge i_clk) 	// Update internal value when wr_stb is high
    if (wr_stb)
      internal_value <= data;
endmodule

// Counter component
module counter (i_clk, wr_stb, incr_stb, data, result);
  input        i_clk;		// Do updates on rising i_clk
  input        wr_stb;		// Update counter if high
  input        incr_stb;	// Increment cntr if high, overridden by wr_stb
  input  [7:0] data;		// Input data
  output [7:0] result;		// Output counter's value

  reg [7:0] internal_value=0;	// Counter's internal value
  assign result= internal_value;

  always @(posedge i_clk) 	// Update internal value when wr_stb is high
    if (wr_stb)	
      internal_value <= data;
    else if (incr_stb)		// Otherwise increment if incr_stb is high
      internal_value <= internal_value + 1;
endmodule

// Memory component, unclocked. 256 8-bit memory locations
// XXX: this is the one I need to work out how to implement in block RAM.
module memory(i_clk, wr_stb, address, data, result);
  parameter    filename = "data.hex";
  input        i_clk;		// Do updates on rising i_clk
  input        wr_stb;		// Update memory if high
  input  [7:0] address;		// Address in memory to write data
  input  [7:0] data;		// Input data
  output [7:0] result;		// Output memory's value

  reg [7:0] mem [0:255];	// Actual memory store
  assign result= mem[address];

  always @(posedge i_clk) 	// Update internal value if wr_stb is high
    if (wr_stb)
      mem[address] <= data;

  initial begin			// Fill the memory with some initial values
    $readmemh(filename, mem);
  end
endmodule

module simplecpu (i_clk);
  input i_clk;			// System clock signal provided by testbench
				// Internal wiring
  wire [7:0] databus;		// The data bus, connected to ROM, AR, IR, X
  wire [7:0] addressbus;	// The address bus, either PC or AR's value
  wire [7:0] Memvalue;		// Output of memory
  wire [7:0] Xvalue;		// Output of X register
  wire [7:0] ARvalue;		// Output of address register
  wire [7:0] IRvalue;		// Output of instruction register
  wire [7:0] PCvalue;		// Output of PC
  wire [7:0] uSeqvalue;		// Output of microsequencer
  wire [7:0] Decodevalue;	// Output of instruction decoder

				// Active high ctrl lines: bits of Decodevalue
  wire	     PCload;		// Load PC with the AR value
  wire	     Xload;		// Load the A register
  wire	     IRload;		// Load the instruction register
  wire	     ARload;		// Load the address register
  wire	     ARena;		// Put AR on the address bus; put PC if low
  wire	     Xena;		// Put X on the data bus; put memory if low
  wire	     uSreset;		// Reset the microsequence phase to zero
  wire	     PCincr;		// Increment the PC

				// Multiplex on the data and address busses
  assign addressbus= ARena ? ARvalue : PCvalue;
  assign databus=    Xena  ? Xvalue  : Memvalue;

				// Add in the components
  register  Xreg(i_clk, Xload,  databus, Xvalue);
  register IRreg(i_clk, IRload, databus, IRvalue);
  register ARreg(i_clk, ARload, databus, ARvalue);

				// The microsequencer either increments (1'b1),
				// or is reset to value 8'h00
  counter uSeq(i_clk, uSreset, 1'b1,   8'h00,   uSeqvalue);
  counter   PC(i_clk, PCload,  PCincr, ARvalue, PCvalue);

  memory #(.filename("rom.hex"))
	 ROM(i_clk, Xena, addressbus, databus, Memvalue);
  memory #(.filename("decode.hex"))
	 Decode(i_clk, 1'b0, {IRvalue[3:0],uSeqvalue[3:0]}, 8'h00, Decodevalue);

				// Get the individual control
				// lines from the Decodevalue
  assign PCincr=  Decodevalue[7];
  assign uSreset= Decodevalue[6];
  assign Xena=    Decodevalue[5];
  assign ARena=   Decodevalue[4];
  assign ARload=  Decodevalue[3];
  assign IRload=  Decodevalue[2];
  assign Xload=   Decodevalue[1];
  assign PCload=  Decodevalue[0];

endmodule


// The test bench to generate the VCD file from the simulation
module icarus_tb();
  reg i_clk;

  // Initialise the clock, create the VCD file
  initial begin        
    $dumpfile("test.vcd");
    $dumpvars(0, icarus_tb);
    i_clk = 0;       	// initial value of clk
    #60 $finish;     	// Terminate simulation
  end

  // Clock generator
  always begin
    #1 i_clk = ~i_clk; 	// Toggle i_clk every tick
  end

  // Connect the CPU to the test bench
  simplecpu DUT(i_clk);

endmodule
