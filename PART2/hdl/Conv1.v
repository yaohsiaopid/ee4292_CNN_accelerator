
module Conv1  #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 8,
parameter BW_PER_PARAM = 8
)
(
input clk,                       
input rst_n,                     
input enable,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_a3,
input [BW_PER_ACT-1:0] pipe3_c0,
input [BW_PER_ACT-1:0] pipe3_c1,
input [BW_PER_ACT-1:0] pipe3_c2,
input [BW_PER_ACT-1:0] pipe3_c3,
// output 
output reg valid,             
output [5:0] n_sram_raddr_a0,
output [5:0] n_sram_raddr_a1,
output [5:0] n_sram_raddr_a2,
output [5:0] n_sram_raddr_a3,
//bytemask for SRAM group B
output [CH_NUM*ACT_PER_ADDR-1:0] n_sram_bytemask_b,
// write addrress to SRAM group B
output [5:0] n_sram_waddr_b,
// write data to SRAM group B
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_sram_wdata_b,
output [3:0] n_sram_wen,
//
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_a0,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_a1,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_a2,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_a3,
output [10:0] n_raddr_weight,
output [6:0]  n_raddr_bias,
output reg wr_w,
output reg wr_b
);
reg [10:0] l_raddr_weight;
reg [6:0]  l_raddr_bias;
reg [CH_NUM*ACT_PER_ADDR-1:0]  nl_sram_bytemask_b;
reg [5:0] l_sram_raddr_a0, l_sram_raddr_a1, l_sram_raddr_a2, l_sram_raddr_a3;
reg [5:0] nl_sram_raddr_a0, nl_sram_raddr_a1, nl_sram_raddr_a2, nl_sram_raddr_a3;
reg [3:0] nl_sram_wen; // sram b
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] nl_sram_wdata_b;
reg [5:0]  nl_sram_waddr_b;
assign n_sram_raddr_a0 = nl_sram_raddr_a0;
assign n_sram_raddr_a1 = nl_sram_raddr_a1;
assign n_sram_raddr_a2 = nl_sram_raddr_a2;
assign n_sram_raddr_a3 = nl_sram_raddr_a3;
assign n_sram_wen = nl_sram_wen;
assign n_sram_bytemask_b = nl_sram_bytemask_b;
assign n_sram_wdata_b = nl_sram_wdata_b;
assign n_sram_waddr_b = nl_sram_waddr_b;
localparam IDLE=2'd0, PREP=2'd1, ACT=2'd2, END=2'd3;
reg [1:0] ch, nch;
reg [2:0] row, nrow, col, ncol;
reg [1:0] state, nstate;
reg mode;
reg ready;
reg [2:0] wbcnt, nwbcnt;
reg [2:0] wbrow, nwbrow; 
reg [1:0] nbank_num;
reg [1:0] tmpcnt, ntmpcnt;
assign n_raddr_weight = l_raddr_weight;// + 1;
assign n_raddr_bias = l_raddr_bias;// + 1;
always @* begin 

    nwbcnt = wbcnt;
    nwbrow = wbrow;
    if(ready) begin 
        if(nwbcnt == 5) begin
            nwbrow = wbrow + 1;
            nwbcnt = 0;
        end else begin 
            nwbrow = wbrow;
            nwbcnt = wbcnt + 1;
        end 
    end 

    nbank_num = {wbrow[0], wbcnt[0]};
    nl_sram_waddr_b = 6 * wbrow[2:0] + wbcnt[2:1]; // 6 * r/2 + cnt/2
    case(ch)
        2'd0: nl_sram_wdata_b = {pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{12*BW_PER_ACT{1'b0}}};
        2'd1: nl_sram_wdata_b = {{4*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{8*BW_PER_ACT{1'b0}}};
        2'd2: nl_sram_wdata_b = {{8*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{4*BW_PER_ACT{1'b0}}};
        2'd3: nl_sram_wdata_b = {{12*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3};
    endcase
    case(ch) 
        2'd0: nl_sram_bytemask_b = {1'b0,1'b0,1'b0,1'b0,{12{1'b1}}};
        2'd1: nl_sram_bytemask_b = {{4{1'b1}},1'b0,1'b0,1'b0,1'b0,{8{1'b1}}};
        2'd2: nl_sram_bytemask_b = {{8{1'b1}},1'b0,1'b0,1'b0,1'b0,{4{1'b1}}};
        2'd3: nl_sram_bytemask_b = {{12{1'b1}},1'b0,1'b0,1'b0,1'b0};
    endcase
    nl_sram_wen = 4'b1111;
    if(ready) begin 
        case(nbank_num)
            2'd0: nl_sram_wen = 4'b1110;
            2'd1: nl_sram_wen = 4'b1101;
            2'd2: nl_sram_wen = 4'b1011;
            2'd3: nl_sram_wen = 4'b0111;
        endcase
    end 
end 



always @* begin 
    nl_sram_raddr_a0 = l_sram_raddr_a0; nl_sram_raddr_a1 = l_sram_raddr_a1;
    nl_sram_raddr_a2 = l_sram_raddr_a2; nl_sram_raddr_a3 = l_sram_raddr_a3;
    if(state == PREP || state == ACT) begin 
        if(col == 4) begin 
        nl_sram_raddr_a0 = 6 * (row[2:1] + 1); 
        nl_sram_raddr_a1 = 6 * (row[2:1] + 1);
        nl_sram_raddr_a2 = 6 * (row[2:1] + 1) - 6 * (row[0] == 0); 
        nl_sram_raddr_a3 = 6 * (row[2:1] + 1) - 6 * (row[0] == 0);
        end else begin 
            nl_sram_raddr_a0 = l_sram_raddr_a0 + (mode == 0); nl_sram_raddr_a1 = l_sram_raddr_a1 + (mode == 1);
            nl_sram_raddr_a2 = l_sram_raddr_a2 + (mode == 0); nl_sram_raddr_a3 = l_sram_raddr_a3 + (mode == 1);
        end 
    end

    ntmpcnt = tmpcnt;
    if(state == ACT && row == 5 && col == 5) begin 
        ntmpcnt = tmpcnt + 1;
    end 
    
    nrow = row; ncol = col; nch = ch; 
    if(state == ACT) begin 
        if(row == 5 && col == 5) begin 
            if(tmpcnt == 3) begin 
                nrow = 0; ncol = 0;
            end
        end else begin 
            if(col == 5) begin 
                ncol = 0;   nrow = row + 1;
            end else begin 
                ncol = col + 1; nrow = row; 
            end 
        end 
           
    end 
    if(!enable) begin 
        nstate = IDLE;
    end else begin
        case(state) 
            IDLE: nstate = PREP;
            PREP: nstate = ACT;
            ACT: nstate = (ch == 3 && row == 5 && col == 5 && tmpcnt == 2) ? END : ACT;
            END: nstate = END;
        endcase
    end

    case({row[0],col[0]})
        2'b00: begin 
            n_tmp_a0 = sram_rdata_a0;
            n_tmp_a1 = sram_rdata_a1;
            n_tmp_a2 = sram_rdata_a2;
            n_tmp_a3 = sram_rdata_a3;
        end 
        2'b01: begin 
            n_tmp_a0 = sram_rdata_a1;
            n_tmp_a1 = sram_rdata_a0;
            n_tmp_a2 = sram_rdata_a3;
            n_tmp_a3 = sram_rdata_a2;
        end 
        2'b10: begin 
            n_tmp_a0 = sram_rdata_a2;
            n_tmp_a1 = sram_rdata_a3;
            n_tmp_a2 = sram_rdata_a0;
            n_tmp_a3 = sram_rdata_a1;
        end 
        2'b11: begin 
            n_tmp_a0 = sram_rdata_a3;
            n_tmp_a1 = sram_rdata_a2;
            n_tmp_a2 = sram_rdata_a1;
            n_tmp_a3 = sram_rdata_a0;
        end 
    endcase 
end 

always @(posedge clk) begin 
    if(~rst_n) begin 
        ready <= 0;
        state <= IDLE;
        ch <= 0; row <= 0; col <= 0;
        l_sram_raddr_a0 <= 0; l_sram_raddr_a1 <= 0; l_sram_raddr_a2 <= 0; l_sram_raddr_a3 <= 0;
        valid <= 0;
        mode <= 0;
        wbcnt <= 0; wbrow <= 0;
        tmpcnt <= 0;
        wr_b <= 0; wr_w <= 0;
        l_raddr_weight <= 4;
        l_raddr_bias <= 1;
        // prev_row <= 0; prev_cnt <= 0; prev_idx <= 0;
        // row <= 0;   idx <= 0;   cnt <= 0; 
    end else begin 
        state <= nstate;
        row <= nrow; col <= ncol; //ch <= nch;
        tmpcnt <= ntmpcnt;
        l_sram_raddr_a0 <= nl_sram_raddr_a0; l_sram_raddr_a1 <= nl_sram_raddr_a1;
        l_sram_raddr_a2 <= nl_sram_raddr_a2; l_sram_raddr_a3 <= nl_sram_raddr_a3;
        if(!ready && col == 2) begin 
            ready <= 1;
        end else if(row == 5 && tmpcnt == 2) begin 
            ready <= 0;
            ch <= ch + 1;
        end 

        if(state == ACT && row == 5 && col >= 4) begin 
            if(tmpcnt < 3) begin 
            l_raddr_weight <= l_raddr_weight + 1;
            l_raddr_bias <= l_raddr_bias + 1;
            end 
            wr_b <= 1;
            wr_w <= 1;
        end else begin 
            wr_b <= 0;
            wr_w <= 0;
        end 

        if(state == END) 
            valid <= 1;
        if(state == PREP || state == ACT) begin 
            mode <= !mode;
        end 
        wbcnt <= nwbcnt; wbrow <= nwbrow;
        // if(state == PREP || state == ACT) begin 
        //     $display("%d %d %d %d %d", col, l_sram_raddr_a0, l_sram_raddr_a1, l_sram_raddr_a2, l_sram_raddr_a3);
        // end 
    end 
end 

endmodule

