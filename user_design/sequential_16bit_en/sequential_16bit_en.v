module top(input wire clk, input wire [27:0] io_in, output wire [27:0] io_out, output wire [27:0] io_oeb);
    wire rst = io_in[0];
    wire en = io_in[1];
    reg [27:0] ctr;

    always @(posedge clk) begin
        if (en) begin
            if (rst) ctr <= 0;
            else ctr <= ctr + 1'b1;
        end else ctr <= ctr;
    end

    assign io_out[27:2] = ctr[25:0];
    assign io_oeb = {26'b111111, 2'b0};
endmodule
