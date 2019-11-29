module Convnet_top #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 8
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

//read address from SRAM group A
output [5:0] sram_raddr_a0,
output [5:0] sram_raddr_a1,
output [5:0] sram_raddr_a2,
output [5:0] sram_raddr_a3,

output busy,
output valid,                         //output valid to check the final answer (after POOL)

//write enable for SRAM group A 
output sram_wen_a0,
output sram_wen_a1,
output sram_wen_a2,
output sram_wen_a3,

//bytemask for SRAM group A 
output [CH_NUM*ACT_PER_ADDR-1:0] sram_bytemask_a,
//write addrress to SRAM group A 
output [5:0] sram_waddr_a,
//write data to SRAM group A 
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_wdata_a
);
localparam IDLE=2'd0, ACT=2'd1, END=2'd2;
reg [4:0] row, nrow;
reg [1:0] state, nstate;
reg l_enable;
reg l_busy;
reg l_valid;
reg [7:0] tmp [0:3]
reg [1:0] idx, nidx,prev_idx; // 0 - 3
// idx: current input data correspond to idx
reg [2:0] cnt, ncnt;
assign busy = l_busy;
assign valid = l_valid;
reg [CH_NUM*ACT_PER_ADDR-1:0] l_sram_bytemask_a, nl_sram_bytemask_a;
reg [5:0] l_sram_waddr_a, nl_sram_waddr_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] l_sram_wdata_a;
reg l_sram_wen [0:3];
assign sram_bytemask_a = l_sram_bytemask_a;
assign sram_waddr_a = l_sram_waddr_a;
assign sram_wdata_a = l_sram_wdata_a;
assign sram_wen_a0 = l_sram_wen[0];
assign sram_wen_a1 = l_sram_wen[1];
assign sram_wen_a2 = l_sram_wen[2];
assign sram_wen_a3 = l_sram_wen[3];
reg [1:0] bank_num;
always @* begin 
  if(!l_enable)
    nstate = IDLE;
  else begin 
    case(state) 
      IDLE: nstate = l_enable ? ACT : IDLE;
      ACT: nstate = (row == 28) ? END : ACT;
      END: nstate =  END;
      default: nstate = IDLE;
    endcase
  end 
end 

always @* begin 
  bank_num = row[2]
end 


always @(posedge clk) begin 
  if(!rst_n) begin 
    state <= IDLE;
    row <= 0;   idx <= 0;   cnt <= 0; prev_idx <= 0;
    tmp[0] <= 0; tmp[1] <= 0; tmp[2] <= 0; tmp[3] <= 0; tmp[4] <= 0; tmp[5] <= 0;
    l_sram_bytemask_a <= {CH_NUM*ACT_PER_ADDR{1'b1}};
    l_sram_waddr_a <= 0;
    l_sram_wdata_a <= 0;
    l_sram_wen[0] <= 0; l_sram_wen[1] <= 0; l_sram_wen[2] <= 0; l_sram_wen[3] <= 0;
  end else begin 
    l_enable <= enable;
    l_busy <= ~enable;
    if(l_enable && state != END) begin 
      tmp[3] <= input_data; // take in input data to tmp!
      tmp[2] <= tmp[3];
      tmp[1] <= tmp[2];
      tmp[0] <= tmp[1];
    end 
    
    if(idx == 3) begin 
      //export in next cycle
      l_sram_wen[bank_num] <= 1;
    end else begin 
      l_sram_wen[0] <= 0; l_sram_wen[1] <= 0; l_sram_wen[2] <= 0; l_sram_wen[3] <= 0;
    end 

    state <= nstate
    idx <= nidx;
    prev_idx <= idx;
    cnt <= ncnt;
    row <= nrow;
  end
end 

always @* begin  
  nidx = idx;
  if(state == ACT) begin 
    if(idx == 3)    nidx = 0
    else            nidx = idx + 1;
  end

  ncnt = cnt;
  if(state == ACT && idx == 3) begin 
    if(cnt == 6)    ncnt = 0;
    else            ncnt = cnt + 1;
  end 

  nrow = row;
  if(state == ACT && cnt == 6) begin 
    nrow = row + 1;
  end 
end 


endmodule