//
// Addition of two values from memory
//
// 1. Take two addresses stored in RS1 and RS2
// 2. Retrieve the values at these addresses
// 3. Add them
// 4. Write the result to RD
//

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
    reg  [31:0] rega_q, regb_q;
    reg         instr_killed;
    wire [31:0] res_o;
    wire        unknown_instr_o;

    ///////////////////////
    // Coprocessor State //
    ///////////////////////
    localparam StWaiting  = 0,
               StExecute  = 1,
               StResult   = 2;
    reg  [1:0] state_d, state_q;

    // Sequential update
    reg is_resetting;
    always @(posedge clk) begin
        if (io_in[0]) begin
            is_resetting <= 1'b1;
            state_q <= StWaiting;
            instr_killed <= 1'b0;
            instr_q <= 32'd0;
            id_instr_q <= 4'd0;
            rega_q <= 32'd0;
            regb_q <= 32'd0;
        end else begin
            is_resetting <= 1'b0;
            state_q <= state_d;
            if (state_q == StWaiting && issue_valid_i) begin
                instr_q    <= issue_req_instr_i;
                id_instr_q <= issue_req_id_i;
            end
            if (state_q == StWaiting && register_valid_i && register_id_i == issue_req_id_i) begin
                if (register_rs_valid_i[0]) rega_q <= register_rsa_i;
                if (register_rs_valid_i[1]) regb_q <= register_rsb_i;
            end
            if (commit_kill_i && state_q == StWaiting && commit_valid_i && commit_id_i == issue_req_id_i) begin
                instr_killed <= 1'b1;
            end else if (state_q == StWaiting) begin
                instr_killed <= 1'b0;
            end
        end
    end

    // State handling
    always @(*) begin
        state_d = state_q;
        case(state_q)
            StWaiting: begin
                if (!is_resetting && issue_valid_i && issue_resp_accept_o) state_d = StExecute;
            end
            StExecute: begin
                // NOTE: Single cycle instruction: no computing to wait for
                if (!instr_killed) state_d = StResult;
                else               state_d = StWaiting;
            end
            StResult: begin
                if (result_ready_i) state_d = StWaiting;
            end
            default: state_d = StWaiting;
        endcase
    end

    // Output assignement
    always @(*) begin
        // CVXIF Issue and register interface
        issue_ready_o              = (!is_resetting && state_q == StWaiting);
        issue_resp_accept_o        = (!is_resetting && state_q == StWaiting
                                        && !unknown_instr_o);
        issue_resp_writeback_o     = 1'b1;          // Writeback
        issue_resp_register_read_o = 3'b111;        // Read both registers
        register_ready_o           = issue_ready_o; // For CVE2, issue and register are done at the same pipeline stage
        // CVXIF Result interface
        result_valid_o             = (state_q == StResult && !instr_killed);
        result_id_o                = id_instr_q;
        result_data_o              = res_o;
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

    // compute module
    rv32_zbkb_top #(
        .XLEN(32),
        .ILEN(32)
    ) i_rv32_zbkb_top (
        .instr_i((state_q == StWaiting) ? issue_req_instr_i : instr_q),
        .rega_i(rega_q),
        .regb_i(regb_q),

        .res_o,
        .unknown_instr_o
    );

    assign io_oeb = '0;
    assign io_out = { 1'b0, instr_q[31:25], 1'b0, instr_q[14:12], 1'b0, instr_q[6:0], 2'd0, unknown_instr_o, instr_killed, 2'd0, state_q };
    // assign io_out = 28'hEADBEEF;
endmodule
