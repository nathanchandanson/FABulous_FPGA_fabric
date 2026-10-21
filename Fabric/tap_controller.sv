`timescale 1ps/1ps

module tap_controller (
    // JTAG Control inputs
    input logic tck_i,
    input logic trst_ni,
    input logic tms_i,

    // Output control signals
    output jtag_pkg::operation_t op_o,
    output jtag_pkg::register_t reg_o
);

    typedef enum {
        TestLogicReset, RunTestIdle,
        SelectDRScan, CaptureDR, ShiftDR, Exit1DR, PauseDR, Exit2DR, UpdateDR,
        SelectIRScan, CaptureIR, ShiftIR, Exit1IR, PauseIR, Exit2IR, UpdateIR
    } state_e;

    state_e state_d, state_q;

    always_comb begin
        unique case (state_q)
            TestLogicReset: begin
                state_d = (tms_i ? TestLogicReset : RunTestIdle);
                op_o    = jtag_pkg::OP_TEST_LOGIC_RESET;
                reg_o   = jtag_pkg::REG_NONE;
            end
            RunTestIdle: begin
                state_d = (tms_i ? SelectDRScan : RunTestIdle);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_NONE;
            end

            SelectDRScan: begin
                state_d = (tms_i ? SelectIRScan : CaptureDR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_DR;
            end
            CaptureDR: begin
                state_d = (tms_i ? Exit1DR : ShiftDR);
                op_o    = jtag_pkg::OP_CAPTURE;
                reg_o   = jtag_pkg::REG_DR;
            end
            ShiftDR: begin
                state_d = (tms_i ? Exit1DR : ShiftDR);
                op_o    = jtag_pkg::OP_SHIFT;
                reg_o   = jtag_pkg::REG_DR;
            end
            Exit1DR: begin
                state_d = (tms_i ? UpdateDR : PauseDR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_DR;
            end
            PauseDR: begin
                state_d = (tms_i ? Exit2DR : PauseDR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_DR;
            end
            Exit2DR: begin
                state_d = (tms_i ? UpdateDR : ShiftDR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_DR;
            end
            UpdateDR: begin
                state_d = (tms_i ? SelectDRScan : RunTestIdle);
                op_o    = jtag_pkg::OP_UPDATE;
                reg_o   = jtag_pkg::REG_DR;
            end

            SelectIRScan: begin
                state_d = (tms_i ? TestLogicReset : CaptureIR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_IR;
            end
            CaptureIR: begin
                state_d = (tms_i ? Exit1IR : ShiftIR);
                op_o    = jtag_pkg::OP_CAPTURE;
                reg_o   = jtag_pkg::REG_IR;
            end
            ShiftIR: begin
                state_d = (tms_i ? Exit1IR : ShiftIR);
                op_o    = jtag_pkg::OP_SHIFT;
                reg_o   = jtag_pkg::REG_IR;
            end
            Exit1IR: begin
                state_d = (tms_i ? UpdateIR : PauseIR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_IR;
            end
            PauseIR: begin
                state_d = (tms_i ? Exit2IR : PauseIR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_IR;
            end
            Exit2IR: begin
                state_d = (tms_i ? UpdateIR : ShiftIR);
                op_o    = jtag_pkg::OP_NONE;
                reg_o   = jtag_pkg::REG_IR;
            end
            UpdateIR: begin
                state_d = (tms_i ? SelectDRScan : RunTestIdle);
                op_o    = jtag_pkg::OP_UPDATE;
                reg_o   = jtag_pkg::REG_IR;
            end

            default:        state_d = TestLogicReset;
        endcase
    end

    always_ff @(posedge tck_i or negedge trst_ni) begin
        if (!trst_ni) begin
            state_q <= TestLogicReset;
        end else begin
            state_q <= state_d;
        end
    end

endmodule
