module CVXIF_REGISTER2 #(parameter NoConfigBits = 0)(
    // User design
    output REGISTER_VALID,
    input  REGISTER_READY,

    output [ 3:0] REGISTER_ID,
    output [31:0] REGISTER_RSA,
    output [31:0] REGISTER_RSB,
    output [ 1:0] REGISTER_RS_VALID,    // NOTE: This is a generic implementation so it sets X_NUM_RS is 2.

    // Top
    (* FABulous, EXTERNAL *) input  REGISTER_VALID_top,
    (* FABulous, EXTERNAL *) output REGISTER_READY_top,

    (* FABulous, EXTERNAL *) input  [ 3:0] REGISTER_ID_top,
    (* FABulous, EXTERNAL *) input  [31:0] REGISTER_RSA_top,
    (* FABulous, EXTERNAL *) input  [31:0] REGISTER_RSB_top,
    (* FABulous, EXTERNAL *) input  [ 1:0] REGISTER_RS_VALID_top
);

    assign REGISTER_VALID     = REGISTER_VALID_top;
    assign REGISTER_READY_top = REGISTER_READY;

    assign REGISTER_ID       = REGISTER_ID_top;
    assign REGISTER_RSA      = REGISTER_RSA_top;
    assign REGISTER_RSB      = REGISTER_RSB_top;
    assign REGISTER_RS_VALID = REGISTER_RS_VALID_top;

endmodule
