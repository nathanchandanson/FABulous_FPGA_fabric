module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);
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
    // ReSULT INTERFACE
    reg         result_valid_o;
    wire        result_ready_i;
    reg  [ 3:0] result_id_o;
    reg  [31:0] result_data_o;
    reg  [ 4:0] result_rd_o;
    reg         result_we_o;

    // R-type instruction decoding
    wire [6:0] opcode_d;
    wire [4:0] rs1_d;
    wire [4:0] rs2_d;
    wire [4:0] rd_d;
    wire [2:0] funct3_d;
    wire [6:0] funct7_d;
    reg  [6:0] opcode_q;
    reg  [4:0] rs1_q;
    reg  [4:0] rs2_q;
    reg  [4:0] rd_q;
    reg  [2:0] funct3_q;
    reg  [6:0] funct7_q;

    assign opcode_d = issue_req_instr_i[6:0];
    assign rs1_d    = issue_req_instr_i[19:15];
    assign rs2_d    = issue_req_instr_i[24:20];
    assign rd_d     = issue_req_instr_i[11:7];
    assign funct3_d = issue_req_instr_i[14:12];
    assign funct7_d = issue_req_instr_i[31:25];

    localparam OPCODE_XIF = 7'h5B;

    // Registers to store values
    wire [31:0] op1_d;
    wire [31:0] op2_d;
    wire [31:0] result_d;
    wire [3:0]  id_d;
    reg  [31:0] op1_q;
    reg  [31:0] op2_q;
    reg  [31:0] result_q;
    reg  [3:0]  id_q;
    reg         is_killed;

    assign op1_d    = register_rsa_i;
    assign op2_d    = register_rsb_i;
    assign result_d = op1_q + op2_q;    // NOTE: Simple addition. Put in always @(posedge clk) for multi-cycle compute.
    assign id_d     = issue_req_id_i;


    // Coprocessor State
    localparam StWaitingReg = 0,
               StExecute    = 1,
               StReturnRes  = 2;
    reg  [1:0] state_d, state_q;
    wire       is_executing;

    assign is_executing = 1'b0;     // Because single cycle instruction

    // Sequential update
    reg is_resetting;
    always @(posedge clk) begin
        if (io_in[0]) begin
            is_resetting <= 1'b1;
            state_q      <= StWaitingReg;

            opcode_q     <= 7'd0;
            rs1_q        <= 5'd0;
            rs2_q        <= 5'd0;
            rd_q         <= 5'd0;
            funct3_q     <= 3'd0;
            funct7_q     <= 7'd0;

            op1_q        <= 32'd0;
            op2_q        <= 32'd0;
            result_q     <= 32'd0;
            id_q         <= 4'd0;

            is_killed    <= 1'b0;
        end else begin
            is_resetting <= 1'b0;
            state_q      <= state_d;

            if (state_q == StWaitingReg && issue_valid_i && register_valid_i && issue_resp_accept_o) begin
                opcode_q     <= opcode_d;
                rs1_q        <= rs1_d;
                rs2_q        <= rs2_d;
                rd_q         <= rd_d;
                funct3_q     <= funct3_d;
                funct7_q     <= funct7_d;
                if (register_rs_valid_i[0]) op1_q <= op1_d;
                if (register_rs_valid_i[1]) op2_q <= op2_d;

                is_killed    <= 1'b0;
            end

            result_q <= result_d;

            if (state_q == StWaitingReg && issue_valid_i) begin
                id_q         <= id_d;
            end

            if (commit_valid_i && commit_id_i == id_q) begin
                if (commit_kill_i) is_killed <= 1'b1;
                else               is_killed <= 1'b0;
            end
        end
    end

    // Output assignement
    always @(*) begin
        issue_ready_o              = 1'b0;
        issue_resp_accept_o        = 1'b0;
        issue_resp_writeback_o     = 1'b1;                      // We want to write to rd
        issue_resp_register_read_o = 3'b011;                    // We want two input registers. NOTE: 3 bits because the issue interface is generic
        register_ready_o           = 1'b0;
        result_valid_o             = 1'b0;
        result_id_o                = id_q;
        result_data_o              = result_q;
        result_rd_o                = rd_q;
        result_we_o                = issue_resp_writeback_o;    // We want two input registers.

        case (state_q)
            StWaitingReg: begin
                if (!is_resetting) begin
                    issue_ready_o       = 1'b1;
                    register_ready_o    = 1'b1;
                    issue_resp_accept_o = (opcode_d == OPCODE_XIF) ? 1'b1 : 1'b0;
                end
            end
            StExecute: begin
            end
            StReturnRes: begin
                result_valid_o      = 1'b1;
            end
        endcase
    end

    // State handling
    always @(*) begin
        state_d = state_q;
        case (state_q)
            StWaitingReg: if (issue_valid_i && register_valid_i && !is_resetting && issue_resp_accept_o) state_d = StExecute;
            StExecute: begin
                if (!is_executing) begin
                    if (is_killed) state_d = StWaitingReg;
                    else           state_d = StReturnRes;
                end
            end
            StReturnRes:  if (result_ready_i) state_d = StWaitingReg;
        endcase
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

    assign io_oeb = '0;
    assign io_out = { op2_d[11:0], op2_q[11:0], is_killed, 1'd0, state_q};
    // assign io_out = 28'hEADBEEF;
endmodule
