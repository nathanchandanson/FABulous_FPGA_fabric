module CVXIF_ISSUE #(parameter NoConfigBits = 0)(
    ////// User design //////
    output        ISSUE_VALID,
    input         ISSUE_READY,
    // issue_req
    output [31:0] ISSUE_REQ_INSTR,
    output [ 3:0] ISSUE_REQ_ID,
    // issue_resp
    input         ISSUE_RESP_ACCEPT,
    input         ISSUE_RESP_WRITEBACK,
    input  [ 2:0] ISSUE_RESP_REGISTER_READ,

    ////////// Top //////////
    (* FABulous, EXTERNAL *) input         ISSUE_VALID_top,
    (* FABulous, EXTERNAL *) output        ISSUE_READY_top,
    // issue_req
    (* FABulous, EXTERNAL *) input  [31:0] ISSUE_REQ_INSTR_top,
    (* FABulous, EXTERNAL *) input  [ 3:0] ISSUE_REQ_ID_top,
    // issue_resp
    (* FABulous, EXTERNAL *) output        ISSUE_RESP_ACCEPT_top,
    (* FABulous, EXTERNAL *) output        ISSUE_RESP_WRITEBACK_top,
    (* FABulous, EXTERNAL *) output [ 2:0] ISSUE_RESP_REGISTER_READ_top
);

    assign ISSUE_VALID                  = ISSUE_VALID_top;
    assign ISSUE_READY_top              = ISSUE_READY;
    // issue_req
    assign ISSUE_REQ_INSTR              = ISSUE_REQ_INSTR_top;
    assign ISSUE_REQ_ID                 = ISSUE_REQ_ID_top;
    // issue_resp
    assign ISSUE_RESP_ACCEPT_top        = ISSUE_RESP_ACCEPT;
    assign ISSUE_RESP_WRITEBACK_top     = ISSUE_RESP_WRITEBACK;
    assign ISSUE_RESP_REGISTER_READ_top = ISSUE_RESP_REGISTER_READ;

endmodule
