//
// This design takes a custom instruction that contains pointers to nonce, key
// and data
// 1. Get the CVXIF instruction
// 2. Get the data from RAM using OBI Master
// 3. Compute
// 4. Return to RAM
//

module top(
    input  logic        clk,
    input  logic [27:0] io_in,
    output logic [27:0] io_out,
    output logic [27:0] io_oeb
);

    ////////////////////////
    // Signal definitions //
    ////////////////////////
    /*
     * CVXIF interface
     */
    // Issue interface
    logic        issue_valid_i;
    logic        issue_ready_o;
    logic [31:0] issue_req_instr_i;
    logic [ 3:0] issue_req_id_i;
    logic        issue_resp_accept_o;
    logic        issue_resp_writeback_o;
    logic [ 2:0] issue_resp_register_read_o;
    // Register interface
    logic        register_valid_i;
    logic        register_ready_o;
    logic [ 3:0] register_id_i;
    logic [31:0] register_rsa_i;
    logic [31:0] register_rsb_i;
    logic [ 1:0] register_rs_valid_i;
    // Commit interface
    logic        commit_valid_i;
    logic [ 3:0] commit_id_i;
    logic        commit_kill_i;
    // Result interface
    logic        result_valid_o;
    logic        result_ready_i;
    logic [ 3:0] result_id_o;
    logic [31:0] result_data_o;
    logic [ 4:0] result_rd_o;
    logic        result_we_o;

    /*
     * OBI Master interface
     */
    logic        obi_req_o;
    logic        obi_we_o;
    logic [3:0]  obi_be_o;
    logic [23:0] obi_addr_o;
    logic [31:0] obi_wdata_o;

    logic        obi_gnt_i;
    logic        obi_rvalid_i;
    logic [31:0] obi_rdata_i;

    /*
     * Internal logic
     */
    // Custom instruction encoding:
    // R-type with RS1 the register containing the memory address of out
    // NOTE: With CVE2, issue, register and valid are given at the same time
    localparam CVXIF_OPCODE = 7'b0001011;
    logic        accept_instr;
    logic [31:0] out_ptr;

    assign accept_instr = (issue_valid_i && register_valid_i && commit_valid_i &&
                           issue_req_id_i == register_id_i && issue_req_id_i == commit_id_i &&
                           !commit_kill_i && register_rs_valid_i[0] == 1'b1 &&
                           issue_req_instr_i == CVXIF_OPCODE);

    // FSM definitions
    typedef enum {
        StWaitingCvxif,
        StLoadValues,
        StRoundNCol,
        StRoundNDiag,
        StStoreValues
    } state_e;
    state_e state_d, state_q;
    logic [$clog2(10)-1:0] round_nbr;
    logic mem_state;

    assign mem_state = (state_q == StLoadValues || state_q == StStoreValues);

    // Memory definitions
    logic [          31:0] out_values [16];
    logic [$clog2(16)-1:0] idx_curr_out_value;
    logic [          31:0] addr_curr_out_value;
    logic                  obi_granted;

    assign addr_curr_out_value = out_ptr + (idx_curr_out_value << 2);   // Pointer arithmetic: base + idx*4


    ///////////////////
    // Logic updates //
    ///////////////////
    /*
     * FSM Sequential and combinational updates
     */
    always_ff @(posedge clk) begin
        if (io_in[0]) state_q <= StWaitingCvxif;
        else          state_q <= state_d;
    end

    always_comb begin
        state_d = state_q;

        unique case (state_q)
            StWaitingCvxif: begin
                if (accept_instr) begin
                    state_d = StLoadValues;
                end
            end
            StLoadValues: begin
                if (idx_out_value == 15) state_d = StRoundNCol;
            end
            StRoundNCol: begin
                // TODO:
            end
            StRoundNDiag: begin
                // TODO:
            end
            StStoreValues: begin
                if (idx_out_value == 15) state_d = StWaitingCvxif;
            end
            default: begin
            end
        endcase
    end

    /*
     * Memory Sequential and combinational updates
     */
    always_ff @(posedge clk) begin
        if (io_in[0]) begin
            idx_out_value <= '0;
        end else begin
            if (mem_state) begin
                if (obi_rvalid_i) begin
                    idx_out_value                  <= idx_out_value + 1'b1;
                    out_values[idx_curr_out_value] <= obi_rdata_i;
                end
            end else begin
                idx_out_value <= '0;
            end
        end
    end

    always_comb begin
        obi_req_o   = mem_state && !obi_granted;
        obi_we_o    = (state_q == StStoreValues);
        obi_be_o    = 4'b1111;                      // Read all bytes
        obi_addr_o  = addr_curr_out_value;
        obi_wdata_o = (state_q == StStoreValues) ? out_values[idx_curr_out_value] : '0;
    end

    /*
     * Internal Sequential and combinational updates
     */
    always_ff @(posedge clk) begin
        if (io_in[0]) begin
            out_ptr <= '0;
            obi_granted <= 1'b0;
        end else begin
            if (accept_instr) begin
                out_ptr <= register_rsa_i;
            end

            if (mem_state && obi_granted && obi_rvalid_i) begin // Ready for another one
                obi_granted <= 1'b0;
            end else if (obi_req_o && obi_gnt_i) begin          // Wait for value
                obi_granted <= 1'b1;
            end
        end
    end

    always_comb begin
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
    assign io_out = 28'hEADBEEF;
endmodule
