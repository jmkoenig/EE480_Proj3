// Important State Machine States
`define Start		4'b1000
`define Decode  	4'b1001

// Basic sizes
`define OPSIZE		[7:0]
`define STATE		[3:0]
`define WORD		[15:0]
`define MEMSIZE 	[65535:0]	// Total amount of instructions in memory
`define REGSIZE 	[15:0]		// Number of Registers
`define DEST		[15:0]

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
`define OPnop           8'b00000010
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
`define NOP		16'b0000001000000001

module processor(halt, reset, clk);
	//control signal definitions
	output reg halt;
	input reset, clk;
	reg `STATE s;
	reg `OPSIZE op;

	//processor component definitions
	reg `WORD text `MEMSIZE;	// instruction memory
	reg `WORD data `MEMSIZE;	// data memory
	reg `WORD pc = 0, pc3;
	reg `WORD regfile `REGSIZE;	// Register File Size
	wire `WORD aluOut;
	reg `DEST target = 0;		// jump target
	//new variables
	reg jump, jump3;
	reg `WORD ir, ir0, ir1, ir2;
	reg `WORD rd1, rs1, rd2, rs2;
	reg `WORD imm, res;
	reg `WORD tpc;
	wire pendpc;			// is there a pc update
	reg wait1 = 0;	// is a stall needed in stage 1 or 2

	//processor initialization
	always @(posedge reset) begin
		halt = 0;
		pc = 0;
		//state is NOP
		s = `TrapOrJr;
		jump = 0;
		jump3 = 0;
		rd1 = 0;
		rs1 = 0;
		ir0 = `NOP;
		ir1 = `NOP;
		ir2 = `NOP;
		
		//The following functions read from VMEM?
		$readmemh0(text);
		$readmemh1(data);
	end
	
	//These are the operations 
	function `WORD ALUout;
		input `OPSIZE op;
		input `WORD rd, rs;
		case (op)
			`OPaddi:  begin ALUout = rd `WORD + rs `WORD; end		
			`OPaddii: begin
				ALUout `HighBits = rd `HighBits + rs `HighBits; 
				ALUout `LowBits = rd `LowBits + rs `LowBits;
			end
			`OPmuli: begin ALUout = rd `WORD * rs `WORD; end
			`OPmulii: begin 
				ALUout `HighBits = rd `HighBits * rs `HighBits; 
				ALUout `LowBits = rd `LowBits * rs `LowBits; 
			end
			`OPshi: begin ALUout = ((rs `WORD > 0) ? (rd `WORD << rs `WORD) : (rd[15:0] >> -rs[15:0])); end
			`OPshii: begin 
				ALUout `HighBits = ((rs `HighBits >0)?(rd `HighBits <<rs `HighBits):(rd `HighBits >>-rs `HighBits ));
				ALUout `LowBits = ((rs `LowBits >0)?(rd `LowBits <<rs `LowBits):(rd `LowBits >>-rs `LowBits ));
			end
			`OPslti: begin ALUout = rd `WORD < rs `WORD; end
			`OPsltii: begin 
				ALUout `HighBits= rd `HighBits < rs `HighBits; 
				ALUout `LowBits = rd `LowBits < rs `LowBits; 
			end
			`OPaddp: begin ALUout = rd `WORD + rs `WORD; end
			`OPaddpp: begin 
				ALUout `HighBits = rd `HighBits + rs `HighBits; 
				ALUout `LowBits = rd `LowBits + rs `LowBits;
			end
			`OPmulp: begin ALUout = rd `WORD * rs `WORD; end
			`OPmulpp: begin 
				ALUout `HighBits = rd `HighBits * rs `HighBits; 
				ALUout `LowBits = rd `LowBits * rs `LowBits; 
			end
			`OPand: begin ALUout = rd & rs; end
			`OPor: begin ALUout = rd | rs; end
			`OPxor: begin ALUout = rd ^ rs; end
			`OPanyi: begin ALUout = (rd ? -1: 0); end
			`OPanyii: begin 
				ALUout `HighBits= (rd `HighBits ? -1 : 0); 
				ALUout `LowBits = (rd `LowBits ? -1 : 0); 
			end
			`OPnegi: begin ALUout = -rd; end
			`OPnegii: begin 
				ALUout `HighBits = -rd `HighBits; 
				ALUout `LowBits = -rd `LowBits; 
			end
			`OPi2p: begin ALUout = rd; end
			`OPii2pp: begin ALUout = rd; end
			`OPp2i: begin ALUout = rd; end
			`OPpp2ii: begin ALUout = rd; end
			`OPinvp: begin ALUout = 0; end
			`OPinvpp: begin ALUout = 0; end
			`OPnot: begin ALUout = ~rd; end	
		endcase	
	endfunction
	
	//checks if the destination register is set
	function setsrd;
	input `WORD inst;
	setsrd = (inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz) && (inst `OP != `OPst) && (inst `OP != `OPtrap) 
		&& (inst `OP != `OPnop);
	endfunction
	
	//checks if pc is set
	function setspc;
	input `WORD inst;
		setspc = !((inst `OP != `OPjr) && (inst `Op0 != `OPbz) && (inst `Op0 != `OPbnz));
	endfunction
	
	//check if rd is used
	function usesrd;
	input `WORD inst;	
	usesrd = (inst `OP != `OPld) && (inst `OP != `OPtrap) && (inst `OP != `OPci8) && (inst `OP != `OPcii) && (inst `OP != `OPcup) 
		&& (inst `OP != `OPnop);
	endfunction
	
	//check if rd is used
	function usesrs;
	input `WORD inst;
	usesrs = !((inst `OP != `OPaddi) && (inst `OP != `OPaddii) && (inst `OP != `OPaddp) && (inst `OP != `OPaddpp) && 
		   (inst `OP != `OPld) && (inst `OP != `OPand) && (inst `OP != `OPmuli) && (inst `OP != `OPmulii) && 
		   (inst `OP != `OPmulp) && (inst `OP != `OPmulpp) && (inst `OP != `OPshi) && (inst `OP != `OPshii) && 
		   (inst `OP != `OPslti) && (inst `OP != `OPst) && (inst `OP != `OPxor));
	endfunction
	
	//is pc changing
	assign pendpc = (setspc(ir0) || setspc(ir1)) || setspc(ir2);
	
	//start of state 0
	always @(posedge clk) begin
		tpc = (jump3 ? pc3 : pc);
		if (wait1) begin
    			// blocked by stage 1, so don't increment
   			pc <= tpc;
  		end else begin
   			// not blocked by stage 1
			//pendpc usage has been removed here, now assuming not taken
  			ir = text[tpc];
			ir0 <= ir;
			pc <= tpc + 1;
		end
	end
	
	//start of stage 1
	always @(posedge clk) begin
		//check for conflict
		if((ir0 != `NOP) && setsrd(ir1) && 
		   ((usesrd(ir0) && (ir0 `Reg0 == ir1 `Reg0)) || (usesrs(ir0) && (ir0 `Reg1 == ir1 `Reg0)))) begin
			wait1 = 1;
			ir1 <= `NOP;
		//no conflict
		end else begin
			wait1 = 0;
			rd1 <= regfile[ir0 `Reg0];
			rs1 <= regfile[ir0 `Reg1];
			ir1 <= ir0;
			op <= ir0 `OP;
			s  <= ir0 `Op0;
			if(jump3)
				ir1 <= `NOP;
			else
				ir1 <= ir0;
		end
		//check to ensure no incorrect follow through
	end
	
	//stage 2 starts here
	always @(posedge clk) begin
		//State machine case
		case (s)
			`TrapOrJr: begin
				case (op)
					`OPtrap: 
						begin
							jump <= 0;
						end
					`OPjr:
						begin
							target <= regfile[ir1 `Reg0 ];
							jump <= 1;
						end
					`OPnop:
						begin
							jump <= 0;
						end
				endcase
			 end // halts the program and saves the current instruction
			`LdOrSt:
				begin
					case (op)
						`OPld:
							begin
								res <= data[regfile [ir1 `Reg1]];
								jump <= 0;
							end
						`OPst:
							begin
								data[regfile [ir1 `Reg1]] = regfile [ir1 `Reg0];
								jump <= 0;
							end
					endcase
				end
			`OPci8:
				begin
					res <= {{8{ir1[7]}} ,ir1 `Imm8};
					jump <= 0;
				end
			`OPcii:
				begin
					res `HighBits <= ir1 `Imm8;
					res `LowBits <= ir1 `Imm8;
					jump <= 0;
				end
			`OPcup:
				begin
					res `HighBits <= ir1 `Imm8;
					jump <= 0;
				end
			`OPbz:
				begin
					if (regfile [ir1 `Reg0] == 0) begin
							target <= pc + ir1 `Imm8;
							jump <= 1;
					end else
						jump <= 0;	
				end
			`OPbnz:
				begin
					if (regfile [ir1 `Reg0] != 0) begin
						target <= pc + ir1 `Imm8;
						jump <= 1;
					end else
						jump <= 0;
				end
			default: //default cases are handled by ALU
				begin
					res <= ALUout(op,rd1,rs1);
					jump <= 0;
				end
		endcase	
		rd2 <= rd1;
		rs2 <= rs1;
		if(jump3)
			ir2 <= `NOP;
		else
			ir2 <= ir1;
	end
	
	//stage 3 starts here
	always @ (posedge clk) begin
		if(ir2 `OP == `OPtrap) 
			halt = 1;
		if(!jump3 && !jump && (ir2 != `NOP && setsrd(ir2)))
			regfile [rd2] <= res;
		if(jump)
			jump3 <= 1;
		else
			jump3 <= 0;
		pc3 <= target;
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
