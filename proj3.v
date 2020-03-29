// Important State Machine States
`define Start		4'b1000
`define Decode  	4'b1001

// Basic sizes
`define OPSIZE		[7:0]
`define STATE		[3:0]
`define WORD		[15:0]
`define MEMSIZE 	[65535:0]	// Total amount of instructions in memory
`define REGSIZE 	[15:0]		// Number of Registers

//Instruction Field Placements
//NOTE: I could be wrong about these, I generated them from Dr. Deitz's assembler implementation
`define OP		[15:8]
`define Op0		[15:12]
`define Op1		[11:8]
`define Reg0		[3:0]
`define Reg1		[7:4]
`define Imm8		[11:4]
`define HighBits	[15:8]
`define LowBits		[7:0]

//4 bit op codes
`define LdOrSt		4'b0100
`define TrapOrJr	4'b0000
`define OPci8		4'b1011
`define OPcii		4'b1100
`define OPcup		4'b1101
`define OPbz		4'b1110
`define OPbnz		4'b1111

// 8 bit op codes
`define OPtrap		8'b00000000
`define OPjr 		8'b00000001
`define OPld		8'b01000000
`define OPst		8'b01000001
`define OPnot		8'b00010000
`define OPi2p		8'b00100000
`define OPii2pp		8'b00100001
`define OPp2i		8'b00100010
`define OPpp2ii		8'b00100011
`define OPinvp		8'b00100100
`define OPinvpp		8'b00100101
`define OPanyi		8'b00110000
`define OPanyii		8'b00110001
`define OPnegi		8'b00110010
`define OPnegii		8'b00110011
`define OPand		8'b01010000
`define OPor		8'b01010001
`define OPxor		8'b01010010
`define OPaddp		8'b01100000
`define OPaddpp		8'b01100001
`define OPmulp		8'b01100010
`define OPmulpp		8'b01100011
`define OPaddi		8'b01110000
`define OPaddii		8'b01110001
`define OPmuli		8'b01110010
`define OPmulii		8'b01110011
`define OPshi		8'b01110100
`define OPshii		8'b01110101
`define OPslti		8'b01110110
`define OPsltii		8'b01110111

// TODO: complete ALU
module alu(rd, rs, op, aluOut);
	input `WORD rd;
	input wire `WORD rs;
	input wire `OPSIZE op;
	output wire `WORD aluOut;
	
	
	reg `WORD out;
	assign aluOut = out;
	
	//These are the operations 
	always @* begin 
		case (op)
			`OPaddi:  begin out = rd `WORD + rs `WORD; end
			
			`OPaddii: begin
				out `HighBits = rd `HighBits + rs `HighBits; 
				out `LowBits = rd `LowBits + rs `LowBits;
			end
			`OPmuli: begin out = rd `WORD * rs `WORD; end
			`OPmulii: begin 
				out `HighBits = rd `HighBits * rs `HighBits; 
				out `LowBits = rd `LowBits * rs `LowBits; 
			end
			`OPshi: begin out = ((rs `WORD > 0) ? (rd `WORD << rs `WORD) : (rd[15:0] >> -rs[15:0])); end
			`OPshii: begin 
				out `HighBits = ((rs `HighBits >0)?(rd `HighBits <<rs `HighBits):(rd `HighBits >>-rs `HighBits ));
				out `LowBits = ((rs `LowBits >0)?(rd `LowBits <<rs `LowBits):(rd `LowBits >>-rs `LowBits ));
			end
			`OPslti: begin out = rd `WORD < rs `WORD; end
			`OPsltii: begin 
				out `HighBits= rd `HighBits < rs `HighBits; 
				out `LowBits = rd `LowBits < rs `LowBits; 
			end
			`OPaddp: begin out = rd `WORD + rs `WORD; end
			`OPaddpp: begin 
				out `HighBits = rd `HighBits + rs `HighBits; 
				out `LowBits = rd `LowBits + rs `LowBits;
			end
			`OPmulp: begin out = rd `WORD * rs `WORD; end
			`OPmulpp: begin 
				out `HighBits = rd `HighBits * rs `HighBits; 
				out `LowBits = rd `LowBits * rs `LowBits; 
			end
			`OPand: begin out = rd & rs; end
			`OPor: begin out = rd | rs; end
			`OPxor: begin out = rd ^ rs; end
			`OPanyi: begin out = (rd ? -1: 0); end
			`OPanyii: begin 
				out `HighBits= (rd `HighBits ? -1 : 0); 
				out `LowBits = (rd `LowBits ? -1 : 0); 
			end
			`OPnegi: begin out = -rd; end
			`OPnegii: begin 
				out `HighBits = -rd `HighBits; 
				out `LowBits = -rd `LowBits; 
			end
			`OPi2p: begin out = rd; end
			`OPii2pp: begin out = rd; end
			`OPp2i: begin out = rd; end
			`OPpp2ii: begin out = rd; end
			`OPinvp: begin out = 0; end
			`OPinvpp: begin out = 0; end
			`OPnot: begin out = ~rd; end	
		endcase	
	end
endmodule

module processor(halt, reset, clk);
	//control signal definitions
	output reg halt;
	input reset, clk;
	reg `STATE s;
	reg `OPSIZE op;

	//processor component definitions
	reg `WORD text `MEMSIZE;		// instruction memory
	reg `WORD data `MEMSIZE;		// data memory
	reg `WORD pc = 0;
	reg `WORD ir;
	reg `WORD regfile `REGSIZE;		// Register File Size
	reg `WORD rd, rs;
	wire `WORD aluOut;
	//new variables
	reg jump;
	reg `WORD ir0, ir1;
	reg `WORD im0, rd1, rn1, res;
	wire pendpc;		// is there a pc update
	reg wait1;		// is a stall needed in stage 1
	
	alu myalu(regfile [ir `Reg0], regfile [ir `Reg1], op, aluOut);

	//processor initialization
	always @(posedge reset) begin
		halt = 0;
		pc = 0;
		s = `Start;
		jump = 0;
		
		//The following functions read from VMEM?
		$readmemh0(text);
		$readmemh1(data);
	end

	//checks if the destination register is set
	function setsrd;
	input `WORD inst;
	setsrd = (inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz) && (inst `OP != `OPst) && (inst `OP != `OPtrap);
	endfunction
	
	//checks if pc is set
	function setspc;
	input `WORD inst;
	setspc = !((inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz));
	endfunction
	
	always @(posedge clk) begin
		//State machine case
		case (s)
			`TrapOrJr: begin
				case (op)
					`OPtrap: 
						begin
							halt <= 1; 
						end
					`OPjr:
						begin
							pc <= regfile[ ir `Reg0 ];
							s <= `Start;
						end
				endcase
			 end // halts the program and saves the current instruction
			`Start: begin ir <= text[pc];  s <= `Decode; end // Fetches first instruction and moves the state to decode
			`Decode: 
				begin // TODO: Figure out how to assign state s to procede with next step.
					op <= {ir `Op0, ir `Op1};
					s  <= ir `Op0;
				end
			`LdOrSt:
				begin
					case (op)
						`OPld:
							begin
								regfile [ir `Reg0] <= data[regfile [ir `Reg1]];
								pc <= pc + 1;
								s <= `Start;
							end
						`OPst:
							begin
								data[regfile [ir `Reg1]] = regfile [ir `Reg0];
								pc <= pc + 1;
								s <= `Start;
							end
					endcase
				end
			`OPci8:
				begin
					regfile [ir `Reg0] <= ((ir `Imm8 & 8'h80) ? 16'hff00 : 0) | (ir `Imm8 & 8'hff);
					pc <= pc + 1;
					s <= `Start;
				end
			`OPcii:
				begin
					regfile [ir `Reg0] `HighBits <= ir `Imm8;
					regfile [ir `Reg0] `LowBits <= ir `Imm8;
					pc <= pc + 1;
					s <= `Start;
				end
			`OPcup:
				begin
					regfile [ir `Reg0] `HighBits <= ir `Imm8;
					pc <= pc + 1;
					s <= `Start;
				end
			`OPbz:
				begin
					if (regfile [ir `Reg0] == 0)
						pc <= pc + ir `Imm8;
					s <= `Start;
				end
			`OPbnz:
				begin
					if (regfile [ir `Reg0] != 0)
						pc <= pc + ir `Imm8;
					s <= `Start;
				end
			default: //default cases are handled by ALU
				begin
					regfile [ir `Reg0] <= aluOut;
					pc <= pc + 1;
					s <= `Start;
				end
		endcase	
	end
endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halted;
processor PE(halted, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halted) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
