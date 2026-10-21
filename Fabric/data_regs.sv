`timescale 1ps/1ps

module data_regs #(
    parameter int FrameBitsPerRow = 32,
    parameter int IOBPins = 28,
    parameter logic [31:0] IdentificationCode = 32'b0101_1010101010101010_11111111000_1
) (
    input logic tck_i,
    input logic tdi_i,
    output logic tdo_o,
    input logic trst_ni,

    input jtag_pkg::operation_t op_i,
    input jtag_pkg::register_t reg_i,
    input jtag_pkg::dr_t dr_i,
    input jtag_pkg::instr_t instr_i,

    output logic[IOBPins-1:0] O_fab_o,
    input  logic[IOBPins-1:0] O_top_i,
    input  logic[IOBPins-1:0] I_fab_i,
    output logic[IOBPins-1:0] I_top_o,
    input  logic[IOBPins-1:0] T_fab_i,
    output logic[IOBPins-1:0] T_top_o,

    output logic[FrameBitsPerRow-1:0] bitstream_packet,
    output logic bitstream_strobe
);

    // Bypass register
    logic dr_bypass_tdo, dr_bypass_rst, dr_bypass_en;
    bypass_reg bypass_reg_i (
        .tck_i(tck_i),
        .en_i(dr_bypass_en),
        .rst_i(dr_bypass_rst),

        .tdi_i(tdi_i),
        .tdo_o(dr_bypass_tdo)
    );
    assign dr_bypass_en = (dr_i == jtag_pkg::DR_BYPASS && op_i == jtag_pkg::OP_SHIFT
                                                       && reg_i == jtag_pkg::REG_DR);
    assign dr_bypass_rst = ((dr_i == jtag_pkg::DR_BYPASS && op_i == jtag_pkg::OP_CAPTURE
                             && reg_i == jtag_pkg::REG_DR) || !trst_ni);

    // Boundary scan register
    logic dr_bsr_tdo;
    boundary_scan_reg #(
        .IOBPins(IOBPins)
    ) boundary_scan_reg_i (
        .tck_i(tck_i),

        .tdi_i(tdi_i),
        .tdo_o(dr_bsr_tdo),

        .instr_i(instr_i),
        .op_i(op_i),
        .reg_i(reg_i),

        .I_fab_i(I_fab_i),
        .I_top_o(I_top_o),
        .O_fab_o(O_fab_o),
        .O_top_i(O_top_i),
        .T_fab_i(T_fab_i),
        .T_top_o(T_top_o)
    );

    // Id register
    logic dr_id_tdo, dr_id_en, dr_id_rst;
    id_reg #(
        .IdentificationCode(IdentificationCode)
    ) id_reg_i (
        .tck_i(tck_i),
        .en_i(dr_id_en),
        .rst_i(dr_id_rst),

        .tdi_i(tdi_i),
        .tdo_o(dr_id_tdo)
    );
    assign dr_id_en = (dr_i == jtag_pkg::DR_ID && op_i == jtag_pkg::OP_SHIFT
                                               && reg_i == jtag_pkg::REG_DR);
    assign dr_id_rst = ((dr_i == jtag_pkg::DR_ID && op_i == jtag_pkg::OP_CAPTURE
                             && reg_i == jtag_pkg::REG_DR) || !trst_ni);

    // Config register
    logic dr_config_tdo, dr_config_rst, dr_config_en;
    config_reg #(
        .FrameBitsPerRow(FrameBitsPerRow)
    ) config_reg_i (
        .tck_i(tck_i),
        .en_i(dr_config_en),
        .rst_i(dr_config_rst),

        .tdi_i(tdi_i),
        .tdo_o(dr_config_tdo),

        .bitstream_packet(bitstream_packet),
        .bitstream_strobe(bitstream_strobe)
    );
    assign dr_config_en = (dr_i == jtag_pkg::DR_CONFIG && op_i == jtag_pkg::OP_SHIFT
                                                       && reg_i == jtag_pkg::REG_DR);
    assign dr_config_rst = ((dr_i == jtag_pkg::DR_CONFIG && op_i == jtag_pkg::OP_CAPTURE
                                && reg_i == jtag_pkg::REG_DR) || !trst_ni);

    // Multiplexing outputs
    always_comb begin
        case (dr_i)
            jtag_pkg::DR_BYPASS: tdo_o = dr_bypass_tdo;
            jtag_pkg::DR_ID:     tdo_o = dr_id_tdo;
            jtag_pkg::DR_CONFIG: tdo_o = dr_config_tdo;
            jtag_pkg::DR_BSR:    tdo_o = dr_bsr_tdo;

            default:             tdo_o = dr_bypass_tdo;
        endcase
    end
endmodule

/* verilator lint_off DECLFILENAME */
/////////////////////
// Bypass register //
/////////////////////
module bypass_reg (
    input logic tck_i,
    input logic en_i,
    input logic rst_i,

    input logic tdi_i,
    output logic tdo_o
);

    logic register;

    always_ff @(posedge tck_i) begin
        if (rst_i)     register <= 1'b0;
        else if (en_i) register <= tdi_i;
        else           register <= register;
    end

    always_ff @(negedge tck_i) tdo_o <= register;
endmodule

/////////////////
// ID register //
/////////////////
module id_reg #(
    parameter logic [31:0] IdentificationCode = 32'b0101_1010101010101010_11111111000_1
) (
    input logic tck_i,
    input logic en_i,
    input logic rst_i,

    input logic tdi_i,
    output logic tdo_o
);

    logic [31:0] register;

    always_ff @(posedge tck_i) begin
        if (rst_i)     register <= IdentificationCode;
        else if (en_i) register <= {tdi_i, register[31:1]};
        else           register <= register;
    end

    always_ff @(negedge tck_i) tdo_o <= register[0];
endmodule

/////////////////////
// Config register //
/////////////////////
module config_reg #(
    parameter int FrameBitsPerRow = 32
) (
    input logic tck_i,
    input logic en_i,
    input logic rst_i,

    input logic tdi_i,
    output logic tdo_o,

    output logic[FrameBitsPerRow-1:0] bitstream_packet,
    output logic bitstream_strobe
);

    logic [FrameBitsPerRow-1:0] register;
    logic [$clog2(FrameBitsPerRow):0] shift_count;
    logic last_bit;

    assign last_bit = (shift_count == FrameBitsPerRow-1);

    // Shifting
    always_ff @(posedge tck_i) begin
        if (rst_i) begin
            register <= '0;
            shift_count <= '0;
        end else if (en_i) begin
            register <= {tdi_i, register[FrameBitsPerRow-1:1]};
            shift_count <= last_bit ? '0 : shift_count + 1'b1;
        end
    end

    always_ff @(negedge tck_i) tdo_o <= register[0];

    // Output signals
    always_ff @(posedge tck_i) begin
        if (rst_i) begin
            bitstream_packet <= '0;
            bitstream_strobe <= 1'b0;
        end else if (en_i) begin
            if (last_bit) begin
                bitstream_packet <= {tdi_i, register[FrameBitsPerRow-1:1]};
                bitstream_strobe <= 1'b1;
            end else begin
                bitstream_strobe <= 1'b0;
            end
        end else begin
            bitstream_strobe <= 1'b0;
        end
    end
endmodule
