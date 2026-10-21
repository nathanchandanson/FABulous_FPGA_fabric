`timescale 1ps/1ps

module instr_reg_dec (
    input logic tck_i,
    input logic tdi_i,
    output logic tdo_o,
    input logic trst_ni,

    input jtag_pkg::operation_t op_i,
    input jtag_pkg::register_t reg_i,

    output jtag_pkg::dr_t dr_o,
    output jtag_pkg::instr_t instr_o
);

    /////////////////
    // IR Register //
    /////////////////
    logic [jtag_pkg::IR_SIZE-1:0] ir_shift;
    logic [jtag_pkg::IR_SIZE-1:0] ir_parallel_clocked;
    logic [jtag_pkg::IR_SIZE-1:0] ir_parallel;

    // Updating Shift register stage
    always_ff @(posedge tck_i) begin
        if (reg_i == jtag_pkg::REG_IR) begin
            case (op_i)
                jtag_pkg::OP_CAPTURE: ir_shift <= {{(jtag_pkg::IR_SIZE-2){1'b0}}, 2'b01};
                jtag_pkg::OP_SHIFT: begin
                    ir_shift <= {tdi_i, ir_shift[jtag_pkg::IR_SIZE-1:1]};
                end

                default: ir_shift <= ir_shift;
            endcase
        end else ir_shift <= ir_shift;
    end

    always_ff @(negedge tck_i) tdo_o <= ir_shift[0];

    // Latching until UpdateIR or TestLogicReset states
    // Latched at falling edge of tck
    always_ff @(negedge tck_i) begin
        if (op_i == jtag_pkg::OP_UPDATE && reg_i == jtag_pkg::REG_IR) ir_parallel_clocked <= ir_shift;
        else if (op_i == jtag_pkg::OP_TEST_LOGIC_RESET) ir_parallel_clocked <= jtag_pkg::INSTR_IDCODE;
        else ir_parallel_clocked <= ir_parallel_clocked;
    end
    // Update latched output asynchronously when trst low
    assign ir_parallel = (!trst_ni) ? jtag_pkg::INSTR_IDCODE : ir_parallel_clocked;


    /////////////
    // Decoder //
    /////////////
    always_comb begin
        dr_o = jtag_pkg::DR_BYPASS;    // If instruction not recognised : bypass
        instr_o = jtag_pkg::INSTR_BYPASS;

        case (ir_parallel)
            jtag_pkg::INSTR_BYPASS: begin
                dr_o = jtag_pkg::DR_BYPASS;
                instr_o = jtag_pkg::INSTR_BYPASS;
            end
            jtag_pkg::INSTR_SAMPLE_PRELOAD: begin
                dr_o = jtag_pkg::DR_BSR;
                instr_o = jtag_pkg::INSTR_SAMPLE_PRELOAD;
            end
            jtag_pkg::INSTR_EXTEST: begin
                dr_o = jtag_pkg::DR_BSR;
                instr_o = jtag_pkg::INSTR_EXTEST;
            end
            jtag_pkg::INSTR_IDCODE: begin
                dr_o = jtag_pkg::DR_ID;
                instr_o = jtag_pkg::INSTR_IDCODE;
            end
            jtag_pkg::INSTR_CONFIG: begin
                dr_o = jtag_pkg::DR_CONFIG;
                instr_o = jtag_pkg::INSTR_CONFIG;
            end

            default: begin
                dr_o = jtag_pkg::DR_BYPASS;    // If instruction not recognised : bypass
                instr_o = jtag_pkg::INSTR_BYPASS;
            end
        endcase
    end

endmodule
