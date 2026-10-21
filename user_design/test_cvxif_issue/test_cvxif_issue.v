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

    wire        ISSUE_VALID;
    wire        ISSUE_READY;
    // issue_req
    wire [31:0] ISSUE_REQ_INSTR;
    wire [ 3:0] ISSUE_REQ_ID;
    // issue_resp
    wire         ISSUE_RESP_ACCEPT;
    wire         ISSUE_RESP_WRITEBACK;
    wire  [ 2:0] ISSUE_RESP_REGISTER_READ;

    assign ISSUE_READY = counter[0];
    assign ISSUE_RESP_ACCEPT = counter[0];
    assign ISSUE_RESP_WRITEBACK = counter[0];
    assign ISSUE_RESP_REGISTER_READ = counter[2:0];

    assign io_out = { ISSUE_VALID, ISSUE_REQ_INSTR[22:0], ISSUE_REQ_ID };

    CVXIF_ISSUE_wrapper CVXIF_ISSUE_wrapper_inst (
        ////// User design //////
        .ISSUE_VALID(ISSUE_VALID),
        .ISSUE_READY(ISSUE_READY),
        // issue_req
        .ISSUE_REQ_INSTR(ISSUE_REQ_INSTR),
        .ISSUE_REQ_ID(ISSUE_REQ_ID),
        // issue_resp
        .ISSUE_RESP_ACCEPT(ISSUE_RESP_ACCEPT),
        .ISSUE_RESP_WRITEBACK(ISSUE_RESP_WRITEBACK),
        .ISSUE_RESP_REGISTER_READ(ISSUE_RESP_REGISTER_READ)
    );

    assign io_oeb = '0;
endmodule
