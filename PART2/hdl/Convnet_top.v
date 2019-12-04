module Convnet_top #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 8,
parameter WEIGHT_PER_ADDR = 9, 
parameter BIAS_PER_ADDR = 1,
parameter BW_PER_PARAM = 4
)
(
input clk,                           //clock input
input rst_n,                         //synchronous reset (active low)

input enable,
input [BW_PER_ACT-1:0] input_data,    //input image

//read data from SRAM group A
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a3,
//read data from SRAM group B
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b3,

input [WEIGHT_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_weight,  //read data from SRAM weight
input [BIAS_PER_ADDR*BW_PER_PARAM-1:0] sram_rdata_bias,      //read data from SRAM bias

//read address from SRAM group A
output [5:0] sram_raddr_a0,
output [5:0] sram_raddr_a1,
output [5:0] sram_raddr_a2,
output [5:0] sram_raddr_a3,
//read address from SRAM group B
output [5:0] sram_raddr_b0,
output [5:0] sram_raddr_b1,
output [5:0] sram_raddr_b2,
output [5:0] sram_raddr_b3,

output [10:0] sram_raddr_weight,       //read address from SRAM weight  
output [6:0] sram_raddr_bias,          //read address from SRAM bias 

output busy,
output test_layer_finish,
output valid,                         //output valid to check the final answer (after POOL)

//write enable for SRAM groups A & B
output sram_wen_a0,
output sram_wen_a1,
output sram_wen_a2,
output sram_wen_a3,
output sram_wen_b0,
output sram_wen_b1,
output sram_wen_b2,
output sram_wen_b3,

//bytemask for SRAM groups A & B
output [CH_NUM*ACT_PER_ADDR-1:0] sram_bytemask_a,
output [CH_NUM*ACT_PER_ADDR-1:0] sram_bytemask_b,

//write addrress to SRAM groups A & B
output [5:0] sram_waddr_a,
output [5:0] sram_waddr_b,

//write data to SRAM groups A & B
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a,
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_b
);

wire unshuffle_valid;
reg lvalid;
assign valid = lvalid;
reg unsh_n_sram_wen_a0;
reg unsh_n_sram_wen_a1;
reg unsh_n_sram_wen_a2;
reg unsh_n_sram_wen_a3;
reg [CH_NUM*ACT_PER_ADDR-1:0] l_sram_bytemask_a, nl_sram_bytemask_a;
wire [CH_NUM*ACT_PER_ADDR-1:0] unsh_n_sram_bytemask_a;
reg [5:0] l_sram_waddr_a, nl_sram_waddr_a;
wire [5:0] unsh_n_sram_waddr_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] l_sram_wdata_a, nl_sram_wdata_a;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] unsh_n_sram_wdata_a;
localparam IDLE=3'd0, UNSHUFFLE=3'd1, CONV1=3'd2, END=3'd7;
reg [2:0] state, nstate;
reg [3:0] l_sram_wen, nl_sram_wen;
wire [3:0] unshuffle_nl_sram_wen;
assign sram_wen_a0 = l_sram_wen[0];
assign sram_wen_a1 = l_sram_wen[1];
assign sram_wen_a2 = l_sram_wen[2];
assign sram_wen_a3 = l_sram_wen[3];

assign sram_bytemask_a = l_sram_bytemask_a;
assign sram_waddr_a = l_sram_waddr_a;
assign sram_wdata_a = l_sram_wdata_a;

always @* begin 
    nl_sram_wen = l_sram_wen;
    if(state <= UNSHUFFLE ) begin 
        nl_sram_wen = unshuffle_nl_sram_wen;
    end 

    nl_sram_bytemask_a = l_sram_bytemask_a;
    if(state <= UNSHUFFLE) begin 
        nl_sram_bytemask_a = unsh_n_sram_bytemask_a;
    end 
    nl_sram_waddr_a = l_sram_waddr_a;
    if(state <= UNSHUFFLE) begin 
        nl_sram_waddr_a = unsh_n_sram_waddr_a;
    end 
    nl_sram_wdata_a = l_sram_wdata_a;
    if(state <= UNSHUFFLE) begin 
        nl_sram_wdata_a = unsh_n_sram_wdata_a;
    end 
end 


Unshuffle #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT)
)
myUnshuffle (
.clk(clk),                           //clock input
.rst_n(rst_n),                         //synchronous reset (active low)
.enable(enable),
.input_data(input_data),    //input image
// output 
.busy(busy),
.valid(unshuffle_valid),    
.n_sram_wen(unshuffle_nl_sram_wen),
.n_sram_bytemask_a(unsh_n_sram_bytemask_a),
.n_sram_waddr_a(unsh_n_sram_waddr_a),
.n_sram_wdata_a(unsh_n_sram_wdata_a)
);


always @(posedge clk) begin 
    if(!rst_n) begin 
        l_sram_wen <= 4'b0;
        l_sram_bytemask_a <= {CH_NUM*ACT_PER_ADDR{1'b1}};
        l_sram_waddr_a <= 0;
        l_sram_wdata_a <= 0;
        state <= IDLE;
        lvalid <= 0;
    end else begin 
        l_sram_wen <= nl_sram_wen;
        l_sram_bytemask_a <= nl_sram_bytemask_a;
        l_sram_waddr_a <= nl_sram_waddr_a;
        l_sram_wdata_a <= nl_sram_wdata_a;
        state <= nstate;
        if(state == END)
            lvalid <= 1;
    end 
end 
always @* begin 
    if(!enable) begin 
        nstate = IDLE;
    end else begin 
        case(state)
            IDLE: nstate = UNSHUFFLE;
            UNSHUFFLE: nstate = (unshuffle_valid == 1) ? END : UNSHUFFLE;
            END: nstate = END;
            default: nstate = IDLE;
        endcase
    end 
end 



endmodule