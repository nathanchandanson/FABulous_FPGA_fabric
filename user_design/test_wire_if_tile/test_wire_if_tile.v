// SPDX-FileCopyrightText: © 2025 Leo Moser <leo.moser@pm.me>
// SPDX-License-Identifier: Apache-2.0

module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);
    reg [31:0] counter;
    always @(posedge clk) begin
        if (io_in[0]) counter <= 32'b0;
        else counter <= counter + 1'b1;
    end

    wire [31:0] REG1_INA;
    wire [ 7:0] REG1_INB;
    wire [ 7:0] REG1_INC;
    wire [ 3:0] REG1_IND;
    wire [31:0] REG1_OUTA;
    wire [ 7:0] REG1_OUTB;
    wire [ 7:0] REG1_OUTC;
    wire [ 3:0] REG1_OUTD;
    assign REG1_OUTA = counter;
    assign REG1_OUTB = counter[7:0];
    assign REG1_OUTC = counter[7:0];
    assign REG1_OUTD = counter[3:0];

    wire [31:0] REG2_INA;
    wire [ 7:0] REG2_INB;
    wire [ 7:0] REG2_INC;
    wire [ 3:0] REG2_IND;
    wire [31:0] REG2_OUTA;
    wire [ 7:0] REG2_OUTB;
    wire [ 7:0] REG2_OUTC;
    wire [ 3:0] REG2_OUTD;
    assign REG2_OUTA = counter;
    assign REG2_OUTB = counter[7:0];
    assign REG2_OUTC = counter[7:0];
    assign REG2_OUTD = counter[3:0];

    wire [31:0] REG3_INA;
    wire [ 7:0] REG3_INB;
    wire [ 7:0] REG3_INC;
    wire [ 3:0] REG3_IND;
    wire [31:0] REG3_OUTA;
    wire [ 7:0] REG3_OUTB;
    wire [ 7:0] REG3_OUTC;
    wire [ 3:0] REG3_OUTD;
    assign REG3_OUTA = counter;
    assign REG3_OUTB = counter[7:0];
    assign REG3_OUTC = counter[7:0];
    assign REG3_OUTD = counter[3:0];

    WIRE_IF_wrapper WIRE_IF_wrapper_REG1(
        .INA(REG1_INA),
        .INB(REG1_INB),
        .INC(REG1_INC),
        .IND(REG1_IND),

        .OUTA(REG1_OUTA),
        .OUTB(REG1_OUTB),
        .OUTC(REG1_OUTC),
        .OUTD(REG1_OUTD)
    );

    WIRE_IF_wrapper WIRE_IF_wrapper_REG2(
        .INA(REG2_INA),
        .INB(REG2_INB),
        .INC(REG2_INC),
        .IND(REG2_IND),

        .OUTA(REG2_OUTA),
        .OUTB(REG2_OUTB),
        .OUTC(REG2_OUTC),
        .OUTD(REG2_OUTD)
    );

    WIRE_IF_wrapper WIRE_IF_wrapper_REG3(
        .INA(REG3_INA),
        .INB(REG3_INB),
        .INC(REG3_INC),
        .IND(REG3_IND),

        .OUTA(32'd0),
        .OUTB(8'd0),
        .OUTC(8'd0),
        .OUTD(4'd0)
    );

    assign io_oeb = '0;
    assign io_out = {REG1_INA[1:0], REG1_INB[1:0], REG1_INC[1:0], REG1_IND[1:0], 
                     REG2_INA[1:0], REG2_INB[1:0], REG2_INC[1:0], REG2_IND[1:0], 
                     REG3_INA[1:0], REG3_INB[1:0], REG3_INC[1:0], REG3_IND[1:0]};
endmodule
