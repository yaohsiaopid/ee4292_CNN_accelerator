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
wire conv1_valid, conv2_valid, conv3_valid;
reg lvalid;
assign valid = lvalid;
reg unsh_n_sram_wen_a0;
reg unsh_n_sram_wen_a1;
reg unsh_n_sram_wen_a2;
reg unsh_n_sram_wen_a3;
reg [CH_NUM*ACT_PER_ADDR-1:0] l_sram_bytemask_a, nl_sram_bytemask_a;
reg [CH_NUM*ACT_PER_ADDR-1:0] l_sram_bytemask_b, nl_sram_bytemask_b;
wire [CH_NUM*ACT_PER_ADDR-1:0] unsh_n_sram_bytemask_a;
reg [5:0] l_sram_waddr_a, nl_sram_waddr_a;
reg [5:0] l_sram_waddr_b, nl_sram_waddr_b;
wire [5:0] unsh_n_sram_waddr_a, conv2_n_sram_waddr_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] l_sram_wdata_a, nl_sram_wdata_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] l_sram_wdata_b, nl_sram_wdata_b;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] unsh_n_sram_wdata_a;
localparam IDLE=3'd0, UNSHUFFLE=3'd1, CONV1=3'd2, CONV2=3'd3, CONV3=3'd4, END=3'd7;
reg [2:0] state, nstate;
reg [3:0] l_sram_a_wen, nl_sram_a_wen;
reg [3:0] l_sram_b_wen, nl_sram_b_wen;
wire [3:0] unshuffle_nl_sram_wen;
wire [3:0] conv1_nl_sram_wen, conv2_nl_sram_wen, conv3_nl_sram_wen;
wire [5:0] conv1_n_sram_raddr_a0, conv1_n_sram_raddr_a1, conv1_n_sram_raddr_a2, conv1_n_sram_raddr_a3;
wire [5:0] conv3_n_sram_raddr_a0, conv3_n_sram_raddr_a1, conv3_n_sram_raddr_a2, conv3_n_sram_raddr_a3;
wire [5:0] conv2_n_sram_raddr_b0, conv2_n_sram_raddr_b1, conv2_n_sram_raddr_b2, conv2_n_sram_raddr_b3;
reg [5:0] n_sram_raddr_a0, n_sram_raddr_a1, n_sram_raddr_a2, n_sram_raddr_a3;
reg [5:0] n_sram_raddr_b0, n_sram_raddr_b1, n_sram_raddr_b2, n_sram_raddr_b3;
reg [5:0] lsram_raddr_a0, lsram_raddr_a1, lsram_raddr_a2, lsram_raddr_a3;
reg [5:0] lsram_raddr_b0, lsram_raddr_b1, lsram_raddr_b2, lsram_raddr_b3;
reg [10:0] lsram_raddr_weight, nsram_raddr_weight;
reg [6:0] lraddr_bias, nraddr_bias;
wire [10:0] shuffle_n_raddr_weight, conv1_n_raddr_weight, conv2_n_raddr_weight, conv3_n_raddr_weight;
wire [6:0] shuffle_n_raddr_bias, conv1_n_raddr_bias, conv2_n_raddr_bias, conv3_n_raddr_bias;
wire shuffle_wr_b, shuffle_wr_w, conv1_wr_w, conv1_wr_b, conv2_wr_w, conv2_wr_b, conv3_wr_w, conv3_wr_b;
assign sram_raddr_weight = lsram_raddr_weight;
assign sram_raddr_bias = lraddr_bias;

reg wr_w, wr_b;

wire [CH_NUM*ACT_PER_ADDR-1:0] conv1_n_sram_bytemask_b, conv2_n_sram_bytemask_a, conv3_n_sram_bytemask_b;
wire [5:0] conv1_n_sram_waddr_b, conv3_n_sram_waddr_b;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] conv1_n_sram_wdata_b, conv2_n_sram_wdata_a, conv3_n_sram_wdata_b;

wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] conv1_n_tmp_a0, conv2_n_tmp_b0, conv3_n_tmp_a0;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] conv1_n_tmp_a1, conv2_n_tmp_b1, conv3_n_tmp_a1;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] conv1_n_tmp_a2, conv2_n_tmp_b2, conv3_n_tmp_a2;
wire [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] conv1_n_tmp_a3, conv2_n_tmp_b3, conv3_n_tmp_a3;

wire pong, wr_pong_w;
wire [1:0] conv3_ctl;
wire conv3_reset;
wire cache_valid;
assign sram_raddr_a0 = lsram_raddr_a0;  assign sram_wen_a0 = l_sram_a_wen[0];
assign sram_raddr_a1 = lsram_raddr_a1;  assign sram_wen_a1 = l_sram_a_wen[1];
assign sram_raddr_a2 = lsram_raddr_a2;  assign sram_wen_a2 = l_sram_a_wen[2];
assign sram_raddr_a3 = lsram_raddr_a3;  assign sram_wen_a3 = l_sram_a_wen[3];

assign sram_raddr_b0 = lsram_raddr_b0;  assign sram_wen_b0 = l_sram_b_wen[0];
assign sram_raddr_b1 = lsram_raddr_b1;  assign sram_wen_b1 = l_sram_b_wen[1];
assign sram_raddr_b2 = lsram_raddr_b2;  assign sram_wen_b2 = l_sram_b_wen[2];
assign sram_raddr_b3 = lsram_raddr_b3;  assign sram_wen_b3 = l_sram_b_wen[3];

assign sram_bytemask_a = l_sram_bytemask_a;
assign sram_bytemask_b = l_sram_bytemask_b;
assign sram_waddr_a = l_sram_waddr_a;
assign sram_waddr_b = l_sram_waddr_b;
assign sram_wdata_a = l_sram_wdata_a;
assign sram_wdata_b = l_sram_wdata_b;

assign test_layer_finish = (state == END);
always @* begin 
    n_sram_raddr_a0 = lsram_raddr_a0;
    n_sram_raddr_a1 = lsram_raddr_a1;
    n_sram_raddr_a2 = lsram_raddr_a2;
    n_sram_raddr_a3 = lsram_raddr_a3;
    if(state == CONV1) begin 
        n_sram_raddr_a0 = conv1_n_sram_raddr_a0;
        n_sram_raddr_a1 = conv1_n_sram_raddr_a1;
        n_sram_raddr_a2 = conv1_n_sram_raddr_a2;
        n_sram_raddr_a3 = conv1_n_sram_raddr_a3;
    end else if(state == CONV3) begin 
        n_sram_raddr_a0 = conv3_n_sram_raddr_a0;
        n_sram_raddr_a1 = conv3_n_sram_raddr_a1;
        n_sram_raddr_a2 = conv3_n_sram_raddr_a2;
        n_sram_raddr_a3 = conv3_n_sram_raddr_a3;
    end

    n_sram_raddr_b0 = lsram_raddr_b0;
    n_sram_raddr_b1 = lsram_raddr_b1;
    n_sram_raddr_b2 = lsram_raddr_b2;
    n_sram_raddr_b3 = lsram_raddr_b3;
    if(state == CONV2) begin 
        n_sram_raddr_b0 = conv2_n_sram_raddr_b0;
        n_sram_raddr_b1 = conv2_n_sram_raddr_b1;
        n_sram_raddr_b2 = conv2_n_sram_raddr_b2;
        n_sram_raddr_b3 = conv2_n_sram_raddr_b3;
    end 

    nl_sram_a_wen = l_sram_a_wen;
    if(state <= UNSHUFFLE )  
        nl_sram_a_wen = unshuffle_nl_sram_wen;
    else if(state == CONV2)
        nl_sram_a_wen = conv2_nl_sram_wen;

    nl_sram_b_wen = l_sram_b_wen;
    if(state == CONV1)  
        nl_sram_b_wen = conv1_nl_sram_wen;
    else if(state == CONV3)
        nl_sram_b_wen = conv3_nl_sram_wen;

    nl_sram_bytemask_a = l_sram_bytemask_a;
    if(state <= UNSHUFFLE) 
        nl_sram_bytemask_a = unsh_n_sram_bytemask_a;
    else if(state == CONV2)
        nl_sram_bytemask_a = conv2_n_sram_bytemask_a;
    
    nl_sram_bytemask_b = l_sram_bytemask_b;
    if(state == CONV1)  
        nl_sram_bytemask_b = conv1_n_sram_bytemask_b;
    else 
        nl_sram_bytemask_b = conv3_n_sram_bytemask_b;
    
    nl_sram_waddr_a = l_sram_waddr_a;
    if(state <= UNSHUFFLE)  
        nl_sram_waddr_a = unsh_n_sram_waddr_a;
    else if(state == CONV2)
        nl_sram_waddr_a = conv2_n_sram_waddr_a;

    nl_sram_waddr_b = l_sram_waddr_b;
    if(state == CONV1) begin 
        nl_sram_waddr_b = conv1_n_sram_waddr_b;
    end else if(state == CONV3)
        nl_sram_waddr_b = conv3_n_sram_waddr_b;

    nl_sram_wdata_a = l_sram_wdata_a;
    if(state <= UNSHUFFLE) 
        nl_sram_wdata_a = unsh_n_sram_wdata_a;
    else if(state == CONV2)
        nl_sram_wdata_a = conv2_n_sram_wdata_a;

    nl_sram_wdata_b = l_sram_wdata_b;
    if(state == CONV1) begin 
        nl_sram_wdata_b = conv1_n_sram_wdata_b;
    end else if(state == CONV3) begin 
        nl_sram_wdata_b = conv3_n_sram_wdata_b;
    end 
        
    nsram_raddr_weight = lsram_raddr_weight;
    nraddr_bias = lraddr_bias;
    wr_b = 0;
    wr_w = 0;
    if(state == UNSHUFFLE) begin
        nsram_raddr_weight = shuffle_n_raddr_weight;
        nraddr_bias = shuffle_n_raddr_bias;
        wr_b = shuffle_wr_b;
        wr_w = shuffle_wr_w;
    end else if(state == CONV1) begin 
        nsram_raddr_weight = conv1_n_raddr_weight;
        nraddr_bias = conv1_n_raddr_bias;
        wr_b = conv1_wr_b;
        wr_w = conv1_wr_w;
    end else if(state == CONV2) begin 
        nsram_raddr_weight = conv2_n_raddr_weight;
        nraddr_bias = conv2_n_raddr_bias;
        wr_b = conv2_wr_b;
        wr_w = conv2_wr_w;
    end else if(state == CONV3) begin 
        nsram_raddr_weight = conv3_n_raddr_weight;
        nraddr_bias = conv3_n_raddr_bias;
        wr_b = conv3_wr_b;
        wr_w = conv3_wr_w;
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
.n_sram_wdata_a(unsh_n_sram_wdata_a),

.n_raddr_weight(shuffle_n_raddr_weight),
.n_raddr_bias(shuffle_n_raddr_bias),
.wr_w(shuffle_wr_w),
.wr_b(shuffle_wr_b)
);

integer chi, chj;
always @(posedge clk) begin 
    if(!rst_n) begin 
        l_sram_a_wen <= 4'b1111;
        l_sram_b_wen <= 4'b1111;
        l_sram_bytemask_a <= {CH_NUM*ACT_PER_ADDR{1'b1}};
        l_sram_waddr_a <= 0;
        l_sram_wdata_a <= 0;
        state <= IDLE;
        lvalid <= 0;
        lsram_raddr_a0 <= 0;         lsram_raddr_b0 <= 0;
        lsram_raddr_a1 <= 0;         lsram_raddr_b1 <= 0;
        lsram_raddr_a2 <= 0;         lsram_raddr_b2 <= 0;
        lsram_raddr_a3 <= 0;         lsram_raddr_b3 <= 0;
        lsram_raddr_weight <= 0;
        lraddr_bias <= 0;
    end else begin 
        lsram_raddr_a0 <= n_sram_raddr_a0; lsram_raddr_b0 <= n_sram_raddr_b0;
        lsram_raddr_a1 <= n_sram_raddr_a1; lsram_raddr_b1 <= n_sram_raddr_b1;
        lsram_raddr_a2 <= n_sram_raddr_a2; lsram_raddr_b2 <= n_sram_raddr_b2;
        lsram_raddr_a3 <= n_sram_raddr_a3; lsram_raddr_b3 <= n_sram_raddr_b3;
        
        l_sram_a_wen <= nl_sram_a_wen;
        l_sram_b_wen <= nl_sram_b_wen;
        l_sram_bytemask_a <= nl_sram_bytemask_a;
        l_sram_bytemask_b <= nl_sram_bytemask_b;
        l_sram_waddr_a <= nl_sram_waddr_a;
        l_sram_waddr_b <= nl_sram_waddr_b;
        l_sram_wdata_a <= nl_sram_wdata_a;
        l_sram_wdata_b <= nl_sram_wdata_b;
        
        state <= nstate;
        if(state == END)
            lvalid <= 1;

        lsram_raddr_weight <= nsram_raddr_weight;
        lraddr_bias <= nraddr_bias;

    end 
end 
always @* begin 
    if(!enable) begin 
        nstate = IDLE;
    end else begin 
        case(state)
            IDLE: nstate = UNSHUFFLE;
            UNSHUFFLE: nstate = (unshuffle_valid == 1) ? CONV1 : UNSHUFFLE;
            CONV1: nstate = (conv1_valid == 1) ? CONV2 : CONV1;
            CONV2: nstate = (conv2_valid == 1) ? CONV3 : CONV2;
            CONV3: nstate = (conv3_valid == 1) ? END : CONV3;
            END: nstate = END;
            default: nstate = IDLE;
        endcase
    end 
end 

reg [BW_PER_ACT-1:0] pipe3_c0;
reg [BW_PER_ACT-1:0] pipe3_c1;
reg [BW_PER_ACT-1:0] pipe3_c2;
reg [BW_PER_ACT-1:0] pipe3_c3;
reg [BW_PER_ACT-1:0] max_pool, n_maxpool;
Conv1 #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT),
.BW_PER_PARAM(BW_PER_PARAM)
)
myconv1(
.clk(clk),                       
.rst_n(rst_n),                     
.enable(state == CONV1),
.sram_rdata_a0(sram_rdata_a0),
.sram_rdata_a1(sram_rdata_a1),
.sram_rdata_a2(sram_rdata_a2),
.sram_rdata_a3(sram_rdata_a3),
.pipe3_c0(pipe3_c0),
.pipe3_c1(pipe3_c1),
.pipe3_c2(pipe3_c2),
.pipe3_c3(pipe3_c3),
// output 
.valid(conv1_valid),             
.n_sram_raddr_a0(conv1_n_sram_raddr_a0),
.n_sram_raddr_a1(conv1_n_sram_raddr_a1),
.n_sram_raddr_a2(conv1_n_sram_raddr_a2),
.n_sram_raddr_a3(conv1_n_sram_raddr_a3),
//bytemask for SRAM group B
.n_sram_bytemask_b(conv1_n_sram_bytemask_b),
// write addrress to SRAM group B
.n_sram_waddr_b(conv1_n_sram_waddr_b),
// write data to SRAM group B
.n_sram_wdata_b(conv1_n_sram_wdata_b),
.n_sram_wen(conv1_nl_sram_wen),
.n_tmp_a0(conv1_n_tmp_a0),
.n_tmp_a1(conv1_n_tmp_a1),
.n_tmp_a2(conv1_n_tmp_a2),
.n_tmp_a3(conv1_n_tmp_a3),
.n_raddr_weight(conv1_n_raddr_weight),
.n_raddr_bias(conv1_n_raddr_bias),
.wr_w(conv1_wr_b),
.wr_b(conv1_wr_w)
);

Conv2 #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT),
.BW_PER_PARAM(BW_PER_PARAM)
)
myconv2(
.clk(clk),                       
.rst_n(rst_n),                     
.enable(state == CONV2),
.sram_rdata_b0(sram_rdata_b0),
.sram_rdata_b1(sram_rdata_b1),
.sram_rdata_b2(sram_rdata_b2),
.sram_rdata_b3(sram_rdata_b3),
.pipe3_c0(pipe3_c0),
.pipe3_c1(pipe3_c1),
.pipe3_c2(pipe3_c2),
.pipe3_c3(pipe3_c3),
// output 
.valid(conv2_valid),             
.n_sram_raddr_b0(conv2_n_sram_raddr_b0),
.n_sram_raddr_b1(conv2_n_sram_raddr_b1),
.n_sram_raddr_b2(conv2_n_sram_raddr_b2),
.n_sram_raddr_b3(conv2_n_sram_raddr_b3),
//bytemask for SRAM group B
.n_sram_bytemask_a(conv2_n_sram_bytemask_a),
// write addrress to SRAM group B
.n_sram_waddr_a(conv2_n_sram_waddr_a),
// write data to SRAM group B
.n_sram_wdata_a(conv2_n_sram_wdata_a),
.n_sram_wen(conv2_nl_sram_wen),
.n_tmp_b0(conv2_n_tmp_b0),
.n_tmp_b1(conv2_n_tmp_b1),
.n_tmp_b2(conv2_n_tmp_b2),
.n_tmp_b3(conv2_n_tmp_b3),
.n_raddr_weight(conv2_n_raddr_weight),
.n_raddr_bias(conv2_n_raddr_bias),
.wr_w(conv2_wr_b),
.wr_b(conv2_wr_w)
);

Conv3 #(
.CH_NUM(CH_NUM),
.ACT_PER_ADDR(ACT_PER_ADDR),
.BW_PER_ACT(BW_PER_ACT),
.BW_PER_PARAM(BW_PER_PARAM)
)
myconv3(
.clk(clk),                       
.rst_n(rst_n),                     
.enable(state == CONV3),
.sram_rdata_a0(sram_rdata_a0),
.sram_rdata_a1(sram_rdata_a1),
.sram_rdata_a2(sram_rdata_a2),
.sram_rdata_a3(sram_rdata_a3),
.pipe3_c0(pipe3_c0),
.pipe3_c1(pipe3_c1),
.pipe3_c2(pipe3_c2),
.pipe3_c3(pipe3_c3),
// output 
.valid(conv3_valid),             
.n_sram_raddr_a0(conv3_n_sram_raddr_a0),
.n_sram_raddr_a1(conv3_n_sram_raddr_a1),
.n_sram_raddr_a2(conv3_n_sram_raddr_a2),
.n_sram_raddr_a3(conv3_n_sram_raddr_a3),
//bytemask for SRAM group B
.n_sram_bytemask_b(conv3_n_sram_bytemask_b),
// write addrress to SRAM group B
.n_sram_waddr_b(conv3_n_sram_waddr_b),
// write data to SRAM group B
.n_sram_wdata_b(conv3_n_sram_wdata_b),
.n_sram_wen(conv3_nl_sram_wen),
.n_tmp_a0(conv3_n_tmp_a0),
.n_tmp_a1(conv3_n_tmp_a1),
.n_tmp_a2(conv3_n_tmp_a2),
.n_tmp_a3(conv3_n_tmp_a3),
.n_raddr_weight(conv3_n_raddr_weight),
.n_raddr_bias(conv3_n_raddr_bias),
.wr_w(conv3_wr_w),
.wr_b(conv3_wr_b),
.wr_pong_w(wr_pong_w),
.pong(pong),
.conv3_ctl(conv3_ctl),
.reset(conv3_reset),
.cache_valid(cache_valid)
);



// PEs 
// conv1: 
// ch0 at CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1: 3*ACT_PER_ADDR*BW_PER_ACT
// ch1 at 3*ACT_PER_ADDR*BW_PER_ACT-1: 2*ACT_PER_ADDR*BW_PER_ACT
// ch2 at 2*ACT_PER_ADDR*BW_PER_ACT-1: ACT_PER_ADDR*BW_PER_ACT
// ch3 at ACT_PER_ADDR*BW_PER_ACT-1: 0
reg signed [BW_PER_PARAM-1:0] local_weight[0:WEIGHT_PER_ADDR*CH_NUM-1];
reg signed [BW_PER_PARAM-1:0] pong_weight[0:WEIGHT_PER_ADDR*CH_NUM-1];
reg signed [BW_PER_PARAM-1:0] choose_weight[0:WEIGHT_PER_ADDR*CH_NUM-1];
reg signed [BW_PER_PARAM-1:0] local_bias;//[0:BIAS_PER_ADDR*CH_NUM-1];
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_a0,n_tmp_a1,n_tmp_a2,n_tmp_a3;
reg signed [BW_PER_ACT-1:0] tmp_rdata_a0[0:CH_NUM*ACT_PER_ADDR-1];
reg signed [BW_PER_ACT-1:0] tmp_rdata_a1[0:CH_NUM*ACT_PER_ADDR-1];
reg signed [BW_PER_ACT-1:0] tmp_rdata_a2[0:CH_NUM*ACT_PER_ADDR-1];
reg signed [BW_PER_ACT-1:0] tmp_rdata_a3[0:CH_NUM*ACT_PER_ADDR-1];
reg signed [BW_PER_ACT-1:0] tmp_c0[0:WEIGHT_PER_ADDR*CH_NUM-1],tmp_c1[0:WEIGHT_PER_ADDR*CH_NUM-1], tmp_c2[0:WEIGHT_PER_ADDR*CH_NUM-1],tmp_c3[0:WEIGHT_PER_ADDR*CH_NUM-1];
reg signed [BW_PER_ACT+BW_PER_PARAM:0] pipe1_c0[0:12-1], nmul_c0[0:12-1]; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM:0] pipe1_c1[0:12-1], nmul_c1[0:12-1]; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM:0] pipe1_c2[0:12-1], nmul_c2[0:12-1]; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM:0] pipe1_c3[0:12-1], nmul_c3[0:12-1]; //3 * 4 - 1

reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] pipe2_c0, nmul2_c0; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] pipe2_c1, nmul2_c1; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] pipe2_c2, nmul2_c2; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] pipe2_c3, nmul2_c3; //3 * 4 - 1
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] act0, act1, act2, act3;
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0]  nmul3_c0, nmul3_1_c0, nmul3_2_c0;
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0]  nmul3_c1, nmul3_1_c1, nmul3_2_c1;
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0]  nmul3_c2, nmul3_1_c2, nmul3_2_c2;
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0]  nmul3_c3, nmul3_1_c3, nmul3_2_c3;

reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] cache0[0:3], cache1[0:3], cache2[0:3], cache3[0:3];
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] ncache[0:3];
integer cache_i;
always @* begin 
    n_tmp_a0 = 0;
    n_tmp_a1 = 0;
    n_tmp_a2 = 0;
    n_tmp_a3 = 0;
    if(state == CONV1 || state == UNSHUFFLE) begin 
        n_tmp_a0 = conv1_n_tmp_a0;
        n_tmp_a1 = conv1_n_tmp_a1;
        n_tmp_a2 = conv1_n_tmp_a2;
        n_tmp_a3 = conv1_n_tmp_a3;
    end else if(state == CONV2) begin 
        n_tmp_a0 = conv2_n_tmp_b0;
        n_tmp_a1 = conv2_n_tmp_b1;
        n_tmp_a2 = conv2_n_tmp_b2;
        n_tmp_a3 = conv2_n_tmp_b3;  
    end else if(state == CONV3) begin 
        n_tmp_a0 = conv3_n_tmp_a0;
        n_tmp_a1 = conv3_n_tmp_a1;
        n_tmp_a2 = conv3_n_tmp_a2;
        n_tmp_a3 = conv3_n_tmp_a3;
    end 
end 
integer wi, i, j, maci, cci;
always @(posedge clk) begin 
    if(!rst_n) begin 
        for(i = 0; i < 16; i = i + 1) begin 
            tmp_rdata_a0[i] <= 0; tmp_rdata_a1[i] <= 0; tmp_rdata_a2[i] <= 0; tmp_rdata_a3[i] <= 0;
        end     
        for(maci = 0; maci < 12; maci = maci + 1) begin
            pipe1_c0[maci] <= 0;  pipe1_c1[maci] <= 0;  pipe1_c2[maci] <= 0;  pipe1_c3[maci] <= 0;
        end 
        pipe2_c0 <= 0;  pipe2_c1 <= 0;   pipe2_c2 <= 0;    pipe2_c3 <= 0;
        pipe3_c0 <= 0;   pipe3_c1 <= 0;   pipe3_c2 <= 0;   pipe3_c3 <= 0;
        max_pool <= 0;
        for(cci = 0; cci < 4; cci = cci + 1) begin 
        cache0[cci] <= 0; cache1[cci] <= 0; cache2[cci] <= 0; cache3[cci] <= 0;
        end 
    end else begin 
        if(wr_w == 1) begin 
            // $display("wr: %d", sram_raddr_weight);
            local_weight[0] <= local_weight[9] ;  local_weight[9] <=  local_weight[18]; local_weight[18] <= local_weight[27]; 
            local_weight[1] <= local_weight[10];  local_weight[10] <= local_weight[19]; local_weight[19] <= local_weight[28]; 
            local_weight[2] <= local_weight[11];  local_weight[11] <= local_weight[20]; local_weight[20] <= local_weight[29]; 
            local_weight[3] <= local_weight[12];  local_weight[12] <= local_weight[21]; local_weight[21] <= local_weight[30]; 
            local_weight[4] <= local_weight[13];  local_weight[13] <= local_weight[22]; local_weight[22] <= local_weight[31]; 
            local_weight[5] <= local_weight[14];  local_weight[14] <= local_weight[23]; local_weight[23] <= local_weight[32]; 
            local_weight[6] <= local_weight[15];  local_weight[15] <= local_weight[24]; local_weight[24] <= local_weight[33]; 
            local_weight[7] <= local_weight[16];  local_weight[16] <= local_weight[25]; local_weight[25] <= local_weight[34]; 
            local_weight[8] <= local_weight[17];  local_weight[17] <= local_weight[26]; local_weight[26] <= local_weight[35]; 
            local_weight[27] <= sram_rdata_weight[BW_PER_PARAM*9-1:BW_PER_PARAM*8];
            local_weight[28] <= sram_rdata_weight[BW_PER_PARAM*8-1:BW_PER_PARAM*7];
            local_weight[29] <= sram_rdata_weight[BW_PER_PARAM*7-1:BW_PER_PARAM*6];
            local_weight[30] <= sram_rdata_weight[BW_PER_PARAM*6-1:BW_PER_PARAM*5];
            local_weight[31] <= sram_rdata_weight[BW_PER_PARAM*5-1:BW_PER_PARAM*4];
            local_weight[32] <= sram_rdata_weight[BW_PER_PARAM*4-1:BW_PER_PARAM*3];
            local_weight[33] <= sram_rdata_weight[BW_PER_PARAM*3-1:BW_PER_PARAM*2];
            local_weight[34] <= sram_rdata_weight[BW_PER_PARAM*2-1:BW_PER_PARAM*1];
            local_weight[35] <= sram_rdata_weight[BW_PER_PARAM*1-1:BW_PER_PARAM*0];
        end 
        if(wr_b == 1) begin 
            local_bias <= sram_rdata_bias;
        end 
        if(wr_pong_w == 1) begin 
            pong_weight[0] <= pong_weight[9] ;  pong_weight[9] <=  pong_weight[18]; pong_weight[18] <= pong_weight[27]; 
            pong_weight[1] <= pong_weight[10];  pong_weight[10] <= pong_weight[19]; pong_weight[19] <= pong_weight[28]; 
            pong_weight[2] <= pong_weight[11];  pong_weight[11] <= pong_weight[20]; pong_weight[20] <= pong_weight[29]; 
            pong_weight[3] <= pong_weight[12];  pong_weight[12] <= pong_weight[21]; pong_weight[21] <= pong_weight[30]; 
            pong_weight[4] <= pong_weight[13];  pong_weight[13] <= pong_weight[22]; pong_weight[22] <= pong_weight[31]; 
            pong_weight[5] <= pong_weight[14];  pong_weight[14] <= pong_weight[23]; pong_weight[23] <= pong_weight[32]; 
            pong_weight[6] <= pong_weight[15];  pong_weight[15] <= pong_weight[24]; pong_weight[24] <= pong_weight[33]; 
            pong_weight[7] <= pong_weight[16];  pong_weight[16] <= pong_weight[25]; pong_weight[25] <= pong_weight[34]; 
            pong_weight[8] <= pong_weight[17];  pong_weight[17] <= pong_weight[26]; pong_weight[26] <= pong_weight[35]; 
            pong_weight[27] <= sram_rdata_weight[BW_PER_PARAM*9-1:BW_PER_PARAM*8];
            pong_weight[28] <= sram_rdata_weight[BW_PER_PARAM*8-1:BW_PER_PARAM*7];
            pong_weight[29] <= sram_rdata_weight[BW_PER_PARAM*7-1:BW_PER_PARAM*6];
            pong_weight[30] <= sram_rdata_weight[BW_PER_PARAM*6-1:BW_PER_PARAM*5];
            pong_weight[31] <= sram_rdata_weight[BW_PER_PARAM*5-1:BW_PER_PARAM*4];
            pong_weight[32] <= sram_rdata_weight[BW_PER_PARAM*4-1:BW_PER_PARAM*3];
            pong_weight[33] <= sram_rdata_weight[BW_PER_PARAM*3-1:BW_PER_PARAM*2];
            pong_weight[34] <= sram_rdata_weight[BW_PER_PARAM*2-1:BW_PER_PARAM*1];
            pong_weight[35] <= sram_rdata_weight[BW_PER_PARAM*1-1:BW_PER_PARAM*0];
        end 
        // for(j = 0; j < CH_NUM; j = j + 1) begin 
        //     for(i = 0; i < ACT_PER_ADDR; i = i + 1) begin 
        //         tmp_rdata_a0[4*j+i] <= n_tmp_a0[(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-1-i*BW_PER_ACT:(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-(i+1)*BW_PER_ACT]; 
        //         tmp_rdata_a1[4*j+i] <= n_tmp_a1[(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-1-i*BW_PER_ACT:(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-(i+1)*BW_PER_ACT]; 
        //         tmp_rdata_a2[4*j+i] <= n_tmp_a2[(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-1-i*BW_PER_ACT:(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-(i+1)*BW_PER_ACT]; 
        //         tmp_rdata_a3[4*j+i] <= n_tmp_a3[(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-1-i*BW_PER_ACT:(CH_NUM-j)*ACT_PER_ADDR*BW_PER_ACT-(i+1)*BW_PER_ACT]; 
        //     end 
        // end 
        tmp_rdata_a1[0] <=   n_tmp_a1[127:120];      tmp_rdata_a0[0] <=   n_tmp_a0[127:120];
        tmp_rdata_a1[1] <=   n_tmp_a1[119:112];      tmp_rdata_a0[1] <=   n_tmp_a0[119:112];
        tmp_rdata_a1[2] <=   n_tmp_a1[111:104];      tmp_rdata_a0[2] <=   n_tmp_a0[111:104];
        tmp_rdata_a1[3] <=   n_tmp_a1[103:96];       tmp_rdata_a0[3] <=   n_tmp_a0[103:96];
        tmp_rdata_a1[4] <=   n_tmp_a1[95:88];        tmp_rdata_a0[4] <=   n_tmp_a0[95:88];
        tmp_rdata_a1[5] <=   n_tmp_a1[87:80];        tmp_rdata_a0[5] <=   n_tmp_a0[87:80];
        tmp_rdata_a1[6] <=   n_tmp_a1[79:72];        tmp_rdata_a0[6] <=   n_tmp_a0[79:72];
        tmp_rdata_a1[7] <=   n_tmp_a1[71:64];        tmp_rdata_a0[7] <=   n_tmp_a0[71:64];
        tmp_rdata_a1[8] <=   n_tmp_a1[63:56];        tmp_rdata_a0[8] <=   n_tmp_a0[63:56];
        tmp_rdata_a1[9] <=   n_tmp_a1[55:48];        tmp_rdata_a0[9] <=   n_tmp_a0[55:48];
        tmp_rdata_a1[10] <=  n_tmp_a1[47:40];        tmp_rdata_a0[10] <=  n_tmp_a0[47:40];
        tmp_rdata_a1[11] <=  n_tmp_a1[39:32];        tmp_rdata_a0[11] <=  n_tmp_a0[39:32];
        tmp_rdata_a1[12] <=  n_tmp_a1[31:24];        tmp_rdata_a0[12] <=  n_tmp_a0[31:24];
        tmp_rdata_a1[13] <=  n_tmp_a1[23:16];        tmp_rdata_a0[13] <=  n_tmp_a0[23:16];
        tmp_rdata_a1[14] <=  n_tmp_a1[15:8];         tmp_rdata_a0[14] <=  n_tmp_a0[15:8];
        tmp_rdata_a1[15] <=  n_tmp_a1[7:0];          tmp_rdata_a0[15] <=  n_tmp_a0[7:0];

        tmp_rdata_a3[0] <=   n_tmp_a3[127:120];      tmp_rdata_a2[0] <=   n_tmp_a2[127:120];
        tmp_rdata_a3[1] <=   n_tmp_a3[119:112];      tmp_rdata_a2[1] <=   n_tmp_a2[119:112];
        tmp_rdata_a3[2] <=   n_tmp_a3[111:104];      tmp_rdata_a2[2] <=   n_tmp_a2[111:104];
        tmp_rdata_a3[3] <=   n_tmp_a3[103:96];       tmp_rdata_a2[3] <=   n_tmp_a2[103:96];
        tmp_rdata_a3[4] <=   n_tmp_a3[95:88];        tmp_rdata_a2[4] <=   n_tmp_a2[95:88];
        tmp_rdata_a3[5] <=   n_tmp_a3[87:80];        tmp_rdata_a2[5] <=   n_tmp_a2[87:80];
        tmp_rdata_a3[6] <=   n_tmp_a3[79:72];        tmp_rdata_a2[6] <=   n_tmp_a2[79:72];
        tmp_rdata_a3[7] <=   n_tmp_a3[71:64];        tmp_rdata_a2[7] <=   n_tmp_a2[71:64];
        tmp_rdata_a3[8] <=   n_tmp_a3[63:56];        tmp_rdata_a2[8] <=   n_tmp_a2[63:56];
        tmp_rdata_a3[9] <=   n_tmp_a3[55:48];        tmp_rdata_a2[9] <=   n_tmp_a2[55:48];
        tmp_rdata_a3[10] <=  n_tmp_a3[47:40];        tmp_rdata_a2[10] <=  n_tmp_a2[47:40];
        tmp_rdata_a3[11] <=  n_tmp_a3[39:32];        tmp_rdata_a2[11] <=  n_tmp_a2[39:32];
        tmp_rdata_a3[12] <=  n_tmp_a3[31:24];        tmp_rdata_a2[12] <=  n_tmp_a2[31:24];
        tmp_rdata_a3[13] <=  n_tmp_a3[23:16];        tmp_rdata_a2[13] <=  n_tmp_a2[23:16];
        tmp_rdata_a3[14] <=  n_tmp_a3[15:8];         tmp_rdata_a2[14] <=  n_tmp_a2[15:8];
        tmp_rdata_a3[15] <=  n_tmp_a3[7:0];          tmp_rdata_a2[15] <=  n_tmp_a2[7:0];

        for(maci = 0; maci < 12; maci = maci + 1) begin
            pipe1_c0[maci] <= nmul_c0[maci];
            pipe1_c1[maci] <= nmul_c1[maci];
            pipe1_c2[maci] <= nmul_c2[maci];
            pipe1_c3[maci] <= nmul_c3[maci];
        end 
        
        if(cache_valid) begin 
        (* synthesis, parallel_case *)
        case(conv3_ctl) 
            2'b01: begin 
            cache0[0] <= cache0[0] + nmul2_c0;
            cache0[1] <= cache0[1] + nmul2_c1;
            cache0[2] <= cache0[2] + nmul2_c2;
            cache0[3] <= cache0[3] + nmul2_c3;
            if(conv3_reset == 1) begin 
                cache3[0] <= 0; cache3[1] <= 0;  cache3[2] <= 0;   cache3[3] <= 0;
            end 
            end 
            2'b10: begin 
            cache1[0] <= cache1[0] + nmul2_c0;
            cache1[1] <= cache1[1] + nmul2_c1;
            cache1[2] <= cache1[2] + nmul2_c2;
            cache1[3] <= cache1[3] + nmul2_c3;
            if(conv3_reset == 1) begin 
                cache0[0] <= 0; cache0[1] <= 0;  cache0[2] <= 0;   cache0[3] <= 0;
            end 
             end 
            2'b11: begin 
            cache2[0] <= cache2[0] + nmul2_c0;
            cache2[1] <= cache2[1] + nmul2_c1;
            cache2[2] <= cache2[2] + nmul2_c2;
            cache2[3] <= cache2[3] + nmul2_c3;
            if(conv3_reset == 1) begin 
                cache1[0] <= 0; cache1[1] <= 0;  cache1[2] <= 0;   cache1[3] <= 0;
            end 
             end 
            2'b00: begin 
            cache3[0] <= cache3[0] + nmul2_c0;
            cache3[1] <= cache3[1] + nmul2_c1;
            cache3[2] <= cache3[2] + nmul2_c2;
            cache3[3] <= cache3[3] + nmul2_c3;
            if(conv3_reset == 1) begin 
                cache2[0] <= 0; cache2[1] <= 0;  cache2[2] <= 0;   cache2[3] <= 0;
            end 
            end 
        endcase 
        end
        pipe2_c0 <= nmul2_c0; pipe3_c0 <= nmul3_2_c0[7:0];   
        pipe2_c1 <= nmul2_c1; pipe3_c1 <= nmul3_2_c1[7:0];  
        pipe2_c2 <= nmul2_c2; pipe3_c2 <= nmul3_2_c2[7:0]; 
        pipe2_c3 <= nmul2_c3; pipe3_c3 <= nmul3_2_c3[7:0];

        max_pool <= n_maxpool;
        if(state == CONV3) begin 
            if(myconv3.state == 2) begin  //ACT
                // $display("%h", sram_rdata_weight);
                // $display("%b bias %d; %b %b %b rch: %d row: %d col: %d w_stat: %d caddr: %d waddr: %d ",
                // wr_b, sram_raddr_bias, pong,wr_w, wr_pong_w, myconv3.r_ch, myconv3.row, myconv3.col, myconv3.w_stat, sram_raddr_weight, myconv3.l_raddr_weight);
                $display("----\n%d rch: %d row: %d col: %d w_stat: %d caddr: %d waddr: %d raddr: %d %d %d %d ",
                 conv3_ctl, myconv3.r_ch, myconv3.row, myconv3.col, myconv3.w_stat, sram_raddr_weight, myconv3.l_raddr_weight, 
                myconv3.l_sram_raddr_a0, myconv3.l_sram_raddr_a1, myconv3.l_sram_raddr_a2, myconv3.l_sram_raddr_a3);
                
                $display("%h",n_tmp_a0);
                $display("weight");
                for(chi = 0; chi < 4; chi = chi + 1) begin 
                    for(chj = 0; chj < 9; chj = chj + 1) begin 
                        $write("(%d, %d),", choose_weight[chi*9+chj], tmp_c0[chi*9+chj]);
                    end 
                    $write("\n");
                end
                $display("\n%d", local_bias);
                
                for(chi = 0; chi < 4; chi = chi + 1) begin 
                    $display("%d %d %d %d", cache0[chi], cache1[chi], cache2[chi], cache3[chi]);
                end 
                $display("nmul2_c: %d %d %d %d",nmul2_c0, nmul2_c1, nmul2_c2, nmul2_c3);
                $display("act0: %d %d %d %d",act0, act1, act2, act3);
                
                if(myconv3.prev_stat == 3)
                    $write("::");
                    // four result from last ::  to next three !! 
                $display("%d %d %d %d", pipe3_c0,pipe3_c1,pipe3_c2,pipe3_c3);
                
            end 
        end 
        if(state == CONV2) begin 
            // $display("%d", sram_raddr_weight);
            // if(myconv2.tmpcnt == 4) $display("=====================");
            // if(myconv2.state == 1) begin 
            // if(myconv2.row == 4 && myconv2.col >= 3)  begin
            //     $display("tmpcnt %d %d %d", myconv2.tmpcnt, myconv2.wr_w, sram_raddr_weight);
            // end 
            // if(myconv2.row == 0 && myconv2.col < 1)  begin
            //     $display("bias: %d", local_bias);
            //     $display("sweight:::");
            //     for(chi = 0; chi < 4; chi = chi + 1) begin 
            //         for(chj = 0; chj < 9; chj = chj + 1) begin 
            //             $write("%d,", local_weight[chi*9+chj]);
            //         end 
            //         $write("\n");
            //     end
            //     $display("");
            // end
            // if(myconv2.state == 2) begin 
            //     $display("row col: %d %d; %d %d %d %d", myconv2.row, myconv2.col, 
            //     sram_raddr_b0, sram_raddr_b1, sram_raddr_b2, sram_raddr_b3);
            //     // $display(": %h %h",n_tmp_a0, sram_rdata_b0);
            //     // $display(": %h %h",n_tmp_a1, sram_rdata_b1);
            //     // $display(": %h %h",n_tmp_a2, sram_rdata_b2);
            //     // $display(": %h %h",n_tmp_a3, sram_rdata_b3);
            //     $display("%d %d %d %d", pipe3_c0,pipe3_c1,pipe3_c2,pipe3_c3);
            //     $display(";%b, %d, (%d %d)", l_sram_a_wen, myconv2.ch, myconv2.wbrow, myconv2.wbcnt);
            //     $display("addrb: %d mask: %b\ndata: %h",l_sram_waddr_a, l_sram_bytemask_a, l_sram_wdata_a);
            // end
        end 
        // if(state == CONV1) begin 
        //     // DUMPP
        //     // if(myconv1.row == 0 && myconv1.col == 1) begin 
        //     //     $display("weight:::");
        //     //     for(chi = 0; chi < 4; chi = chi + 1) begin 
        //     //         for(chj = 0; chj < 9; chj = chj + 1) begin 
        //     //             $write("%d,", local_weight[chi*9+chj]);
        //     //         end 
        //     //         $write("\n");
        //     //     end
        //     // end 
        //     $display("---------------------");
        //     $display(";%b, %d, (%d %d)", l_sram_b_wen, myconv1.ch, myconv1.wbrow, myconv1.wbcnt);
        //     if(myconv1.row == 0 && myconv1.col <= 3)  begin
        //         $display("==========================="); 
        //         $display("bias: %d", bias_shift);
        //         $display("weight:::");
        //         for(chi = 0; chi < 4; chi = chi + 1) begin 
        //             for(chj = 0; chj < 9; chj = chj + 1) begin 
        //                 $write("%d,", local_weight[chi*9+chj]);
        //             end 
        //             // $write("\n");
        //         end
        //         $display("\n");
        //     end 
        //     $display("%d %d %d %d", pipe3_c0,pipe3_c1,pipe3_c2,pipe3_c3);
        //     // $display("bias: %h", bias_shift);
        //     $display("addrb: %d mask: %b\ndata: %h",l_sram_waddr_b, l_sram_bytemask_b, l_sram_wdata_b);
        //     // $display(",%h", conv1_n_sram_wdata_b);
        //     // $display("- %d:%d:%d:%d", pipe2_c3,nmul3_c3,nmul3_1_c3,pipe2_c3);
            
        //     $display("row col: %d %d; %d %d %d %d", myconv1.row, myconv1.col, sram_raddr_a0, sram_raddr_a1, sram_raddr_a2, sram_raddr_a3);
        //     $display("---------------------");
        //     // $display("nsram addr: %d %d %d %d", myconv1.n_sram_raddr_a0, myconv1.n_sram_raddr_a1, myconv1.n_sram_raddr_a2, myconv1.n_sram_raddr_a3); 
        //     // for(chi = 0; chi < 36; chi = chi + 1) begin 
        //     //     $write("%d,",tmp_c3[chi]);
        //     // end 
        //     // $write("\n----------\n");

        //     // for(chj = 0; chj < 12; chj = chj + 1) begin 
        //     //     $write("%d,", nmul_c3[chj]);
        //     // end 
        //     // $write("\n");
        //     // for(chj = 0; chj < 16; chj = chj + 1) begin 
        //     //     $write("%d,", tmp_rdata_a1[chj]);
        //     // end 
        //     // $write("\n");
        //     // for(chj = 0; chj < 16; chj = chj + 1) begin 
        //     //     $write("%d,", tmp_rdata_a2[chj]);
        //     // end 
        //     // $write("\n");
        //     // for(chj = 0; chj < 16; chj = chj + 1) begin 
        //     //     $write("%d,", tmp_rdata_a3[chj]);
        //     // end 
        //     // $write("\n");
        //     // $display(": %h %h",sram_rdata_a0, n_tmp_a0);
        //     // $display(": %h %h",sram_rdata_a1, n_tmp_a1);
        //     // $display(": %h %h",sram_rdata_a2, n_tmp_a2);
        //     // $display(": %h %h",sram_rdata_a3, n_tmp_a3);
        // end
    end 
end 



// assign tmp_c0 ~ c3
always @* begin 
    //channel 0 3x3
    tmp_c0[0]   = tmp_rdata_a0[0];      tmp_c0[9]   = tmp_rdata_a0[4];
    tmp_c0[1]   = tmp_rdata_a0[1];      tmp_c0[10]  = tmp_rdata_a0[5];
    tmp_c0[2]   = tmp_rdata_a1[0];      tmp_c0[11]  = tmp_rdata_a1[4];
    tmp_c0[3]   = tmp_rdata_a0[2];      tmp_c0[12]  = tmp_rdata_a0[6];
    tmp_c0[4]   = tmp_rdata_a0[3];      tmp_c0[13]  = tmp_rdata_a0[7];
    tmp_c0[5]   = tmp_rdata_a1[2];      tmp_c0[14]  = tmp_rdata_a1[6];
    tmp_c0[6]   = tmp_rdata_a2[0];      tmp_c0[15]  = tmp_rdata_a2[4];
    tmp_c0[7]   = tmp_rdata_a2[1];      tmp_c0[16]  = tmp_rdata_a2[5];
    tmp_c0[8]   = tmp_rdata_a3[0];      tmp_c0[17]  = tmp_rdata_a3[4];

    tmp_c0[18]  = tmp_rdata_a0[8];      tmp_c0[27]  = tmp_rdata_a0[12];
    tmp_c0[19]  = tmp_rdata_a0[9];      tmp_c0[28]  = tmp_rdata_a0[13];
    tmp_c0[20]  = tmp_rdata_a1[8];      tmp_c0[29]  = tmp_rdata_a1[12];
    tmp_c0[21]  = tmp_rdata_a0[10];     tmp_c0[30]  = tmp_rdata_a0[14];
    tmp_c0[22]  = tmp_rdata_a0[11];     tmp_c0[31]  = tmp_rdata_a0[15];
    tmp_c0[23]  = tmp_rdata_a1[10];     tmp_c0[32]  = tmp_rdata_a1[14];
    tmp_c0[24]  = tmp_rdata_a2[8];      tmp_c0[33]  = tmp_rdata_a2[12];
    tmp_c0[25]  = tmp_rdata_a2[9];      tmp_c0[34]  = tmp_rdata_a2[13];
    tmp_c0[26]  = tmp_rdata_a3[8];      tmp_c0[35]  = tmp_rdata_a3[12];
    
    //channel 1
    tmp_c1[0]   = tmp_rdata_a0[1];      tmp_c1[9]   = tmp_rdata_a0[5];
    tmp_c1[1]   = tmp_rdata_a1[0];      tmp_c1[10]  = tmp_rdata_a1[4];
    tmp_c1[2]   = tmp_rdata_a1[1];      tmp_c1[11]  = tmp_rdata_a1[5];
    tmp_c1[3]   = tmp_rdata_a0[3];      tmp_c1[12]  = tmp_rdata_a0[7];
    tmp_c1[4]   = tmp_rdata_a1[2];      tmp_c1[13]  = tmp_rdata_a1[6];
    tmp_c1[5]   = tmp_rdata_a1[3];      tmp_c1[14]  = tmp_rdata_a1[7];
    tmp_c1[6]   = tmp_rdata_a2[1];      tmp_c1[15]  = tmp_rdata_a2[5];
    tmp_c1[7]   = tmp_rdata_a3[0];      tmp_c1[16]  = tmp_rdata_a3[4];
    tmp_c1[8]   = tmp_rdata_a3[1];      tmp_c1[17]  = tmp_rdata_a3[5];

    tmp_c1[18]  = tmp_rdata_a0[9];      tmp_c1[27]  = tmp_rdata_a0[13];
    tmp_c1[19]  = tmp_rdata_a1[8];      tmp_c1[28]  = tmp_rdata_a1[12];
    tmp_c1[20]  = tmp_rdata_a1[9];      tmp_c1[29]  = tmp_rdata_a1[13];
    tmp_c1[21]  = tmp_rdata_a0[11];     tmp_c1[30]  = tmp_rdata_a0[15];
    tmp_c1[22]  = tmp_rdata_a1[10];     tmp_c1[31]  = tmp_rdata_a1[14];
    tmp_c1[23]  = tmp_rdata_a1[11];     tmp_c1[32]  = tmp_rdata_a1[15];
    tmp_c1[24]  = tmp_rdata_a2[9];      tmp_c1[33]  = tmp_rdata_a2[13];
    tmp_c1[25]  = tmp_rdata_a3[8];      tmp_c1[34]  = tmp_rdata_a3[12];
    tmp_c1[26]  = tmp_rdata_a3[9];      tmp_c1[35]  = tmp_rdata_a3[13];
    
    //channel 2
    tmp_c2[0]   = tmp_rdata_a0[2];      tmp_c2[9]   = tmp_rdata_a0[6];
    tmp_c2[1]   = tmp_rdata_a0[3];      tmp_c2[10]  = tmp_rdata_a0[7];
    tmp_c2[2]   = tmp_rdata_a1[2];      tmp_c2[11]  = tmp_rdata_a1[6];
    tmp_c2[3]   = tmp_rdata_a2[0];      tmp_c2[12]  = tmp_rdata_a2[4];
    tmp_c2[4]   = tmp_rdata_a2[1];      tmp_c2[13]  = tmp_rdata_a2[5];
    tmp_c2[5]   = tmp_rdata_a3[0];      tmp_c2[14]  = tmp_rdata_a3[4];
    tmp_c2[6]   = tmp_rdata_a2[2];      tmp_c2[15]  = tmp_rdata_a2[6];
    tmp_c2[7]   = tmp_rdata_a2[3];      tmp_c2[16]  = tmp_rdata_a2[7];
    tmp_c2[8]   = tmp_rdata_a3[2];      tmp_c2[17]  = tmp_rdata_a3[6];

    tmp_c2[18]  = tmp_rdata_a0[10];     tmp_c2[27]  = tmp_rdata_a0[14];
    tmp_c2[19]  = tmp_rdata_a0[11];     tmp_c2[28]  = tmp_rdata_a0[15];
    tmp_c2[20]  = tmp_rdata_a1[10];     tmp_c2[29]  = tmp_rdata_a1[14];
    tmp_c2[21]  = tmp_rdata_a2[8];      tmp_c2[30]  = tmp_rdata_a2[12];
    tmp_c2[22]  = tmp_rdata_a2[9];      tmp_c2[31]  = tmp_rdata_a2[13];
    tmp_c2[23]  = tmp_rdata_a3[8];      tmp_c2[32]  = tmp_rdata_a3[12];
    tmp_c2[24]  = tmp_rdata_a2[10];     tmp_c2[33]  = tmp_rdata_a2[14];
    tmp_c2[25]  = tmp_rdata_a2[11];     tmp_c2[34]  = tmp_rdata_a2[15];
    tmp_c2[26]  = tmp_rdata_a3[10];     tmp_c2[35]  = tmp_rdata_a3[14];

    //channel 3
    tmp_c3[0]   = tmp_rdata_a0[3];      tmp_c3[9]   = tmp_rdata_a0[7];
    tmp_c3[1]   = tmp_rdata_a1[2];      tmp_c3[10]  = tmp_rdata_a1[6];
    tmp_c3[2]   = tmp_rdata_a1[3];      tmp_c3[11]  = tmp_rdata_a1[7];
    tmp_c3[3]   = tmp_rdata_a2[1];      tmp_c3[12]  = tmp_rdata_a2[5];
    tmp_c3[4]   = tmp_rdata_a3[0];      tmp_c3[13]  = tmp_rdata_a3[4];
    tmp_c3[5]   = tmp_rdata_a3[1];      tmp_c3[14]  = tmp_rdata_a3[5];
    tmp_c3[6]   = tmp_rdata_a2[3];      tmp_c3[15]  = tmp_rdata_a2[7];
    tmp_c3[7]   = tmp_rdata_a3[2];      tmp_c3[16]  = tmp_rdata_a3[6];
    tmp_c3[8]   = tmp_rdata_a3[3];      tmp_c3[17]  = tmp_rdata_a3[7];

    tmp_c3[18]  = tmp_rdata_a0[11];     tmp_c3[27]  = tmp_rdata_a0[15];
    tmp_c3[19]  = tmp_rdata_a1[10];     tmp_c3[28]  = tmp_rdata_a1[14];
    tmp_c3[20]  = tmp_rdata_a1[11];     tmp_c3[29]  = tmp_rdata_a1[15];
    tmp_c3[21]  = tmp_rdata_a2[9];      tmp_c3[30]  = tmp_rdata_a2[13];
    tmp_c3[22]  = tmp_rdata_a3[8];      tmp_c3[31]  = tmp_rdata_a3[12];
    tmp_c3[23]  = tmp_rdata_a3[9];      tmp_c3[32]  = tmp_rdata_a3[13];
    tmp_c3[24]  = tmp_rdata_a2[11];     tmp_c3[33]  = tmp_rdata_a2[15];
    tmp_c3[25]  = tmp_rdata_a3[10];     tmp_c3[34]  = tmp_rdata_a3[14];
    tmp_c3[26]  = tmp_rdata_a3[11];     tmp_c3[35]  = tmp_rdata_a3[15];
    
    if(state == CONV3) begin
       case(conv3_ctl)
        2'b01:begin 
        act0 = cache3[0]; act1 = cache3[1]; act2 = cache3[2]; act3 = cache3[3];
        end
        2'b10:begin 
        act0 = cache0[0]; act1 = cache0[1]; act2 = cache0[2]; act3 = cache0[3];
        end
        2'b11:begin 
        act0 = cache1[0]; act1 = cache1[1]; act2 = cache1[2]; act3 = cache1[3];
        end
        2'b00:begin 
        act0 = cache2[0]; act1 = cache2[1]; act2 = cache2[2]; act3 = cache2[3];
        end
       endcase
    end else begin 
        act0 = pipe2_c0;
        act1 = pipe2_c1;
        act2 = pipe2_c2;
        act3 = pipe2_c3;
    end 
end 

integer ci, cj;
reg signed [BW_PER_ACT+BW_PER_PARAM+3:0] bias_shift;// = {{5{local_bias[BW_PER_PARAM-1]}},local_bias,7'd0};
reg [7:0] round; 
integer wi_cho;
always @* begin 
    round = (state <= CONV1) ? 8'b01000000 : ((state == CONV2) ? 8'b00010000 : 8'b00100000);
    bias_shift = (state <= CONV1) ? {{5{local_bias[BW_PER_PARAM-1]}},local_bias,7'd0} : {{9{local_bias[BW_PER_PARAM-1]}},local_bias,3'd0};  // conv3 & conv2 use both bias >> 3
    
    if(state <= CONV1) begin 
    nmul3_1_c0 = {{7{nmul3_c0[15]}}, nmul3_c0[15:7]};
    nmul3_1_c1 = {{7{nmul3_c1[15]}}, nmul3_c1[15:7]};
    nmul3_1_c2 = {{7{nmul3_c2[15]}}, nmul3_c2[15:7]};
    nmul3_1_c3 = {{7{nmul3_c3[15]}}, nmul3_c3[15:7]};
    end else if(state == CONV2) begin 
    nmul3_1_c0 = {{5{nmul3_c0[15]}}, nmul3_c0[15:5]};
    nmul3_1_c1 = {{5{nmul3_c1[15]}}, nmul3_c1[15:5]};
    nmul3_1_c2 = {{5{nmul3_c2[15]}}, nmul3_c2[15:5]};
    nmul3_1_c3 = {{5{nmul3_c3[15]}}, nmul3_c3[15:5]};
    end else begin 
    nmul3_1_c0 = {{8{nmul3_c0[15]}}, nmul3_c0[15:6]};
    nmul3_1_c1 = {{8{nmul3_c1[15]}}, nmul3_c1[15:6]};
    nmul3_1_c2 = {{8{nmul3_c2[15]}}, nmul3_c2[15:6]};
    nmul3_1_c3 = {{8{nmul3_c3[15]}}, nmul3_c3[15:6]};
    end 
    
    if(pong == 1) begin 
        for(wi_cho = 0; wi_cho < 36; wi_cho = wi_cho + 1)
            choose_weight[wi_cho] = pong_weight[wi_cho];
    end else begin 
        for(wi_cho = 0; wi_cho < 36; wi_cho = wi_cho + 1)
            choose_weight[wi_cho] = local_weight[wi_cho];
    end 
end 

always @* begin 
    for(ci = 0; ci < 12; ci = ci + 1) begin 
        nmul_c0[ci] = tmp_c0[3*ci] * choose_weight[3*ci] + tmp_c0[3*ci+1] * choose_weight[3*ci+1] + tmp_c0[3*ci+2] * choose_weight[3*ci+2];
        nmul_c1[ci] = tmp_c1[3*ci] * choose_weight[3*ci] + tmp_c1[3*ci+1] * choose_weight[3*ci+1] + tmp_c1[3*ci+2] * choose_weight[3*ci+2];
        nmul_c2[ci] = tmp_c2[3*ci] * choose_weight[3*ci] + tmp_c2[3*ci+1] * choose_weight[3*ci+1] + tmp_c2[3*ci+2] * choose_weight[3*ci+2];
        nmul_c3[ci] = tmp_c3[3*ci] * choose_weight[3*ci] + tmp_c3[3*ci+1] * choose_weight[3*ci+1] + tmp_c3[3*ci+2] * choose_weight[3*ci+2];
    end 
    
    nmul2_c0 = pipe1_c0[0] + pipe1_c0[1] + pipe1_c0[2] + pipe1_c0[3] + pipe1_c0[4] + pipe1_c0[5] + pipe1_c0[6] + pipe1_c0[7] + pipe1_c0[8] + pipe1_c0[9] + pipe1_c0[10] + pipe1_c0[11];  
    nmul2_c1 = pipe1_c1[0] + pipe1_c1[1] + pipe1_c1[2] + pipe1_c1[3] + pipe1_c1[4] + pipe1_c1[5] + pipe1_c1[6] + pipe1_c1[7] + pipe1_c1[8] + pipe1_c1[9] + pipe1_c1[10] + pipe1_c1[11]; 
    nmul2_c2 = pipe1_c2[0] + pipe1_c2[1] + pipe1_c2[2] + pipe1_c2[3] + pipe1_c2[4] + pipe1_c2[5] + pipe1_c2[6] + pipe1_c2[7] + pipe1_c2[8] + pipe1_c2[9] + pipe1_c2[10] + pipe1_c2[11]; 
    nmul2_c3 = pipe1_c3[0] + pipe1_c3[1] + pipe1_c3[2] + pipe1_c3[3] + pipe1_c3[4] + pipe1_c3[5] + pipe1_c3[6] + pipe1_c3[7] + pipe1_c3[8] + pipe1_c3[9] + pipe1_c3[10] + pipe1_c3[11]; 
    
    nmul3_c0 = bias_shift + act0 + round;//{7'b1000000};
    nmul3_c1 = bias_shift + act1 + round;//{7'b1000000};
    nmul3_c2 = bias_shift + act2 + round;//{7'b1000000};
    nmul3_c3 = bias_shift + act3 + round;//{7'b1000000};

end 

always @* begin 
    
    nmul3_2_c0 = (nmul3_1_c0[15] == 1) ? 0 : ((nmul3_1_c0 >= 13'd127) ? 12'd127 : nmul3_1_c0);//(nmul3_1_c0 >= 12'd127) ? 12'd127 : ((nmul3_1_c0 < 0) ? 0 : nmul3_1_c0);
    nmul3_2_c1 = (nmul3_1_c1[15] == 1) ? 0 : ((nmul3_1_c1 >= 13'd127) ? 12'd127 : nmul3_1_c1);//(nmul3_1_c1 >= 12'd127) ? 12'd127 : ((nmul3_1_c1 < 0) ? 0 : nmul3_1_c1);
    nmul3_2_c2 = (nmul3_1_c2[15] == 1) ? 0 : ((nmul3_1_c2 >= 13'd127) ? 12'd127 : nmul3_1_c2);//(nmul3_1_c2 >= 12'd127) ? 12'd127 : ((nmul3_1_c2 < 0) ? 0 : nmul3_1_c2);
    nmul3_2_c3 = (nmul3_1_c3[15] == 1) ? 0 : ((nmul3_1_c3 >= 13'd127) ? 12'd127 : nmul3_1_c3);//(nmul3_1_c3 >= 12'd127) ? 12'd127 : ((nmul3_1_c3 < 0) ? 0 : nmul3_1_c3);
end 
wire [BW_PER_ACT-1:0] comp0 = pipe3_c0 > pipe3_c1 ? pipe3_c0 : pipe3_c1;
wire [BW_PER_ACT-1:0] comp1 = pipe3_c2 > pipe3_c3 ? pipe3_c2 : pipe3_c3;
always @* begin 
    n_maxpool = (comp0 > comp1) ? comp0 : comp1;
end 

endmodule