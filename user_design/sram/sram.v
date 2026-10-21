// SPDX-FileCopyrightText: © 2025 Leo Moser <leo.moser@pm.me>
// SPDX-License-Identifier: Apache-2.0

module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);

    wire [31:0] sram0_do, sram1_do, sram2_do, sram3_do;

    reg [15:0] sram_do;
    wire sram0_en, sram1_en, sram2_en, sram3_en;

    assign sram0_en = io_in[25:24] == 2'd0;
    assign sram1_en = io_in[25:24] == 2'd1;
    assign sram2_en = io_in[25:24] == 2'd2;
    assign sram3_en = io_in[25:24] == 2'd3;

    IHP_SRAM_1024x32_wrapper sram0 (
        .A_ADDR    (io_in[23:16]),
        .A_BM      (32'hFFFFFFFF),
        .A_DIN     ({16'd0, io_in[15:0]}),
        .A_WEN     (io_in[26]),
        .A_MEN     (sram0_en),
        .A_REN     (io_in[27]),
        .A_DOUT    (sram0_do)
    );

    IHP_SRAM_1024x32_wrapper sram1 (
        .A_ADDR    (io_in[23:16]),
        .A_BM      (32'hFFFFFFFF),
        .A_DIN     ({io_in[15:8], 16'd0, io_in[7:0]}),
        .A_WEN     (io_in[26]),
        .A_MEN     (sram1_en),
        .A_REN     (io_in[27]),
        .A_DOUT    (sram1_do)
    );

    IHP_SRAM_1024x32_wrapper sram2 (
        .A_ADDR    (io_in[23:16]),
        .A_BM      (32'hFFFFFFFF),
        .A_DIN     ({io_in[15:0], 16'd0}),
        .A_WEN     (io_in[26]),
        .A_MEN     (sram2_en),
        .A_REN     (io_in[27]),
        .A_DOUT    (sram2_do)
    );

    IHP_SRAM_1024x32_wrapper sram3 (
        .A_ADDR    (io_in[23:16]),
        .A_BM      (32'hFFFFFFFF),
        .A_DIN     ({io_in[15:8], 8'd0, io_in[7:0], 8'd0}),
        .A_WEN     (io_in[26]),
        .A_MEN     (sram3_en),
        .A_REN     (io_in[27]),
        .A_DOUT    (sram3_do)
    );

    always @(*) begin
        case (io_in[25:24])
            2'd0:  sram_do = sram0_do[15:0];
            2'd1:  sram_do = {sram1_do[31:24], sram1_do[7:0]};
            2'd2:  sram_do = sram2_do[31:16];
            2'd3:  sram_do = {sram3_do[31:24], sram3_do[15:8]};
            default: sram_do = 'x;
        endcase
    end

    assign io_out = {12'd0, sram_do};
endmodule
