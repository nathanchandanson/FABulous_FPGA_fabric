`timescale 1ps/1ps

package jtag_pkg;
    localparam IR_SIZE = 4;

    typedef enum logic [2:0] {
        OP_NONE,
        OP_TEST_LOGIC_RESET,
        //RUN_TEST_IDLE,
        OP_CAPTURE,
        OP_SHIFT,
        OP_UPDATE
    } operation_t;

    typedef enum logic [1:0] {
        REG_NONE,
        REG_IR,
        REG_DR
    } register_t;

    typedef enum logic [IR_SIZE-1:0] {
        INSTR_SAMPLE_PRELOAD = 4'b0001,
        INSTR_EXTEST         = 4'b0110,
        INSTR_IDCODE         = 4'b1001,
        INSTR_CONFIG         = 4'b0101,
        INSTR_BYPASS         = '1
        // Eventually custom ones
    } instr_t;

    typedef enum logic [1:0] {
        DR_BYPASS,
        DR_ID,
        DR_BSR,
        DR_CONFIG
        // Eventually custom ones
    } dr_t;
endpackage
