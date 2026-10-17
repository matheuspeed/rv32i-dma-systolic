module imem (
    input wire [31:0] addr,
    output wire [31:0] inst
);
    reg [31:0] mem [0:255];

    initial begin
        $readmemh("imem.hex", mem);
    end

    // Endereçamento por palavra (ignora os 2 bits menos significativos)
    assign inst = mem[addr[31:2]];
endmodule