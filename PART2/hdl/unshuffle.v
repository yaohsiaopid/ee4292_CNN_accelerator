module Unshuffle #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 8
)
(
input clk,                           //clock input
input rst_n,                         //synchronous reset (active low)

input enable,
input [BW_PER_ACT-1:0] input_data,    //input image

output busy,
output valid,                         // 
//write enable for SRAM group A 
output [3:0] n_sram_wen,

//bytemask for SRAM group A 
output [CH_NUM*ACT_PER_ADDR-1:0] n_sram_bytemask_a,
//write addrress to SRAM group A 
output [5:0] n_sram_waddr_a,
//write data to SRAM group A 
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_sram_wdata_a

);

localparam IDLE=2'd0, ACT=2'd1, END=2'd2;
reg [4:0] row, nrow, prev_row;
reg [1:0] state, nstate;
reg l_enable;
reg l_busy;
reg l_valid;
reg [BW_PER_ACT-1:0] tmp[0:3];
reg [1:0] idx, nidx,prev_idx; // 0 - 3
// idx:  input data just went into ff correspond to idx
reg [2:0] cnt, ncnt, prev_cnt;
assign busy = l_busy;
assign valid = l_valid;
reg [CH_NUM*ACT_PER_ADDR-1:0]  nl_sram_bytemask_a;
reg [5:0]  nl_sram_waddr_a;
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] nl_sram_wdata_a;
// reg l_sram_wen [0:3];
reg [3:0] nl_sram_wen;
// assign sram_bytemask_a = l_sram_bytemask_a;
// assign sram_waddr_a = l_sram_waddr_a;
// assign sram_wdata_a = l_sram_wdata_a;
reg [1:0] nbank_num;
assign n_sram_bytemask_a = nl_sram_bytemask_a;
assign n_sram_waddr_a = nl_sram_waddr_a;
assign n_sram_wdata_a = nl_sram_wdata_a;
assign n_sram_wen = nl_sram_wen;
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
  nbank_num = {prev_row[2], prev_cnt[0]}; // ((r % 8) / 4) * 2 + cnt % 2
  nl_sram_waddr_a = 6 * prev_row[4:3] + prev_cnt[2:1];// 6 * (r/8) + (cnt / 2);
  case(prev_row[1:0]) 
    2'd0: nl_sram_wdata_a = {tmp[0],tmp[2],{2*BW_PER_ACT{1'b0}},tmp[1],tmp[3],{10*BW_PER_ACT{1'b0}}};
    2'd1: nl_sram_wdata_a = {{8*BW_PER_ACT{1'b0}},tmp[0],tmp[2],{2*BW_PER_ACT{1'b0}},tmp[1],tmp[3],{2*BW_PER_ACT{1'b0}}};
    2'd2: nl_sram_wdata_a = {{2*BW_PER_ACT{1'b0}},tmp[0],tmp[2],{2*BW_PER_ACT{1'b0}},tmp[1],tmp[3],{8*BW_PER_ACT{1'b0}}};
    2'd3: nl_sram_wdata_a = {{10*BW_PER_ACT{1'b0}}, tmp[0],tmp[2],{2*BW_PER_ACT{1'b0}},tmp[1],tmp[3]};
  endcase 
  case(prev_row[1:0]) 
    2'd0: nl_sram_bytemask_a = {1'b0,1'b0,{2{1'b1}},1'b0,1'b0,{10{1'b1}}};
    2'd1: nl_sram_bytemask_a = {{8{1'b1}}, 1'b0, 1'b0, {2{1'b1}}, 1'b0, 1'b0, {2{1'b1}}};
    2'd2: nl_sram_bytemask_a = {{2{1'b1}},1'b0, 1'b0,{2{1'b1}},1'b0, 1'b0,{8{1'b1}}};
    2'd3: nl_sram_bytemask_a = {{10{1'b1}}, 1'b0, 1'b0,{2{1'b1}},1'b0, 1'b0};
  endcase

  if(prev_idx == 3) begin 
    case(nbank_num)
        2'd0: nl_sram_wen = 4'b1110;
        2'd1: nl_sram_wen = 4'b1101;
        2'd2: nl_sram_wen = 4'b1011;
        2'd3: nl_sram_wen = 4'b0111;
    endcase
  end else begin 
    nl_sram_wen = 4'b1111;
  end 

end 


always @(posedge clk) begin 
  if(!rst_n) begin 
    state <= IDLE;
    row <= 0;   idx <= 0;   cnt <= 0; 
    tmp[0] <= 0; tmp[1] <= 0; tmp[2] <= 0; tmp[3] <= 0; 
    // l_sram_bytemask_a <= {CH_NUM*ACT_PER_ADDR{1'b1}};
    // l_sram_waddr_a <= 0;
    // l_sram_wdata_a <= 0;
    l_valid <= 0;
    prev_row <= 0; prev_cnt <= 0; prev_idx <= 0;
  end else begin 
    l_enable <= enable;
    l_busy <= ~l_enable;
    if(l_enable && state != END) begin 
    //   $display("row: %d  cnt: %d idx: %d %b", row,cnt, idx, input_data);
      tmp[3] <= input_data; // take in input data to tmp!
      tmp[2] <= tmp[3];
      tmp[1] <= tmp[2];
      tmp[0] <= tmp[1];
    end 
    
    // if(prev_idx == 3) begin 
    //   l_sram_waddr_a <= nl_sram_waddr_a;
    //   l_sram_wdata_a <= nl_sram_wdata_a;
    //   l_sram_bytemask_a <= nl_sram_bytemask_a;
    // end  

    state <= nstate;
    idx <= nidx;
    cnt <= ncnt;
    row <= nrow;
    prev_row <= row; prev_cnt <= cnt; prev_idx <= idx;
    if(state == END)
      l_valid <= 1;
  end
end 

always @* begin  
  nidx = idx;
  if(state == ACT) begin 
    if(idx == 3)    nidx = 0;
    else            nidx = idx + 1;
  end

  ncnt = cnt;
  if(state == ACT && idx == 3) begin 
    if(cnt == 6)    ncnt = 0;
    else            ncnt = cnt + 1;
  end 

  nrow = row;
  if(state == ACT && cnt == 6 && idx == 3) begin 
    nrow = row + 1;
  end 
end 

endmodule