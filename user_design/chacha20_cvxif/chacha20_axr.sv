module chacha20_axr (
    input  logic [          31:0] x_i,
    input  logic [          31:0] y_i,
    input  logic [          31:0] z_i,
    input  logic [$clog2(16)-1:0] shamt_i,    // Biggest rotate left by 16

    input  logic [          31:0] x_o,
    input  logic [          31:0] z_o
);

    logic [31:0] x_temp, z_temp_0, z_temp_1;

    always_comb begin
        x_temp   = x_i + y_i;
        z_temp_0 = z_i ^ x_temp;
        z_temp_1 = ( z_temp_0 << shamt_i | z_temp_0 >> (32-shamt_i));

        x_o = x_temp;
        z_o = z_temp_1;
    end

endmodule
