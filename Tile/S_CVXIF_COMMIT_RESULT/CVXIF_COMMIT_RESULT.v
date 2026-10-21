module CVXIF_COMMIT_RESULT #(parameter NoConfigBits = 0)(
    // User design
    // Commit interface
    output        COMMIT_VALID,
    output [ 3:0] COMMIT_ID,
    output        COMMIT_KILL,
    // Result interface
    input         RESULT_VALID,
    output        RESULT_READY,
    input  [ 3:0] RESULT_ID,
    input  [31:0] RESULT_DATA,
    input  [ 4:0] RESULT_RD,
    input         RESULT_WE,

    // Top
    // Commit interface
    (* FABulous, EXTERNAL *) input         COMMIT_VALID_top,
    (* FABulous, EXTERNAL *) input  [ 3:0] COMMIT_ID_top,
    (* FABulous, EXTERNAL *) input         COMMIT_KILL_top,
    // Result interface
    (* FABulous, EXTERNAL *) output        RESULT_VALID_top,
    (* FABulous, EXTERNAL *) input         RESULT_READY_top,
    (* FABulous, EXTERNAL *) output [ 3:0] RESULT_ID_top,
    (* FABulous, EXTERNAL *) output [31:0] RESULT_DATA_top,
    (* FABulous, EXTERNAL *) output [ 4:0] RESULT_RD_top,
    (* FABulous, EXTERNAL *) output        RESULT_WE_top
);

    // Commit interface
    assign COMMIT_VALID     = COMMIT_VALID_top;

    assign COMMIT_ID        = COMMIT_ID_top;
    assign COMMIT_KILL      = COMMIT_KILL_top;

    // Result interface
    assign RESULT_VALID_top = RESULT_VALID;
    assign RESULT_READY     = RESULT_READY_top;

    assign RESULT_ID_top    = RESULT_ID;
    assign RESULT_DATA_top  = RESULT_DATA;
    assign RESULT_RD_top    = RESULT_RD;
    assign RESULT_WE_top    = RESULT_WE;

endmodule
