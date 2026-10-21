module OBI_MASTER #(parameter NoConfigBits = 0)(
    // User design
    input         REQ,
    input         WE,
    input  [3: 0] BE,
    input  [23:0] ADDR,
    input  [31:0] WDATA,

    output        GNT,
    output        RVALID,
    output [31:0] RDATA,

    // Top
    (* FABulous, EXTERNAL *) output        MASTER_REQ_top,
    (* FABulous, EXTERNAL *) output        MASTER_WE_top,
    (* FABulous, EXTERNAL *) output [3: 0] MASTER_BE_top,
    (* FABulous, EXTERNAL *) output [23:0] MASTER_ADDR_top,
    (* FABulous, EXTERNAL *) output [31:0] MASTER_WDATA_top,

    (* FABulous, EXTERNAL *) input         MASTER_GNT_top,
    (* FABulous, EXTERNAL *) input         MASTER_RVALID_top,
    (* FABulous, EXTERNAL *) input  [31:0] MASTER_RDATA_top
);

    assign MASTER_REQ_top   = REQ;
    assign MASTER_WE_top    = WE;
    assign MASTER_BE_top    = BE;
    assign MASTER_ADDR_top  = ADDR;
    assign MASTER_WDATA_top = WDATA;

    assign GNT       = MASTER_GNT_top;
    assign RVALID    = MASTER_RVALID_top;
    assign RDATA     = MASTER_RDATA_top;

endmodule
