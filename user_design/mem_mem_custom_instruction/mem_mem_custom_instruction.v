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
    reg [31:0] instr_q;
    reg [3:0]  id_instr_q;
    reg [31:0] addr1_q, addr2_q;    // Address of the two values
    reg        instr_killed;

    localparam OPCODE_XIF = 7'h5B;

    //////////////////////////
    // OBI Master interface //
    //////////////////////////
    reg         obi_req_o;
    reg         obi_we_o;
    reg  [3:0]  obi_be_o;
    reg  [23:0] obi_addr_o;
    reg  [31:0] obi_wdata_o;

    wire        obi_gnt_i;
    wire        obi_rvalid_i;
    wire [31:0] obi_rdata_i;

    // Values
    reg         obi_granted;
    reg         obi_current_request;  // Track which value we are requesting
    reg  [31:0] opa_q, opb_q;
    wire [31:0] result_data;
    assign result_data = opa_q + opb_q;

    ///////////////////////
    // Coprocessor State //
    ///////////////////////
    localparam StWaiting  = 0,
               StLoadData = 1,
               StExecute  = 2,
               StResult   = 3;
    reg  [1:0] state_d, state_q;

    // Sequential update
    reg is_resetting;
    always @(posedge clk) begin
        if (io_in[0]) begin
            is_resetting <= 1'b1;
            state_q <= StWaiting;
            instr_killed <= 1'b0;
        end else begin
            is_resetting <= 1'b0;
            state_q <= state_d;
            if (state_q == StWaiting && issue_valid_i) begin
                instr_q    <= issue_req_instr_i;
                id_instr_q <= issue_req_id_i;
            end
            if (state_q == StWaiting && register_valid_i && register_id_i == issue_req_id_i) begin
                if (register_rs_valid_i[0]) addr1_q <= register_rsa_i;
                if (register_rs_valid_i[1]) addr2_q <= register_rsb_i;
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
                if (!is_resetting && issue_valid_i) state_d = StLoadData;
            end
            StLoadData: begin
                if (obi_current_request == 1'b1 && obi_rvalid_i && obi_granted) state_d = StExecute;
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
                                        && issue_req_instr_i[6:0] == OPCODE_XIF);
        issue_resp_writeback_o     = 1'b0;          // No writeback here
        issue_resp_register_read_o = 3'b111;        // Read both registers
        register_ready_o           = issue_ready_o; // For CVE2, issue and register are done at the same pipeline stage
        // CVXIF Result interface
        result_valid_o             = (state_q == StResult && !instr_killed);
        result_id_o                = id_instr_q;
        result_data_o              = result_data;
        result_rd_o                = instr_q[11:7];
        result_we_o                = 1'b1;          // Always write the computed value
    end

    // Sequential update
    always @(posedge clk) begin
        if (io_in[0]) begin
            obi_granted         <= 1'b0;
            obi_current_request <= 1'b0;
            opa_q               <= 32'd0;
            opb_q               <= 32'd0;
        end else begin
            if (obi_req_o && obi_gnt_i) obi_granted <= 1'b1;

            if (obi_granted && obi_rvalid_i) begin
                obi_granted <= 1'b0;
                if (obi_current_request == 1'd0) begin
                    obi_current_request <= 1'd1;
                    opa_q               <= obi_rdata_i;
                end else begin
                    obi_current_request <= 1'd0;
                    opb_q               <= obi_rdata_i;
                end
            end
        end
    end

    // Combinational assignment
    always @(*) begin
        // OBI
        obi_req_o   = (state_q == StLoadData && !obi_granted);
        obi_we_o    = 1'b0;                         // Never write to memory
        obi_be_o    = 4'b1;                         // Read whole word
        obi_addr_o  = (obi_current_request) ? addr1_q : addr2_q;
        obi_wdata_o = 32'b0;                        // Never write to memory
    end



    // Instantiation of the interfaces
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

    OBI_MASTER_wrapper obi_master_wrapper_inst (
        .REQ(obi_req_o),
        .WE(obi_we_o),
        .BE(obi_be_o),
        .ADDR(obi_addr_o),
        .WDATA(obi_wdata_o),

        .GNT(obi_gnt_i),
        .RVALID(obi_rvalid_i),
        .RDATA(obi_rdata_i)
    );

    assign io_oeb = '0;
    // assign io_out = { op2_d[11:0], op2_q[11:0], is_instr_killed, 1'd0, state_q};
    assign io_out = 28'hEADBEEF;
endmodule
