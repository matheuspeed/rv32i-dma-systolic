module dmem_dp(
    //CPU
    input wire clk,
    input wire [31:0] a,
    input wire [31:0] wd,
    input wire we,
    input wire [2:0] mode,
    output reg [31:0] rd,

    //DMA
    input wire [9:0] memb_addr,
    input wire [31:0] memb_wdata,
    input wire memb_we,
    output reg [31:0] memb_rdata
);
    reg [7:0] mem [0:4095]; // Memória com 4 KB

    wire [11:0] ad = a[11:0];

    // Leitura Assíncrona
    always @(*) begin
        case (mode)
            3'b000: // 4 bytes (LW)
                rd = {mem[ad+3], mem[ad+2], mem[ad+1], mem[ad]};
            3'b001: // Unsigned 2 bytes (LHU)
                rd = {16'b0, mem[ad+1], mem[ad]};
            3'b010: // Signed 2 bytes (LH)
                rd = {{16{mem[ad+1][7]}}, mem[ad+1], mem[ad]};
            3'b011: // Unsigned 1 byte (LBU)
                rd = {24'b0, mem[ad]};
            3'b100: // Signed 1 byte (LB)
                rd = {{24{mem[ad][7]}}, mem[ad]};
            default: rd = 32'b0;
        endcase

        
    end

    // Escrita Síncrona
    always @(posedge clk) begin
        //CPU
        if (we) begin
            case (mode)
                3'b000: begin // SW
                    mem[ad]   <= wd[7:0];
                    mem[ad+1] <= wd[15:8];
                    mem[ad+2] <= wd[23:16];
                    mem[ad+3] <= wd[31:24];
                end
                3'b001, 3'b010: begin // SH
                    mem[ad]   <= wd[7:0];
                    mem[ad+1] <= wd[15:8];
                end
                3'b011, 3'b100: begin // SB
                    mem[ad]   <= wd[7:0];
                end
            endcase
        end
        //DMA
        if(memb_we) begin
            mem[{memb_addr,2'b00}] <= memb_wdata[7:0];
            mem[{memb_addr,2'b00}+1] <= memb_wdata[15:8];
            mem[{memb_addr,2'b00}+2] <= memb_wdata[23:16];
            mem[{memb_addr,2'b00}+3] <= memb_wdata[31:24];
        end

        memb_rdata <= {mem[{memb_addr,2'b00}+3], mem[{memb_addr,2'b00}+2],
                        mem[{memb_addr,2'b00}+1], mem[{memb_addr,2'b00}]};
    end
endmodule