
module Conv2  #(
parameter CH_NUM = 4,
parameter ACT_PER_ADDR = 4,
parameter BW_PER_ACT = 8,
parameter BW_PER_PARAM = 8
)
(
input clk,                       
input rst_n,                     
input enable,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b0,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b1,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b2,
input [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] sram_rdata_b3,
input [BW_PER_ACT-1:0] pipe3_c0,
input [BW_PER_ACT-1:0] pipe3_c1,
input [BW_PER_ACT-1:0] pipe3_c2,
input [BW_PER_ACT-1:0] pipe3_c3,
// output 
output reg valid,             
output [5:0] n_sram_raddr_b0,
output [5:0] n_sram_raddr_b1,
output [5:0] n_sram_raddr_b2,
output [5:0] n_sram_raddr_b3,
//bytemask for SRAM group B
output [CH_NUM*ACT_PER_ADDR-1:0] n_sram_bytemask_a,
// write addrress to SRAM group B
output [5:0] n_sram_waddr_a,
// write data to SRAM group B
output [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_sram_wdata_a,
output [3:0] n_sram_wen,
//
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_b0,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_b1,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_b2,
output reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] n_tmp_b3,
output [10:0] n_raddr_weight,
output [6:0]  n_raddr_bias,
output reg wr_w,
output reg wr_b
);
reg [10:0] l_raddr_weight;
reg [6:0]  l_raddr_bias;
reg [CH_NUM*ACT_PER_ADDR-1:0]  nl_sram_bytemask_a;
reg [5:0] l_sram_raddr_b0, l_sram_raddr_b1, l_sram_raddr_b2, l_sram_raddr_b3;
reg [5:0] nl_sram_raddr_b0, nl_sram_raddr_b1, nl_sram_raddr_b2, nl_sram_raddr_b3;
reg [3:0] nl_sram_wen; // sram b
reg [CH_NUM*ACT_PER_ADDR*BW_PER_ACT-1:0] nl_sram_wdata_a;
reg [5:0]  nl_sram_waddr_a;
assign n_sram_raddr_b0 = nl_sram_raddr_b0;
assign n_sram_raddr_b1 = nl_sram_raddr_b1;
assign n_sram_raddr_b2 = nl_sram_raddr_b2;
assign n_sram_raddr_b3 = nl_sram_raddr_b3;
assign n_sram_wen = nl_sram_wen;
assign n_sram_bytemask_a = nl_sram_bytemask_a;
assign n_sram_wdata_a = nl_sram_wdata_a;
assign n_sram_waddr_a = nl_sram_waddr_a;
localparam IDLE=2'd0, PREP=2'd1, ACT=2'd2, END=2'd3;
reg [3:0] ch, nch;
reg [2:0] row, nrow, col, ncol;
reg [1:0] state, nstate;
reg mode;
reg ready;
reg [2:0] wbcnt, nwbcnt;
reg [2:0] wbrow, nwbrow; 
reg [1:0] nbank_num;
reg [2:0] tmpcnt, ntmpcnt;
reg delay;
assign n_raddr_weight = l_raddr_weight;// + 1;
assign n_raddr_bias = l_raddr_bias;// + 1;
always @* begin 

    nwbcnt = wbcnt;
    nwbrow = wbrow;
    if(ready) begin 
        if(wbcnt == 4) begin
            if(wbrow == 4) 
            nwbrow = 0;
            else 
            nwbrow = wbrow + 1;
            nwbcnt = 0;
        end else begin 
            nwbrow = wbrow;
            nwbcnt = wbcnt + 1;
        end 
    end 

    nbank_num = {wbrow[0], wbcnt[0]};
    nl_sram_waddr_a = 6 * wbrow[2:1] + wbcnt[2:1]; // 6 * r/2 + cnt/2
    case(ch)
        2'd0: nl_sram_wdata_a = {pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{12*BW_PER_ACT{1'b0}}};
        2'd1: nl_sram_wdata_a = {{4*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{8*BW_PER_ACT{1'b0}}};
        2'd2: nl_sram_wdata_a = {{8*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3,{4*BW_PER_ACT{1'b0}}};
        2'd3: nl_sram_wdata_a = {{12*BW_PER_ACT{1'b0}},pipe3_c0,pipe3_c1,pipe3_c2, pipe3_c3};
    endcase
    case(ch) 
        2'd0: nl_sram_bytemask_a = {1'b0,1'b0,1'b0,1'b0,{12{1'b1}}};
        2'd1: nl_sram_bytemask_a = {{4{1'b1}},1'b0,1'b0,1'b0,1'b0,{8{1'b1}}};
        2'd2: nl_sram_bytemask_a = {{8{1'b1}},1'b0,1'b0,1'b0,1'b0,{4{1'b1}}};
        2'd3: nl_sram_bytemask_a = {{12{1'b1}},1'b0,1'b0,1'b0,1'b0};
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
    nl_sram_raddr_b0 = l_sram_raddr_b0; nl_sram_raddr_b1 = l_sram_raddr_b1;
    nl_sram_raddr_b2 = l_sram_raddr_b2; nl_sram_raddr_b3 = l_sram_raddr_b3;
    if(state == ACT) begin 
        if(col == 3) begin 
        nl_sram_raddr_b0 = 6 * (row[2:1] + 1); 
        nl_sram_raddr_b1 = 6 * (row[2:1] + 1);
        nl_sram_raddr_b2 = 6 * (row[2:1] + 1) - 6 * (row[0] == 0); 
        nl_sram_raddr_b3 = 6 * (row[2:1] + 1) - 6 * (row[0] == 0);
        end else begin 
            if(row == 4 && col == 4) begin 
                    nl_sram_raddr_b0 = 0; nl_sram_raddr_b1 = 0;
                    nl_sram_raddr_b2 = 0; nl_sram_raddr_b3 = 0;
            end else begin
                nl_sram_raddr_b0 = l_sram_raddr_b0 + (mode == 0); nl_sram_raddr_b1 = l_sram_raddr_b1 + (mode == 1);
                nl_sram_raddr_b2 = l_sram_raddr_b2 + (mode == 0); nl_sram_raddr_b3 = l_sram_raddr_b3 + (mode == 1);
            end
        end 
    end

    ntmpcnt = tmpcnt;
    if(state == PREP) begin
        if(tmpcnt == 5)
            ntmpcnt = 0;
        else 
            ntmpcnt = tmpcnt + 1; 
    end else if(state == ACT && row == 4 && col == 4) begin 
        if(tmpcnt == 6) 
            ntmpcnt = 0;
        else 
            ntmpcnt = tmpcnt + 1;
    end 
    
    nrow = row; ncol = col; nch = ch; 
    if(state == ACT) begin 
        if(col == 4) begin 
            if(row == 4) begin 
                if(tmpcnt == 6) begin   ncol = 0; nrow = 0; end 
                else begin ncol = col; nrow = row; end 
            end else begin 
                ncol = 0;   nrow = row + 1;
            end 
        end else begin 
            if(!delay && row == 0 && col == 0) begin 
                nrow = row; ncol = 0;
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
            PREP: nstate = (tmpcnt == 5) ? ACT : PREP;
            ACT: nstate = (ch == 5 && row == 4 && col == 4 && tmpcnt == 2) ? END : ACT;
            END: nstate = END;
        endcase
    end

    case({row[0],col[0]})
        2'b00: begin 
            n_tmp_b0 = sram_rdata_b0;
            n_tmp_b1 = sram_rdata_b1;
            n_tmp_b2 = sram_rdata_b2;
            n_tmp_b3 = sram_rdata_b3;
        end 
        2'b01: begin 
            n_tmp_b0 = sram_rdata_b1;
            n_tmp_b1 = sram_rdata_b0;
            n_tmp_b2 = sram_rdata_b3;
            n_tmp_b3 = sram_rdata_b2;
        end 
        2'b10: begin 
            n_tmp_b0 = sram_rdata_b2;
            n_tmp_b1 = sram_rdata_b3;
            n_tmp_b2 = sram_rdata_b0;
            n_tmp_b3 = sram_rdata_b1;
        end 
        2'b11: begin 
            n_tmp_b0 = sram_rdata_b3;
            n_tmp_b1 = sram_rdata_b2;
            n_tmp_b2 = sram_rdata_b1;
            n_tmp_b3 = sram_rdata_b0;
        end 
    endcase 
end 

always @(posedge clk) begin 
    if(~rst_n) begin 
        ready <= 0;
        state <= IDLE;
        ch <= 0; row <= 0; col <= 0;
        l_sram_raddr_b0 <= 0; l_sram_raddr_b1 <= 0; l_sram_raddr_b2 <= 0; l_sram_raddr_b3 <= 0;
        valid <= 0;
        mode <= 0;
        wbcnt <= 0; wbrow <= 0;
        tmpcnt <= 0;
        wr_b <= 0; wr_w <= 0;
        l_raddr_weight <= 16;
        l_raddr_bias <= 4;
        delay <= 0;
    end else begin 
        state <= nstate;
        row <= nrow; col <= ncol; //ch <= nch;
        tmpcnt <= ntmpcnt;
        l_sram_raddr_b0 <= nl_sram_raddr_b0; l_sram_raddr_b1 <= nl_sram_raddr_b1;
        l_sram_raddr_b2 <= nl_sram_raddr_b2; l_sram_raddr_b3 <= nl_sram_raddr_b3;
        if(!delay && row == 0 && col == 0)  
            delay <= 1;
        else 
            delay <= 0;
        if(!ready && col == 2) begin 
            ready <= 1;
        end else if(row == 4 && tmpcnt == 4) begin 
            ready <= 0;
            ch <= ch + 1;
        end 

        if(state == IDLE && enable) begin 
            wr_b <= 1;
            wr_w <= 1;
        end else if((state == ACT && row == 4 && col == 4)) begin 
            if(tmpcnt > 1) begin 
                wr_b <= 1;
                wr_w <= 1;
                if(tmpcnt < 6) begin 
                    l_raddr_weight <= l_raddr_weight + 1;
                end 
            end
            if(tmpcnt == 1) begin 
                l_raddr_bias <= ch + 1;
            end 
        end else if(state == PREP) begin
            l_raddr_weight <= l_raddr_weight + 1;
            if(tmpcnt == 5) begin
                wr_b <= 0;
                wr_w <= 0; 
            end 
        end else begin 
            wr_b <= 0;
            wr_w <= 0;
        end 

        if(state == END) 
            valid <= 1;
            
        if(state == ACT) begin 
            if(col == 3)
                mode <= 0;
            else 
                mode <= !mode;
        end 
        wbcnt <= nwbcnt; wbrow <= nwbrow;
    end 
end 

endmodule

