`define WORD        [15:0]
`define NUMREGS     [15:0]
`define MEMSIZE 	[0:65535]
`define STATE       [3:0]
`define FCNSTATE	[3:0]

//data parts of the instruction
`define OPCODELOC	[15:12]
`define FCNCODELOC  [11:8]
`define RDLOC 		[3:0]
`define RSLOC 		[7:4]
`define EIGHTBITLOC [11:4]

//WHAT REGISTERS ARE WHAT
`define AT          [11]
`define RV          [12]
`define RA          [13]
`define FP          [14]
`define SP          [15]

//OP CODES
`define OPbz		4'he
`define OPbnz		4'hf
`define OPci8		4'hb
`define OPcii		4'hc
`define OPcup		4'hd
`define OPINTS		4'h7
`define OPPOSITS	4'h6
`define OPBITWISE	4'h5
`define OPMEM		4'h4
`define OPANYNEG    4'h3
`define OPCONVERT	4'h2
`define OPOTHER		4'h1
`define OPtrap		4'h0

//FCN CODES
//OPINTS
`define FCNaddi		4'h0
`define FCNaddii	4'h1
`define FCNmuli		4'h2
`define FCNmulii	4'h3
`define FCNshi		4'h4
`define FCNshii 	4'h5
`define FCNslti		4'h6
`define FCNsltii	4'h7
//OPPOSITS
`define FCNaddp		4'h0
`define FCNaddpp	4'h1
`define FCNmulp		4'h2
`define FCNmulpp	4'h3
//OPBITWISE
`define FCNand		4'h0
`define FCNor 		4'h1
`define FCNxor		4'h2
//OPMEM
`define FCNld		4'h0
`define FCNst		4'h1
//OPANYNEG
`define FCNanyi     4'h0
`define FCNanyii	4'h1
`define FCNnegi		4'h2
`define FCNnegii	4'h3
//OPCONVERT
`define FCNi2p		4'h0
`define FCNii2pp	4'h1
`define FCNp2i		4'h2
`define FCNpp2ii	4'h3
`define FCNinvp		4'h4
`define FCNinvpp	4'h5
//OPOTHER
`define FCNnot		4'h0
`define FCNjr		4'h1

//STATES
`define START  		4'ha
`define FINISH 		4'h9
`define DECODE 		4'h8


module processor(output reg halted, input reset, input clk);

reg `WORD instructionMem `MEMSIZE; // instruction memory
reg `WORD data `MEMSIZE; // data memory;
reg `WORD registers `NUMREGS;
reg `WORD pc, address, instructionReg;
reg `STATE state;
reg `FCNSTATE fcn;

always @ (reset) begin
  halted <= 0;
  pc <= 0;
  state <= `START;
  $readmemh0(instructionMem);
  $readmemh1(data);
end

//checking input
always @ (posedge clk) begin
  halted = 0;
  case(state)
    // Dummy codes
    `START : begin instructionReg <= instructionMem[pc]; pc <= pc + 1; state <= `DECODE; end
    `DECODE : begin state <= instructionReg `OPCODELOC; fcn <=	instructionReg `FCNCODELOC; end
    `FINISH : begin halted <= 1; end

    // 	Codes without functions
    `OPtrap : begin halted <= 1; end
    `OPbz : begin if(registers[instructionReg `RDLOC] == 0) pc <= pc + instructionReg `EIGHTBITLOC - 1; state <=`START; end
    `OPbnz : begin if(registers[instructionReg `RDLOC] != 0) pc <= pc + instructionReg `EIGHTBITLOC - 1; state <=`START; end
    `OPci8 : begin if(instructionReg `EIGHTBITLOC[7] == 0) registers[instructionReg `RDLOC][15:8] <= 8'h00;
	               else registers[instructionReg `RDLOC][15:8] <= 8'hff;
				   registers[instructionReg `RDLOC][7:0] <= instructionReg `EIGHTBITLOC;
				   state <=`START; end
    `OPcii : begin registers[instructionReg `RDLOC][7:0] <= instructionReg `EIGHTBITLOC;
                   registers[instructionReg `RDLOC][15:8] <= instructionReg `EIGHTBITLOC;
                   state <=`START; end
    `OPcup : begin registers[instructionReg `RDLOC][15:8] <= instructionReg `EIGHTBITLOC; state <=`START; end


    // Codes with Functions
    `OPINTS : begin
                case(fcn)
					`FCNaddi : begin
						registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] + registers[instructionReg `RSLOC];
						state <=`START; end
					`FCNaddii : begin
						registers[instructionReg `RDLOC][15:8] <= registers[instructionReg `RDLOC][15:8] + registers[instructionReg `RSLOC][15:8];
						registers[instructionReg `RDLOC][7:0] <= registers[instructionReg `RDLOC][7:0] + registers[instructionReg `RSLOC][7:0];
						state <=`START; end
					`FCNmuli : begin
						registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] * registers[instructionReg `RSLOC];
						state <=`START; end
					`FCNmulii : begin
						registers[instructionReg `RDLOC][15:8] <= registers[instructionReg `RDLOC][15:8] * registers[instructionReg `RSLOC][15:8];
						registers[instructionReg `RDLOC][7:0] <= registers[instructionReg `RDLOC][7:0] * registers[instructionReg `RSLOC][7:0];
						state <=`START; end
					`FCNshi : begin
						if(registers[instructionReg `RSLOC] > 0)
							registers[instructionReg `RDLOC] <=  registers[instructionReg `RDLOC] << registers[instructionReg `RSLOC];
						else
							registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] >> -registers[instructionReg `RSLOC];
						state <=`START; end
					`FCNshii : begin
						if(registers[instructionReg `RSLOC][15:8] > 0)
							registers[instructionReg `RDLOC][15:8] <=  registers[instructionReg `RDLOC][15:8] << registers[instructionReg `RSLOC][15:8];
						else
							registers[instructionReg `RDLOC][15:8] <= registers[instructionReg `RDLOC][15:8] >> -registers[instructionReg `RSLOC][15:8];
						if(registers[instructionReg `RSLOC][7:0] > 0)
							registers[instructionReg `RDLOC][7:0] <=  registers[instructionReg `RDLOC][7:0] << registers[instructionReg `RSLOC][7:0];
						else
							registers[instructionReg `RDLOC][7:0] <= registers[instructionReg `RDLOC][7:0] >> -registers[instructionReg `RSLOC][7:0];
						state <=`START;	end
					`FCNslti : begin registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] < registers[instructionReg `RSLOC];
						state <=`START; end
					`FCNsltii : begin
						registers[instructionReg `RDLOC][15:8] <= registers[instructionReg `RDLOC][15:8] < registers[instructionReg `RSLOC][15:8];
						registers[instructionReg `RDLOC][7:0] <= registers[instructionReg `RDLOC][7:0] < registers[instructionReg `RSLOC][7:0];
						state <=`START; end

					default : begin halted <= 1; end
				endcase
			  end

    `OPMEM : begin
                case(fcn)
					`FCNld : begin
						registers[instructionReg `RDLOC] <= data[registers[instructionReg `RSLOC]];
						state <=`START; end
					`FCNst : begin
						data[registers[instructionReg `RSLOC]] <= registers[instructionReg `RDLOC];
						state <=`START; end

					default : begin halted <= 1; end
				endcase
			 end

	`OPANYNEG : begin
					case(fcn)
						//unsure what "any" does, so is this right?
						`FCNanyi : begin
							if(registers[instructionReg `RDLOC] == 0)
								registers[instructionReg `RDLOC] <= 0;
							else registers[instructionReg `RDLOC] <= -1;
							state <=`START; end
						`FCNanyii : begin
							if(registers[instructionReg `RDLOC][15:8] == 0)
								registers[instructionReg `RDLOC][15:8] <= 0;
							else registers[instructionReg `RDLOC][15:8] <= -1;
							if(registers[instructionReg `RDLOC][7:0] == 0)
								registers[instructionReg `RDLOC][7:0] <= 0;
							else registers[instructionReg `RDLOC][7:0] <= -1;
							state <=`START; end
						`FCNnegi : begin
							registers[instructionReg `RDLOC] <= -registers[instructionReg `RDLOC];
							state <=`START; end
						`FCNnegii : begin
							registers[instructionReg `RDLOC][15:8] <= -registers[instructionReg `RDLOC][15:8];
							registers[instructionReg `RDLOC][7:0] <= -registers[instructionReg `RDLOC][7:0];
							state <=`START; end

						default : begin halted <= 1; end
					endcase
				end

    `OPBITWISE : begin
					case(fcn)
						`FCNand : begin
							registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] & registers[instructionReg `RSLOC];
							state <=`START; end
						`FCNor : begin
							registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] | registers[instructionReg `RSLOC];
							state <=`START; end
						`FCNxor : begin
							registers[instructionReg `RDLOC] <= registers[instructionReg `RDLOC] ^ registers[instructionReg `RSLOC];
							state <=`START; end

						default : begin halted <= 1; end
					endcase
				  end

    `OPOTHER : begin
                    case(fcn)
						`FCNnot : begin
							registers[instructionReg `RDLOC] <= ~registers[instructionReg `RDLOC];
							state <=`START; end
						`FCNjr : begin pc <= registers[instructionReg `RDLOC]; state <=`START; end

						default : begin halted <= 1; end
					endcase

			   end

	//dont need to implement
  `OPCONVERT : begin halted <= 1; end
	`OPPOSITS : begin halted <= 1; end
	//dont need to implement

    default : begin halted <= 1; end
    endcase
  end
endmodule

module testbench;
reg reset = 0;
reg clk = 0;
wire halt;
processor PE(halt, reset, clk);
initial begin
  $dumpfile;
  $dumpvars(0, PE);
  #10 reset = 1;
  #10 reset = 0;
  while (!halt) begin
    #10 clk = 1;
    #10 clk = 0;
  end
  $finish;
end
endmodule
