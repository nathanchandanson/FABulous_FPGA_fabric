`timescale 1ps/1ps
module test_wire_if_tile_tb;
    wire [27:0] I_top;
    wire [27:0] T_top;
    reg [27:0] O_top = 0;
    // XIF interface
    reg         ISSUE_VALID_top;
    wire        ISSUE_READY_top;
    reg  [31:0] ISSUE_REQ_INSTR_top;
    reg  [3:0]  ISSUE_REQ_ID_top;
    wire        ISSUE_RESP_ACCEPT_top;
    wire        ISSUE_RESP_WRITEBACK_top;
    wire [2:0]  ISSUE_RESP_REGISTER_READ_top;
    reg  [3:0]  REGISTER_ID_top;
    wire        REGISTER_READY_top;
    reg  [31:0] REGISTER_RSA_top;
    reg  [31:0] REGISTER_RSB_top;
    reg  [1:0]  REGISTER_RS_VALID_top;
    reg         REGISTER_VALID_top;
    reg  [3:0]  COMMIT_ID_top;
    reg         COMMIT_KILL_top;
    reg         COMMIT_VALID_top;
    wire [31:0] RESULT_DATA_top;
    wire [3:0]  RESULT_ID_top;
    wire [4:0]  RESULT_RD_top;
    reg         RESULT_READY_top;
    wire        RESULT_VALID_top;
    wire        RESULT_WE_top;
    // OBI interface
    reg  [0:0]  SLAVE_REQ_top;
    reg  [0:0]  SLAVE_WE_top;
    reg  [3:0]  SLAVE_BE_top;
    reg  [23:0] SLAVE_ADDR_top;
    reg  [31:0] SLAVE_WDATA_top;
    wire [0:0]  SLAVE_GNT_top;
    wire [0:0]  SLAVE_RVALID_top;
    wire [31:0] SLAVE_RDATA_top;
    // Wire interface
    reg  [95:0] WIRE_IF_INA;
    reg  [23:0] WIRE_IF_INB;
    reg  [23:0] WIRE_IF_INC;
    reg  [11:0] WIRE_IF_IND;
    wire [95:0] WIRE_IF_OUTA;
    wire [23:0] WIRE_IF_OUTB;
    wire [23:0] WIRE_IF_OUTC;
    wire [11:0] WIRE_IF_OUTD;

    reg CLK = 1'b0;
    reg resetn = 1'b1;
    reg SelfWriteStrobe = 1'b0;
    reg [31:0] SelfWriteData = 1'b0;

    localparam NumberPin = 28;
    localparam FrameBitsPerRow = 32;
    localparam MAX_SHIFT_NBR = (NumberPin*3 > FrameBitsPerRow)
                               ? NumberPin*3
                               : FrameBitsPerRow;
    reg jtag_tck = 1'b0;
    reg jtag_tms = 1'b1;
    reg jtag_tdi = 1'b0;
    wire jtag_tdo;
    reg jtag_trst = 1'b1;
    logic [MAX_SHIFT_NBR-1:0] values_shift_tdi;
    logic [MAX_SHIFT_NBR-1:0] values_shift_tdo;

    // Instantiate both the fabric and the reference DUT
    eFPGA_top top_i (
        .I_top(I_top),
        .T_top(T_top),
        .O_top(O_top),
        // XIF interface
        .ISSUE_VALID_top(ISSUE_VALID_top),
        .ISSUE_READY_top(ISSUE_READY_top),
        .ISSUE_REQ_INSTR_top(ISSUE_REQ_INSTR_top),
        .ISSUE_REQ_ID_top(ISSUE_REQ_ID_top),
        .ISSUE_RESP_ACCEPT_top(ISSUE_RESP_ACCEPT_top),
        .ISSUE_RESP_WRITEBACK_top(ISSUE_RESP_WRITEBACK_top),
        .ISSUE_RESP_REGISTER_READ_top(ISSUE_RESP_REGISTER_READ_top),
        .REGISTER_ID_top(REGISTER_ID_top),
        .REGISTER_READY_top(REGISTER_READY_top),
        .REGISTER_RSA_top(REGISTER_RSA_top),
        .REGISTER_RSB_top(REGISTER_RSB_top),
        .REGISTER_RS_VALID_top(REGISTER_RS_VALID_top),
        .REGISTER_VALID_top(REGISTER_VALID_top),
        .COMMIT_ID_top(COMMIT_ID_top),
        .COMMIT_KILL_top(COMMIT_KILL_top),
        .COMMIT_VALID_top(COMMIT_VALID_top),
        .RESULT_DATA_top(RESULT_DATA_top),
        .RESULT_ID_top(RESULT_ID_top),
        .RESULT_RD_top(RESULT_RD_top),
        .RESULT_READY_top(RESULT_READY_top),
        .RESULT_VALID_top(RESULT_VALID_top),
        .RESULT_WE_top(RESULT_WE_top),
        // OBI interface
        .SLAVE_REQ_top(SLAVE_REQ_top),
        .SLAVE_WE_top(SLAVE_WE_top),
        .SLAVE_BE_top(SLAVE_BE_top),
        .SLAVE_ADDR_top(SLAVE_ADDR_top),
        .SLAVE_WDATA_top(SLAVE_WDATA_top),
        .SLAVE_GNT_top(SLAVE_GNT_top),
        .SLAVE_RVALID_top(SLAVE_RVALID_top),
        .SLAVE_RDATA_top(SLAVE_RDATA_top),
        // Wire interface
        .WIRE_IF_INA(WIRE_IF_INA),
        .WIRE_IF_INB(WIRE_IF_INB),
        .WIRE_IF_INC(WIRE_IF_INC),
        .WIRE_IF_IND(WIRE_IF_IND),
        .WIRE_IF_OUTA(WIRE_IF_OUTA),
        .WIRE_IF_OUTB(WIRE_IF_OUTB),
        .WIRE_IF_OUTC(WIRE_IF_OUTC),
        .WIRE_IF_OUTD(WIRE_IF_OUTD),

        .CLK(CLK),
        .resetn(resetn),
        .SelfWriteStrobe(SelfWriteStrobe),
        .SelfWriteData(SelfWriteData),

        .tck_i(jtag_tck),
        .tms_i(jtag_tms),
        .tdi_i(jtag_tdi),
        .tdo_o(jtag_tdo),
        .trst_ni(jtag_trst)
    );


    // Bitstream signals
    localparam MAX_BITBYTES = 20000;
    reg [7:0] bitstream[0:MAX_BITBYTES-1];

    integer i;
    reg [31:0] current_word;
    reg [2047:0] bitstream_hex_arg; // 256 bytes for characters
    reg [2047:0] output_waveform_arg; // 256 bytes for characters

    // Clk gen
    always #50 CLK = (CLK === 1'b0);
    always #50 jtag_tck = (jtag_tck === 1'b0);

    // Counter
    reg [31:0] counter = 32'b0;
    always @(posedge CLK) begin
        counter <= counter + 1'b1;
    end
    assign WIRE_IF_INA[31:0] = counter;
    assign WIRE_IF_INA[63:32] = counter;
    assign WIRE_IF_INA[95:64] = counter;
    assign WIRE_IF_INB[7:0] = counter[7:0];
    assign WIRE_IF_INB[15:8] = counter[7:0];
    assign WIRE_IF_INB[23:16] = counter[7:0];
    assign WIRE_IF_INC[7:0] = counter[7:0];
    assign WIRE_IF_INC[15:8] = counter[7:0];
    assign WIRE_IF_INC[23:16] = counter[7:0];
    assign WIRE_IF_IND[3:0] = counter[3:0];
    assign WIRE_IF_IND[7:4] = counter[3:0];
    assign WIRE_IF_IND[11:8] = counter[3:0];



    initial begin

        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, test_wire_if_tile_tb);
            $display("Output waveform set to %s", output_waveform_arg);
        end

        // Reset sequence
        #100;
        resetn = 1'b0;
        jtag_trst = 1'b0;
        #10000;
        resetn = 1'b1;
        jtag_trst = 1'b1;
        #10000;
        repeat (20) @(negedge jtag_tck);
        #2500;
        jtag_tms = 1'b1;
        repeat (20) @(negedge jtag_tck);

`ifndef EMULATION
        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            $readmemh(bitstream_hex_arg, bitstream);
            $display("Read bitstream hex from %s", bitstream_hex_arg);
        end else begin
            $display("Error: No bitstream provided as $plusargs bitstream_hex.");
            $fatal;
        end

        // jtag_program();
        SelfWriteStrobe <= 1'b0;
        for (i = 0; i < MAX_BITBYTES; i = i + 4) begin
            // SelfWriteData <= {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            // repeat (2) @(posedge CLK);
            // SelfWriteStrobe <= 1'b1;
            // @(posedge CLK);
            // SelfWriteStrobe <= 1'b0;
            // repeat (2) @(posedge CLK);
            @(negedge CLK);
            SelfWriteData <= {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            SelfWriteStrobe <= 1'b1;
        end
`endif
        O_top = 28'b1111_1111_1111_1111_1111_1111_1111;
        repeat (10) @(posedge CLK);
        O_top = 28'b0000_0000_0000_0000_0000_0000_0000;

        repeat (500) @(posedge CLK);

        $finish;
    end





    task automatic jtag_program;
        // Go to Shift IR
        jtag_tms = 1'b0;
        @(negedge jtag_tck);

        ////////////////////////
        // Shifting bitstream //
        ////////////////////////
        jtag_rti_goto_shiftIR();
        // Shifting IR
        jtag_shift_goto_selectDR (
            .values_tdi(4'b0101),
            .values_tdo(values_shift_tdo),
            .nbr_values(4)
        );

        // Go from selectDR to shiftDR
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);

        // Start Shifting config register
        current_word <= {bitstream[0], bitstream[1], bitstream[2], bitstream[3]};
        for (i = 0; i < MAX_BITBYTES; i = i + 4) begin
            current_word = {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            jtag_shift (
                .values_tdi(current_word),
                .values_tdo(values_shift_tdo),
                .nbr_values(32)
            );
        end

        jtag_tms = 1'b1;
    endtask


    ///////////////////////////
    // Tasks to control JTAG //
    ///////////////////////////
    // Going to tlr from any state
    task automatic jtag_goto_tlr;
        jtag_tms = 1'b1;
        repeat (5) @(negedge jtag_tck);
    endtask

    // RTI -> ShiftIR
    task automatic jtag_rti_goto_shiftDR;
        jtag_tms = 1'b1;
        @(negedge jtag_tck);
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);
    endtask

    // RTI -> ShiftIR
    task automatic jtag_rti_goto_shiftIR;
        jtag_tms = 1'b1;
        repeat (2) @(negedge jtag_tck);
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);
    endtask

    task automatic jtag_shift (
        input logic[MAX_SHIFT_NBR-1:0] values_tdi,
        output logic[MAX_SHIFT_NBR-1:0] values_tdo,
        input int nbr_values
    );
        for (int i = 0; i < nbr_values; i++) begin
            @(posedge jtag_tck);
            jtag_tdi = values_tdi[i];
            @(negedge jtag_tck);
            values_tdo[i] = jtag_tdo;
        end
    endtask

    task automatic jtag_shift_goto_update (
        input logic[MAX_SHIFT_NBR-1:0] values_tdi,
        output logic[MAX_SHIFT_NBR-1:0] values_tdo,
        input int nbr_values
    );
        for (int i = 0; i < nbr_values; i++) begin
            if (i == nbr_values - 1) jtag_tms = 1'b1;
            @(posedge jtag_tck);
            jtag_tdi = values_tdi[i];
            @(negedge jtag_tck);
            values_tdo[i] = jtag_tdo;
        end
        @(negedge jtag_tck);
    endtask

    // Shift up to 32 bits word -> PauseDR/IR
    task automatic jtag_shift_goto_pause (
        input logic[MAX_SHIFT_NBR-1:0] values_tdi,
        output logic[MAX_SHIFT_NBR-1:0] values_tdo,
        input int nbr_values
    );
        for (int i = 0; i < nbr_values; i++) begin
            if (i == nbr_values - 1) jtag_tms = 1'b1;
            @(posedge jtag_tck);
            jtag_tdi = values_tdi[i];
            @(negedge jtag_tck);
            values_tdo[i] = jtag_tdo;
        end
        jtag_tms = 1'b0;
        @(negedge jtag_tck);
    endtask

    // Shift up to 32 bits word -> RunTestIdle
    task automatic jtag_shift_goto_rti (
        input logic[MAX_SHIFT_NBR-1:0] values_tdi,
        output logic[MAX_SHIFT_NBR-1:0] values_tdo,
        input int nbr_values
    );
        jtag_shift_goto_update (
            .values_tdi(values_tdi),
            .values_tdo(values_tdo),
            .nbr_values(nbr_values)
        );
        jtag_tms = 1'b0;
        @(negedge jtag_tck);
    endtask

    // Shift up to 32 bits word -> SelectDR
    task automatic jtag_shift_goto_selectDR (
        input logic[MAX_SHIFT_NBR-1:0] values_tdi,
        output logic[MAX_SHIFT_NBR-1:0] values_tdo,
        input int nbr_values
    );
        jtag_shift_goto_update (
            .values_tdi(values_tdi),
            .values_tdo(values_tdo),
            .nbr_values(nbr_values)
        );
        jtag_tms = 1'b1;
        @(negedge jtag_tck);
    endtask
endmodule
