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

    // Peripheral
    wire        REQ;
    wire        WE;
    wire [3: 0] BE;
    wire [23:0] ADDR;
    wire [31:0] WDATA;

    wire        GNT;
    wire        RVALID;
    wire [31:0] RDATA;

    assign GNT = counter[0];
    assign RVALID = counter[0];
    assign RDATA = counter;

    assign io_out = { REQ, WE, BE[3:0], ADDR[9:0], WDATA[11:0] };

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

    // assign io_oeb = '0;
    // assign io_out = 32'hCAFECAFE;
endmodule
