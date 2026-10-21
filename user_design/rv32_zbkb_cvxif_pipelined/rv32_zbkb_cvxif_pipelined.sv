import rv32_zbkb_pkg::*;

module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);
    /////////////////////
    // CVXIF interface //
    /////////////////////
    // Issue interface
    wire        issue_valid_i;
    reg         issue_ready_o;
    wire [31:0] issue_req_instr_i;
    wire [ 3:0] issue_req_id_i;
    reg         issue_resp_accept_o;
    reg         issue_resp_writeback_o;
    reg  [ 2:0] issue_resp_register_read_o;
    // Register interface
    wire        register_valid_i;
    reg         register_ready_o;
    wire [ 3:0] register_id_i;
    wire [31:0] register_rsa_i;
    wire [31:0] register_rsb_i;
    wire [ 1:0] register_rs_valid_i;
    // Commit interface
    wire        commit_valid_i;
    wire [ 3:0] commit_id_i;
    wire        commit_kill_i;
    // Result interface
    reg         result_valid_o;
    wire        result_ready_i;
    reg  [ 3:0] result_id_o;
    reg  [31:0] result_data_o;
    reg  [ 4:0] result_rd_o;
    reg         result_we_o;

    // Synchronous latching of the important input values
    reg  [31:0] instr_q;
    reg  [3:0]  id_instr_q;
    // reg  [31:0] rega_q, regb_q, res_q;
    reg         instr_killed, instr_accepted;
    // wire [31:0] res_d;

    // rv32_zbkb
    // Decoding
    wire   unknown_instr_d;
    assign unknown_instr_d = (op_o_dec_d == rv32_zbkb_pkg::OP_UNKNOWN);
    // Executing
    rv32_zbkb_pkg::op_e op_o_dec_d, op_o_dec_q;
    logic [31:0]        opa_o_dec_d, opb_o_dec_d, opa_o_dec_q, opb_o_dec_q;
    logic [31:0]        result;


    ///////////////////////
    // Coprocessor State //
    ///////////////////////
    // Sequential update
    reg is_resetting;
    always @(posedge clk) begin
        if (io_in[0]) begin
            is_resetting <= 1'b1;
            instr_killed <= 1'b0;
            instr_accepted <= 1'b0;
            instr_q <= 32'd0;
            id_instr_q <= 4'd0;
            op_o_dec_q <= rv32_zbkb_pkg::OP_UNKNOWN;
            opa_o_dec_q <= '0;
            opb_o_dec_q <= '0;
        end else begin
            is_resetting <= 1'b0;

            if (instr_accepted && result_ready_i) begin
                instr_accepted <= 1'b0;
            end
            if (issue_valid_i && register_valid_i && register_rs_valid_i[0] && register_rs_valid_i[1]) begin
                instr_q    <= issue_req_instr_i;
                id_instr_q <= issue_req_id_i;
                op_o_dec_q <= op_o_dec_d;
                opa_o_dec_q <= opa_o_dec_d;
                opb_o_dec_q <= opb_o_dec_d;
                instr_accepted <= 1'b1;
            end
            if (commit_kill_i && commit_valid_i && commit_id_i == issue_req_id_i) begin
                instr_killed <= 1'b1;
            end else begin
                instr_killed <= 1'b0;
            end
        end
    end

    // Output assignement
    always @(*) begin
        // CVXIF Issue and register interface
        issue_ready_o              = !is_resetting;
        issue_resp_accept_o        = issue_ready_o & !unknown_instr_d;
        issue_resp_writeback_o     = 1'b1;          // Writeback
        issue_resp_register_read_o = 3'b111;        // Read both registers
        register_ready_o           = issue_ready_o; // For CVE2, issue and register are done at the same pipeline stage
        // CVXIF Result interface
        result_valid_o             = (op_o_dec_q != rv32_zbkb_pkg::OP_UNKNOWN && !instr_killed && instr_accepted && result_ready_i);
        result_id_o                = id_instr_q;
        result_data_o              = result;
        result_rd_o                = instr_q[11:7];
        result_we_o                = 1'b1;          // Always write the computed value
    end

    ////////////////////
    // Instantiations //
    ////////////////////
    CVXIF_ISSUE_wrapper cvxif_issue_inst(
        .ISSUE_VALID(issue_valid_i),
        .ISSUE_READY(issue_ready_o),
        .ISSUE_REQ_INSTR(issue_req_instr_i),
        .ISSUE_REQ_ID(issue_req_id_i),
        .ISSUE_RESP_ACCEPT(issue_resp_accept_o),
        .ISSUE_RESP_WRITEBACK(issue_resp_writeback_o),
        .ISSUE_RESP_REGISTER_READ(issue_resp_register_read_o)
    );

    CVXIF_REGISTER2_wrapper cvxif_register2_inst (
        .REGISTER_VALID(register_valid_i),
        .REGISTER_READY(register_ready_o),

        .REGISTER_ID(register_id_i),
        .REGISTER_RSA(register_rsa_i),
        .REGISTER_RSB(register_rsb_i),
        .REGISTER_RS_VALID(register_rs_valid_i)
    );

    CVXIF_COMMIT_RESULT_WRAPPER cvxif_commit_result_inst (
        // Commit interface
        .COMMIT_VALID(commit_valid_i),
        .COMMIT_ID(commit_id_i),
        .COMMIT_KILL(commit_kill_i),
        // Result interface
        .RESULT_VALID(result_valid_o),
        .RESULT_READY(result_ready_i),
        .RESULT_ID(result_id_o),
        .RESULT_DATA(result_data_o),
        .RESULT_RD(result_rd_o),
        .RESULT_WE(result_we_o)
    );

    // rv32_zbkb
    rv32_zbkb_decoder #(
        .XLEN(32),
        .ILEN(32)
    ) i_dec (
        .instr_i(issue_req_instr_i),
        .rega_i(register_rsa_i),
        .regb_i(register_rsb_i),
        .op_o(op_o_dec_d),
        .opa_o(opa_o_dec_d),
        .opb_o(opb_o_dec_d)
    );

    rv32_zbkb_alu #(
        .XLEN(32)
    ) i_alu (
        .op_i(op_o_dec_q),
        .opa_i(opa_o_dec_q),
        .opb_i(opb_o_dec_q),

        .res_o(result)
    );

    // // NOTE: Really ugly but could not find an alternative
    // // Compute result
    // rv32_zbkb_top #(
    //     .XLEN(32),
    //     .ILEN(32)
    // ) i_rv32_zbkb_top (
    //     // .instr_i(instr_q),
    //     .instr_i(issue_req_instr_i),
    //     .rega_i(rega_q),
    //     .regb_i(regb_q),
    //
    //     .res_o(res_d),
    //     // .unknown_instr_o()
    //     .unknown_instr_o(unknown_instr_d)
    // );
    // // Accept instruction or not
    // rv32_zbkb_top #(
    //     .XLEN(32),
    //     .ILEN(32)
    // ) i_rv32_zbkb_top_accept (
    //     .instr_i(issue_req_instr_i),
    //     .rega_i(),
    //     .regb_i(),
    //
    //     .res_o(),
    //     .unknown_instr_o(unknown_instr_d)
    // );

    assign io_oeb = '0;
    // assign io_out = { res_d[23:0], 2'd0, unknown_instr_o, instr_killed };
    assign io_out = { opa_o_dec_q[11:0], opb_o_dec_q[11:0], 1'd0, unknown_instr_d, instr_accepted, instr_killed };
    // assign io_out = { 1'b0, instr_q[31:25], 1'b0, instr_q[14:12], 1'b0, instr_q[6:0], 3'd0, unknown_instr_o, 3'd0, instr_killed };
    // assign io_out = 28'hEADBEEF;
endmodule
