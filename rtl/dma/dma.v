module dma #(
    parameter ARRAY_SIZE = 4,
    parameter BUF_DEPTH = 16,
    parameter ACC_W = 32,
    parameter DATA_W = 8
)(
    //Sistema
    input clk, rst,
    output wire irq,
    //Registradores
    input [7:0] reg_addr,
    input [31:0] reg_wdata,
    input reg_we,
    output reg [31:0] reg_rdata,
    //Memória
    input [31:0] memb_rdata,
    output reg [9:0] memb_addr,
    output reg [31:0] memb_wdata,
    output reg memb_we,
    //Buffers
    output reg [$clog2(ARRAY_SIZE)-1:0] buf_bank,
    output reg buf_we,
    output reg buf_sel,
    output reg [$clog2(BUF_DEPTH)-1:0] buf_addr,
    output reg [DATA_W-1:0]  buf_wdata,
    //Acelerador
    input acc_busy,
    input acc_done,
    input [ACC_W-1:0] c_data,
    output reg acc_start,
    output reg acc_clear,
    output reg [$clog2(BUF_DEPTH):0] acc_klen,
    output reg [$clog2(ARRAY_SIZE*ARRAY_SIZE)-1:0] c_sel
);

    localparam  IDLE = 4'd0,
                LD_A_REQ = 4'd1,
                LD_A_WR = 4'd2,
                LD_B_REQ = 4'd3,
                LD_B_WR = 4'd4,
                RUN_START = 4'd5,
                RUN_WAIT = 4'd6,
                ST_C = 4'd7,
                FINISH = 4'd8;

    reg [3:0] state, next_state;

    // configuração (escritos pela CPU/testbench)
    reg [31:0] addr_a, addr_b, addr_c;
    reg [31:0] dim_m, dim_n, dim_k;
    reg        irq_en;

    // estado (escritos pela FSM)
    reg        done;
    reg [31:0] cycles;
    reg        start;        // pulso de 1 ciclo gerado pela escrita em CTRL

    wire       busy = (state != IDLE);   // state é o registrador de estado da FSM

    // contadores e endereços FSM
    reg [31:0] ti, tj, k0;                        // bloco de C (linha, coluna) e início do pedaço de K
    reg [$clog2(ARRAY_SIZE)-1:0] b;               // banco (linha de A / coluna de B)
    reg [$clog2(BUF_DEPTH)-1:0]  p;               // posição dentro do banco
    reg [$clog2(ARRAY_SIZE)-1:0] r, c;            // acumulador sendo gravado (linha, coluna)
    reg [1:0] off_r;                              // qual byte da palavra pegar (guardado no REQ)

    // tamanho do pedaço atual de K: 16, ou o que sobrar no último pedaço
    wire [31:0] k_rest = dim_k - k0;
    wire [$clog2(BUF_DEPTH):0] klen = (k_rest > BUF_DEPTH) ? BUF_DEPTH : k_rest;

    // endereços em BYTES (fórmulas da especificação)
    wire [31:0] a_byte = addr_a + (ti + b) * dim_k + k0 + p;           // A[ti+b][k0+p]
    wire [31:0] b_byte = addr_b + (k0 + p) * dim_n + tj + b;           // B[k0+p][tj+b]
    wire [31:0] c_byte = addr_c + (((ti + r) * dim_n + tj + c) << 2);  // C[ti+r][tj+c], 4 bytes cada

    // condições de "fim de laço"
    wire last_load  = (p == klen - 1) && (b == ARRAY_SIZE - 1);   // último elemento de A (ou B) do pedaço
    wire last_chunk = (k0 + BUF_DEPTH >= dim_k);                  // este é o último pedaço de K
    wire last_acc   = (r == ARRAY_SIZE - 1) && (c == ARRAY_SIZE - 1);
    wire last_block = (ti + ARRAY_SIZE >= dim_m) && (tj + ARRAY_SIZE >= dim_n);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            addr_a <= 0;  addr_b <= 0;  addr_c <= 0;
            dim_m  <= 0;  dim_n  <= 0;  dim_k  <= 0;
            irq_en <= 0;  start  <= 0;  done   <= 0;
        end else begin
            start <= 1'b0;                          // padrão: sem pulso

            if (reg_we) begin
                case (reg_addr)
                    8'h00: begin                     // CTRL
                        irq_en <= reg_wdata[1];
                        if (reg_wdata[0] && !busy)
                            start <= 1'b1;
                    end
                    8'h04: if (reg_wdata[1]) done <= 1'b0;   // STATUS: W1C
                    8'h08: addr_a <= reg_wdata;
                    8'h0C: addr_b <= reg_wdata;
                    8'h10: addr_c <= reg_wdata;
                    8'h14: dim_m  <= reg_wdata;
                    8'h18: dim_n  <= reg_wdata;
                    8'h1C: dim_k  <= reg_wdata;
                    default: ;                       // CYCLES e INFO: só leitura
                endcase
            end

            if (state == FINISH) done <= 1'b1;       // a FSM avisa o fim
        end
    end

    always @(*) begin
        case (reg_addr)
            8'h00:   reg_rdata = {30'b0, irq_en, 1'b0};
            8'h04:   reg_rdata = {30'b0, done, busy};
            8'h08:   reg_rdata = addr_a;
            8'h0C:   reg_rdata = addr_b;
            8'h10:   reg_rdata = addr_c;
            8'h14:   reg_rdata = dim_m;
            8'h18:   reg_rdata = dim_n;
            8'h1C:   reg_rdata = dim_k;
            8'h20:   reg_rdata = cycles;
            8'h24:   reg_rdata = ARRAY_SIZE;
            default: reg_rdata = 32'b0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst)        cycles <= 0;
        else if (start) cycles <= 0;            // nova operação: zera
        else if (busy)  cycles <= cycles + 1;   // conta enquanto trabalha
    end

    assign irq = done & irq_en;

    
    always @(posedge clk or posedge rst) begin: state_memory
        if(rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin: next_state_logic
        case (state)
            IDLE: begin
                if (start)
                    next_state = LD_A_REQ;
                else
                    next_state = IDLE;
            end
            LD_A_REQ: begin
                next_state = LD_A_WR;
            end
            LD_A_WR: begin
                if (last_load)
                    next_state = LD_B_REQ;
                else
                    next_state = LD_A_REQ;
            end
            LD_B_REQ: begin
                next_state = LD_B_WR;
            end
            LD_B_WR: begin
                if (last_load)
                    next_state = RUN_START;
                else
                    next_state = LD_B_REQ;
            end
            RUN_START: begin
                next_state = RUN_WAIT;
            end
            RUN_WAIT: begin
                if (acc_done) begin
                    if(last_chunk)
                        next_state = ST_C;
                    else
                        next_state = LD_A_REQ;
                end else
                    next_state = RUN_WAIT;
            end
            ST_C: begin
                if (last_acc) begin
                    if (last_block)
                        next_state = FINISH;
                    else
                        next_state = LD_A_REQ;
                end else
                    next_state = ST_C;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(*) begin: output_logic_comb
        memb_addr = 0;
        buf_we = 0;
        buf_sel = 0;
        buf_bank = 0;
        buf_addr = 0;
        buf_wdata = 0;
        acc_start = 0;
        acc_clear = 0;
        acc_klen = 0;
        c_sel = 0;
        memb_we = 0;
        memb_wdata = 0;
        case (state)
            LD_A_REQ: begin
                memb_addr = a_byte[11:2];
            end
            LD_A_WR: begin
                buf_we = 1;
                buf_sel = 0;
                buf_bank = b;
                buf_addr = p;
                buf_wdata = memb_rdata[8*off_r +: 8];
            end
            LD_B_REQ: begin
                memb_addr = b_byte[11:2];
            end
            LD_B_WR: begin
                buf_we = 1;
                buf_sel = 1;
                buf_bank = b;
                buf_addr = p;
                buf_wdata = memb_rdata[8*off_r +: 8];
            end
            RUN_START: begin
                acc_start = 1;
                acc_clear = (k0 == 0);
                acc_klen = klen;
            end
            ST_C: begin
                c_sel = r*ARRAY_SIZE + c;
                memb_addr = c_byte[11:2];
                memb_we = 1;
`ifdef INJECT_BUG
                // Falha proposital para a demonstração (ativada com +define+INJECT_BUG):
                // o primeiro elemento de cada bloco de C é gravado com +1.
                memb_wdata = (r == 0 && c == 0) ? c_data + 1 : c_data;
`else
                memb_wdata = c_data;
`endif
            end
            default: ;
        endcase
    end

    always @(posedge clk or posedge rst) begin: output_logic_seq
        if(rst) begin
            ti <= 0;
            tj <= 0;
            k0 <= 0;
            b <= 0;
            p <= 0;
            r <= 0;
            c <= 0;
            off_r <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        ti <= 0;
                        tj <= 0;
                        k0 <= 0;
                        b <= 0;
                        p <= 0;
                        r <= 0;
                        c <= 0;
                    end
                end
                LD_A_REQ: begin
                    off_r <= a_byte[1:0];
                end
                LD_A_WR: begin
                    if (p == (klen - 1)) begin
                        p <= 0;
                        if (b == ARRAY_SIZE - 1) begin
                            b <= 0;
                        end else begin
                            b <= b + 1;
                        end
                    end else begin
                        p <= p + 1;
                    end
                end
                LD_B_REQ: begin
                    off_r <= b_byte[1:0];
                end
                LD_B_WR: begin
                    if (p == (klen - 1)) begin
                        p <= 0;
                        if (b == ARRAY_SIZE - 1) begin
                            b <= 0;
                        end else begin
                            b <= b + 1;
                        end
                    end else begin
                        p <= p + 1;
                    end
                end
                RUN_WAIT: begin
                    if (acc_done && !last_chunk) begin
                        k0 <= k0 + BUF_DEPTH;
                    end
                end
                ST_C: begin
                    if (c == ARRAY_SIZE - 1) begin
                        c <= 0;
                        if (r == ARRAY_SIZE - 1) begin
                            r <= 0;
                        end else begin
                            r <= r + 1;
                        end
                    end else begin
                        c <= c + 1;
                    end

                    if (last_acc) begin
                        k0 <= 0;
                        if ((tj + ARRAY_SIZE) < dim_n) begin
                            tj <= tj + ARRAY_SIZE;
                        end else begin
                            tj <= 0;
                            ti <= ti + ARRAY_SIZE;
                        end
                    end
                end
                default: ;
            endcase
        end
    end

    endmodule