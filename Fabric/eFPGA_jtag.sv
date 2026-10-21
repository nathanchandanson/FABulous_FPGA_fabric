`timescale 1ps/1ps

module eFPGA_jtag #(
    parameter int FrameBitsPerRow = 32,
    parameter int IOBPins = 28,
    parameter logic [31:0] IdentificationCode = 32'b0101_1010101010101010_11111111000_1
) (
    input logic tck_i,
    input logic tms_i,
    input logic tdi_i,
    output logic tdo_o,
    input logic trst_ni,

    output logic[IOBPins-1:0] O_fab_o,
    input  logic[IOBPins-1:0] O_top_i,
    input  logic[IOBPins-1:0] I_fab_i,
    output logic[IOBPins-1:0] I_top_o,
    input  logic[IOBPins-1:0] T_fab_i,
    output logic[IOBPins-1:0] T_top_o,

    output logic jtag_programming,
    output logic[FrameBitsPerRow-1:0] bitstream_packet,
    output logic bitstream_strobe
);

    jtag_pkg::operation_t op;
    jtag_pkg::register_t register;
    jtag_pkg::instr_t instr;
    jtag_pkg::dr_t dr;
    logic tdo_dr, tdo_ir;
    assign tdo_o = (register == jtag_pkg::REG_DR) ? tdo_dr : tdo_ir;
    assign jtag_programming = (instr == jtag_pkg::INSTR_CONFIG);

    tap_controller tap_controller_i (
        .tck_i(tck_i),
        .tms_i(tms_i),
        .trst_ni(trst_ni),
        .op_o(op),
        .reg_o(register)
    );

    instr_reg_dec instr_reg_dec_i (
        .tck_i(tck_i),
        .tdi_i(tdi_i),
        .tdo_o(tdo_ir),
        .trst_ni(trst_ni),

        .op_i(op),
        .reg_i(register),

        .dr_o(dr),
        .instr_o(instr)
    );

    data_regs #(
        .FrameBitsPerRow(FrameBitsPerRow),
        .IOBPins(IOBPins),
        .IdentificationCode(IdentificationCode)
    ) data_regs_i (
        .tck_i(tck_i),
        .tdi_i(tdi_i),
        .tdo_o(tdo_dr),
        .trst_ni(trst_ni),

        .op_i(op),
        .reg_i(register),
        .dr_i(dr),
        .instr_i(instr),

        .O_fab_o(O_fab_o),
        .O_top_i(O_top_i),
        .I_fab_i(I_fab_i),
        .I_top_o(I_top_o),
        .T_fab_i(T_fab_i),
        .T_top_o(T_top_o),

        .bitstream_packet(bitstream_packet),
        .bitstream_strobe(bitstream_strobe)
    );
endmodule
