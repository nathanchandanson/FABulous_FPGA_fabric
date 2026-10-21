// SPDX-FileCopyrightText: © 2025 Leo Moser <leo.moser@pm.me>
// SPDX-License-Identifier: Apache-2.0

module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);

    // SRAM
    parameter NUM_SRAM = 7;
    wire [32-1:0] DOUT_SRAMS [NUM_SRAM];
    reg  [32-1:0] DOUT;

    // Peripheral
    wire        REQ;
    wire        WE;
    wire [3: 0] BE;
    wire [23:0] ADDR;
    wire [31:0] WDATA;

    wire        GNT;
    reg         RVALID;
    wire [31:0] RDATA;

    wire [2:0] select_sram;
    reg  [2:0] select_sram_d;
    assign select_sram = ADDR[12:10];

    genvar i;
    generate
        for (i=0; i<NUM_SRAM; i = i + 1) begin : gen_srams
            // SRAM
            IHP_SRAM_1024x32_wrapper sram (
                .A_ADDR   (ADDR[9:0]),
                .A_BM     ({{8{BE[3]}}, {8{BE[2]}}, {8{BE[1]}}, {8{BE[0]}}}),
                .A_DIN    (WDATA),
                .A_WEN    (WE),
                .A_MEN    (select_sram == i && REQ),
                .A_REN    (!WE),
                .A_DOUT   (DOUT_SRAMS[i])
            );
        end
    endgenerate

    always @(posedge clk) begin
        RVALID <= REQ;
        select_sram_d <= select_sram;
    end

    always @(*) begin
        DOUT = 0;
        if (select_sram_d < NUM_SRAM) begin
            DOUT = DOUT_SRAMS[select_sram_d];
        end
    end

    assign RDATA = DOUT;
    assign GNT = 1'b1;

    OBI_SLAVE_wrapper i_OBI_SLAVE_wrapper (
        .REQ(REQ),
        .WE(WE),
        .BE(BE),
        .ADDR(ADDR),
        .WDATA(WDATA),

        .GNT(GNT),
        .RVALID(RVALID),
        .RDATA(RDATA)
    );
    // OBI_A_CHANNEL_wrapper OBI_A_CHANNEL_wrapper_inst (
    //     .REQ(REQ),
    //     .WE(WE),
    //     .BE(BE),
    //     .ADDR(ADDR),
    //     .WDATA(WDATA),
    //     .GNT(GNT)
    // );
    // OBI_R_CHANNEL_wrapper OBI_R_CHANNEL_wrapper_inst (
    //     .RVALID(RVALID),
    //     .RDATA(RDATA)
    // );

    assign io_oeb = '0;
    // assign io_out = { select_sram_d, select_sram, REQ, WE, BE, GNT, RVALID };
    assign io_out = 32'hCAFECAFE;
endmodule
