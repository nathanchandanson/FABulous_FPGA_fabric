module WIRE_IF #(parameter NoConfigBits = 0)(
    ////// User design //////
    output [31:0] INA,
    output [ 7:0] INB,
    output [ 7:0] INC,
    output [ 3:0] IND,

    input  [31:0] OUTA,
    input  [ 7:0] OUTB,
    input  [ 7:0] OUTC,
    input  [ 3:0] OUTD,

    ////////// Top //////////
    (* FABulous, EXTERNAL *) input  [31:0] WIRE_IF_INA,
    (* FABulous, EXTERNAL *) input  [ 7:0] WIRE_IF_INB,
    (* FABulous, EXTERNAL *) input  [ 7:0] WIRE_IF_INC,
    (* FABulous, EXTERNAL *) input  [ 3:0] WIRE_IF_IND,

    (* FABulous, EXTERNAL *) output [31:0] WIRE_IF_OUTA,
    (* FABulous, EXTERNAL *) output [ 7:0] WIRE_IF_OUTB,
    (* FABulous, EXTERNAL *) output [ 7:0] WIRE_IF_OUTC,
    (* FABulous, EXTERNAL *) output [ 3:0] WIRE_IF_OUTD
);

    assign INA = WIRE_IF_INA;
    assign INB = WIRE_IF_INB;
    assign INC = WIRE_IF_INC;
    assign IND = WIRE_IF_IND;

    assign WIRE_IF_OUTA = OUTA;
    assign WIRE_IF_OUTB = OUTB;
    assign WIRE_IF_OUTC = OUTC;
    assign WIRE_IF_OUTD = OUTD;

endmodule
