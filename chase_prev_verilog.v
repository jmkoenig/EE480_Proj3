`define UPPER [15:8]
`define LOWER [7:0]
`define WORD [15:0]
`define TOPOP [15:12]
`define OPCODE [15:8]
`define OPCODE_S [7:0]
`define CONST [11:4]
`define RD [3:0]
`define RS [7:4]
`define MEMSIZE [65535:0]
`define REGSIZE [15:0]

// op defines
`define trap  8'h00
`define jr    8'h01
`define not   8'h10
`define i2p   8'h20
`define ii2pp 8'h21
`define p2i   8'h22
`define pp2ii 8'h23
`define invp  8'h24
`define invpp 8'h25
`define anyi  8'h30
`define anyii 8'h31
`define negi  8'h32
`define negii 8'h33
`define ld    8'h40
`define st    8'h41
`define xor   8'h52
`define or    8'h51
`define and   8'h50
`define addp  8'h60
`define addpp 8'h61
`define mulp  8'h62
`define mulpp 8'h63
`define addi  8'h70
`define addii 8'h71
`define muli  8'h72
`define mulii 8'h73
`define shi   8'h74
`define shii  8'h75
`define slti  8'h76
`define sltii 8'h77


`define ci8 8'hb
`define cii 8'hc
`define cup 8'hd
`define bz  8'he
`define bnz 8'hf






module processor(halted, reset, clk);
    output reg halted;
    input reset, clk;

    reg `WORD r `REGSIZE;
    reg `WORD text `MEMSIZE; // instruction memory
    reg `WORD data `MEMSIZE; // data memory
    reg `WORD PC = 0;
    wire `WORD inst;
    wire alu_valid;
    wire `WORD alu_ans;
    wire `WORD convert_ans;
    assign inst = text[PC];
    ALU logic_unit(alu_valid, alu_ans, inst `OPCODE, r[inst `RD], r[inst `RS]);
    type_converter type_conv(convert_ans, inst[9], inst[10], r[inst `RD]);
    always @(posedge reset) begin
        halted <= 0;
        PC <= 0;
        $readmemh0(text);
        $readmemh1(data);
    end

    always@(posedge clk) begin
        $display("PC: %h, Instruction: %h, Time: %d\n",PC, inst, $time);
    	PC <= PC + 1;
    	casez (inst `TOPOP)
        {1'b0,{3{1'bz}} } :
                case (inst `OPCODE)
                    `i2p, `ii2pp, `p2i, `pp2ii : r[inst `RD] <= convert_ans; 
                    `jr : PC <= r[inst `RD];
                    `ld : r[inst `RD] <= data[r[inst `RS]];
                    `st : data[r[inst `RS]] <= r[inst `RD];
                    `trap : halted = 1;
                    default: if (alu_valid) begin
                                r[inst `RD] <= alu_ans;
                                $display("Ans: %h, Time: %d\n",alu_ans, $time);
                            end
                            else begin
                                $display("Invalid Instruction ALU: %h\n",logic_unit.alu_op);
                                halted = 1; end
                endcase
        `bnz : if (r[inst `RD] != 0) PC <= PC + {{8{inst[11]}},inst `CONST};
        `bz : if (r[inst `RD] == 0) PC <= PC + {{8{inst[11]}},inst `CONST};
        `ci8 : begin r[inst `RD] `UPPER <= {8{inst [11]}};
                r[inst `RD] `LOWER <= inst `CONST; end
        `cii : begin r[inst `RD] `UPPER <= inst `CONST;
                r[inst `RD] `LOWER <= inst `CONST; end
        `cup : r[inst `RD] `UPPER <= inst `CONST;
        default : begin
                $display("Invalid Instruction: %h\n",inst `OPCODE);
                halted = 1; end
    	endcase
    end
endmodule


module ALU(valid, ans, alu_op, x, y);
    input `OPCODE_S alu_op;
    input `WORD x;
    input `WORD y;
    output reg `WORD ans;
    output reg valid;

    always @* begin
    valid = 1;
    case (alu_op)
        `addi, `addp : ans = x + y;
        `muli, `mulp : ans = x * y;
        `negi : ans = -x;
        `shi : ans = ((y <= 127) ? (x << y) : (x >> -y));
        `anyi : ans = (x ? -1 : 0);
        `slti : ans = x < y;
        `invp : ans = 0;
        `addii, `addpp : begin ans `UPPER = x `UPPER + y `UPPER;
            ans `LOWER = x `LOWER + y `LOWER; end
        `mulii, `mulpp : begin ans `UPPER = x `UPPER * y `UPPER;
            ans `LOWER = x `LOWER * y `LOWER; end
        `negii : begin ans `UPPER = -x `UPPER;
            ans `LOWER = -x `LOWER;  end
       `shii : begin ans `UPPER =  ((y `UPPER <= 127) ? (x `UPPER << y `UPPER) : (x `UPPER >> -y `UPPER));
            ans `LOWER =  ((y `LOWER <= 127) ? (x `LOWER << y `LOWER) : (x `LOWER >> -y `LOWER)); end
        `anyii : begin ans `UPPER = (x `UPPER ? -1 : 0);
            ans `LOWER = (x `LOWER ? -1 : 0); end
        `sltii : begin ans `UPPER = x `UPPER < y `UPPER;
            ans `LOWER = x `LOWER < y `LOWER; end
        `invpp : ans = 0;
        `and : ans = x & y;
        `or : ans = x | y;
        `xor : ans = x ^ y;
        `not : ans = ~x;
        default : valid = 0;
    endcase
    end
endmodule

module type_converter(ans, posit_to_int, split, x);
    output reg `WORD ans;
    input posit_to_int, split;
    input `WORD x;
    always @* begin
        ans = x;
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
  $display("R0: %h, Time: %d\n",PE.r[0], $time);
  $finish;
end
endmodule



