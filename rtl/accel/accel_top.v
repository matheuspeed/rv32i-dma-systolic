module accel_top #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_W = 8,
    parameter ACC_W = 32,
    parameter BUF_DEPTH = 16    
)(
    input clk, rst,
    input buf_we,
    input buf_sel,  //0 = buffer A, 1 = buffer B
    input [$clog2(ARRAY_SIZE)-1:0] buf_bank,
    input [$clog2(BUF_DEPTH)-1:0] buf_addr,
    input [DATA_W-1:0] buf_wdata,
    input acc_start,
    input acc_clear,
    input [$clog2(BUF_DEPTH):0] acc_klen,
    output wire acc_busy,
    output reg acc_done,
    input [($clog2(ARRAY_SIZE*ARRAY_SIZE))-1:0] c_sel,
    output wire [ACC_W-1:0] c_data
);

    localparam T_W = $clog2(BUF_DEPTH + 2*ARRAY_SIZE);

    localparam  IDLE = 2'd0,
                CLEAR = 2'd1,
                RUN = 2'd2;

    reg [1:0] state, next_state;

    reg [DATA_W-1:0] buf_a [0:ARRAY_SIZE*BUF_DEPTH-1];
    reg [DATA_W-1:0] buf_b [0:ARRAY_SIZE*BUF_DEPTH-1];

    reg [T_W-1:0]                          t;

    reg  [$clog2(BUF_DEPTH):0]             klen_r;     // cópia do acc_klen
    reg                                    clear_r;    // cópia do acc_clear
    reg  [ARRAY_SIZE*DATA_W-1:0]           a_col, b_row;
    wire [ARRAY_SIZE*ARRAY_SIZE*ACC_W-1:0] acc_flat;
    wire                                   arr_clear;  // clear que vai para a malha
    wire [T_W-1:0]                         LAST = klen_r + 2*(ARRAY_SIZE-1) - 1;


    systolic_array # (
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_W(DATA_W),
    .ACC_W(ACC_W)
  )
  systolic_array_inst (
    .clk(clk),
    .rst(rst),
    .clear(arr_clear),
    .a_col(a_col),
    .b_row(b_row),
    .acc_flat(acc_flat)
  );

    always @(posedge clk) begin
        if(buf_we) begin
            if(!buf_sel)
                buf_a[buf_bank*BUF_DEPTH + buf_addr] <= buf_wdata;
            else
                buf_b[buf_bank*BUF_DEPTH + buf_addr] <= buf_wdata;
        end
    end

    integer i;
    always @(*) begin
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            if (state == RUN && t < klen_r) begin
                a_col[i*DATA_W +: DATA_W] = buf_a[i*BUF_DEPTH + t];
                b_row[i*DATA_W +: DATA_W] = buf_b[i*BUF_DEPTH + t];
            end else begin
                a_col[i*DATA_W +: DATA_W] = {DATA_W{1'b0}};
                b_row[i*DATA_W +: DATA_W] = {DATA_W{1'b0}};
            end
        end
    end

    always @(posedge clk or posedge rst) begin: state_memory
        if(rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin: next_state_logic
        case(state)
            IDLE:   begin
                if(acc_start)
                    next_state = CLEAR;
                else
                    next_state = IDLE;
            end
            CLEAR:  begin
                next_state = RUN;
            end
            RUN:    begin
                if(t == LAST)
                    next_state = IDLE;
                else
                    next_state = RUN;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin: output_logic
        if (rst) begin
            t <= 0;
            klen_r <= 0;
            clear_r <= 0;
            acc_done <= 0;
        end else begin
            acc_done <= 1'b0;
            case(state)
                IDLE:   begin
                    if (acc_start) begin
                        clear_r <= acc_clear;
                        klen_r <= acc_klen;
                    end
                end
                CLEAR:  begin
                    t <= 0;
                end
                RUN:    begin
                    t <= t + 1'b1;
                    if (t == LAST)
                        acc_done <= 1'b1;
                end
                default: begin
                    t <= 0;
                end
            endcase
        end
    end



    assign c_data = acc_flat[c_sel*ACC_W +: ACC_W];
    assign acc_busy  = (state != IDLE);
    assign arr_clear = (state == CLEAR) && clear_r;

endmodule