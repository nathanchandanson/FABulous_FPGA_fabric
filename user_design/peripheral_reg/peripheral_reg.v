// SPDX-FileCopyrightText: © 2025 Leo Moser <leo.moser@pm.me>
// SPDX-License-Identifier: Apache-2.0

module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);

    // SRAM
    parameter NUM_SRAM = 1;
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
    //
    // OBI_R_CHANNEL_wrapper OBI_R_CHANNEL_wrapper_inst (
    //     .RVALID(RVALID),
    //     .RDATA(RDATA)
    // );


    reg [31:0] regs [32];

    assign GNT = 1'b1;

    always @(posedge clk) begin
        RVALID = 1'b0;
        if (REQ) begin
            RVALID = 1'b1;
            if (WE) begin
                if (BE[0]) regs[ADDR[6:2]][ 7: 0] <= WDATA[7 : 0];
                if (BE[1]) regs[ADDR[6:2]][15: 8] <= WDATA[15: 8];
                if (BE[2]) regs[ADDR[6:2]][23:16] <= WDATA[23:16];
                if (BE[3]) regs[ADDR[6:2]][31:24] <= WDATA[31:24];
            end else begin
                RDATA <= regs[ADDR[6:2]];
            end
        end
    end

    assign io_oeb = '0;
    assign io_out = { REQ, WE, GNT, RVALID };
    // assign io_out = 32'hCAFECAFE;
endmodule
