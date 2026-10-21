`timescale 1ps/1ps

module boundary_scan_reg #(
    parameter int IOBPins = 28
) (
    input logic tck_i,

    input logic tdi_i,
    output logic tdo_o,

    input jtag_pkg::instr_t instr_i,
    input jtag_pkg::operation_t op_i,
    input jtag_pkg::register_t reg_i,

    output logic[IOBPins-1:0] O_fab_o,
    input  logic[IOBPins-1:0] O_top_i,
    input  logic[IOBPins-1:0] I_fab_i,
    output logic[IOBPins-1:0] I_top_o,
    input  logic[IOBPins-1:0] T_fab_i,
    output logic[IOBPins-1:0] T_top_o
);

    /*
    *
    * bsr    -----------------------------------------------------------
    * tdi -> |  MSB  |        |        | ... |       |        |  LSB   | -> tdo
    * io pin -----------------------------------------------------------
    *        | IN(O) | OUT(I) | CFG(T) | ... | IN(O) | OUT(I) | CFG(T) |
    *        -----------------------------------------------------------
    *
    */

    logic [IOBPins-2:0] tdo_tdi_cell;

    genvar i;
    generate
        for (i = 0; i < IOBPins; i = i + 1) begin: gen_bsr_cell
            if (i==IOBPins-1) begin: gen_bsr_last_cell
                boundary_scan_cell boundary_scan_cell_i (
                    .tck_i(tck_i),

                    .tdi_i(tdi_i),
                    .tdo_o(tdo_tdi_cell[i-1]),

                    .instr_i(instr_i),
                    .op_i(op_i),
                    .reg_i(reg_i),

                    .O_fab_o(O_fab_o[i]),
                    .O_top_i(O_top_i[i]),
                    .I_fab_i(I_fab_i[i]),
                    .I_top_o(I_top_o[i]),
                    .T_fab_i(T_fab_i[i]),
                    .T_top_o(T_top_o[i])
                );
            end else if (i==0) begin: gen_bsr_first_cell
                boundary_scan_cell boundary_scan_cell_i (
                    .tck_i(tck_i),

                    .tdi_i(tdo_tdi_cell[i]),
                    .tdo_o(tdo_o),

                    .instr_i(instr_i),
                    .op_i(op_i),
                    .reg_i(reg_i),

                    .O_fab_o(O_fab_o[i]),
                    .O_top_i(O_top_i[i]),
                    .I_fab_i(I_fab_i[i]),
                    .I_top_o(I_top_o[i]),
                    .T_fab_i(T_fab_i[i]),
                    .T_top_o(T_top_o[i])
                );
            end else begin: gen_bsr_middle_cells
                boundary_scan_cell boundary_scan_cell_i (
                    .tck_i(tck_i),

                    .tdi_i(tdo_tdi_cell[i]),
                    .tdo_o(tdo_tdi_cell[i-1]),

                    .instr_i(instr_i),
                    .op_i(op_i),
                    .reg_i(reg_i),

                    .O_fab_o(O_fab_o[i]),
                    .O_top_i(O_top_i[i]),
                    .I_fab_i(I_fab_i[i]),
                    .I_top_o(I_top_o[i]),
                    .T_fab_i(T_fab_i[i]),
                    .T_top_o(T_top_o[i])
                );
            end
        end
    endgenerate

endmodule

/* verilator lint_off DECLFILENAME */
/////////////////////////////////////
// Single Bidirectionnal scan cell //
/////////////////////////////////////
module boundary_scan_cell (
    input logic tck_i,

    input logic tdi_i,
    output logic tdo_o,

    input jtag_pkg::instr_t instr_i,
    input jtag_pkg::operation_t op_i,
    input jtag_pkg::register_t reg_i,

    output logic O_fab_o,
    input  logic O_top_i,
    input  logic I_fab_i,
    output logic I_top_o,
    input  logic T_fab_i,
    output logic T_top_o
);

    /*
    *
    * bsr    ---------------------------
    * tdi -> |  MSB  |        |        |
    * io pin ---------------------------
    *        | IN(O) | OUT(I) | CFG(T) |
    *        ---------------------------
    *
    */

    logic [2:0] bsc_register_shift;
    logic [2:0] bsc_register_parallel;

    // Updating Shift register stage
    always_ff @(posedge tck_i) begin
        if (reg_i == jtag_pkg::REG_DR) begin
            case (op_i)
                jtag_pkg::OP_CAPTURE: bsc_register_shift <= {O_top_i, I_fab_i, T_fab_i};
                jtag_pkg::OP_SHIFT:   bsc_register_shift <= {tdi_i, bsc_register_shift[2:1]};

                default: bsc_register_shift <= bsc_register_shift;
            endcase
        end else bsc_register_shift <= bsc_register_shift;
    end

    // Updating tdo at falling edge
    always_ff @(negedge tck_i) tdo_o <= bsc_register_shift[0];

    // Latching register until UpdateDR
    // Latched at falling edge of tck
    always_ff @(negedge tck_i) begin
        if (op_i == jtag_pkg::OP_UPDATE && reg_i == jtag_pkg::REG_DR) bsc_register_parallel <= bsc_register_shift;
        else bsc_register_parallel <= bsc_register_parallel;
    end

    // Assigning the outputs depending on the instruction
    assign {O_fab_o, I_top_o, T_top_o} = (instr_i == jtag_pkg::INSTR_EXTEST)
                                         ? bsc_register_parallel
                                         : {O_top_i, I_fab_i, T_fab_i};
endmodule
