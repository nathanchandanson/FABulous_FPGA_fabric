`timescale 1ps/1ps
module sequential_16bit_en_tb;
    wire [27:0] I_top;
    wire [27:0] T_top;
    reg [27:0] O_top = 0;

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


    localparam MAX_BITBYTES = 20000;
    reg [7:0] bitstream[0:MAX_BITBYTES-1];

    always #50 CLK = (CLK === 1'b0);
    always #500 jtag_tck = (jtag_tck === 1'b0);

    integer i;
    reg have_errors = 1'b0;

    reg [31:0] current_word;

    reg [2047:0] bitstream_hex_arg; // 256 bytes for characters
    reg [2047:0] output_waveform_arg; // 256 bytes for characters
    initial begin

        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, sequential_16bit_en_tb);
            $display("Output waveform set to %s", output_waveform_arg);
        end

`ifndef EMULATION

        if ($value$plusargs("bitstream_hex=%s", bitstream_hex_arg)) begin
            $readmemh(bitstream_hex_arg, bitstream);
            $display("Read bitstream hex from %s", bitstream_hex_arg);
        end else begin
            $display("Error: No bitstream provided as $plusargs bitstream_hex.");
            $fatal;
        end
        current_word <= {bitstream[0], bitstream[1], bitstream[2], bitstream[3]};

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
        for (i = 0; i < 32; i = i + 4) begin
            current_word = {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            if (i == 28) begin
                jtag_shift_goto_pause (
                    .values_tdi(current_word),
                    .values_tdo(values_shift_tdo),
                    .nbr_values(32)
                );
            end else begin
                jtag_shift (
                    .values_tdi(current_word),
                    .values_tdo(values_shift_tdo),
                    .nbr_values(32)
                );
            end
        end

        // Wait and go back to ShiftDR
        jtag_tms = 1'b0;
        repeat (100) @(negedge jtag_tck);
        jtag_tms = 1'b1;
        @(negedge jtag_tck);
        jtag_tms = 1'b0;
        @(negedge jtag_tck);

        // Finish shifting the bitstream
        for (i = 32; i < MAX_BITBYTES; i = i + 4) begin
            current_word = {bitstream[i], bitstream[i+1], bitstream[i+2], bitstream[i+3]};
            jtag_shift (
                .values_tdi(current_word),
                .values_tdo(values_shift_tdo),
                .nbr_values(32)
            );
        end

        jtag_tms = 1'b1;

`endif
        repeat (100) @(negedge jtag_tck);

        O_top = 28'b0000_0011;
        repeat (10) @(negedge jtag_tck);
        O_top = 28'b0000_0010;
        repeat (100) @(negedge jtag_tck);

        /////////////////////////////
        // Setup inputs using JTAG //
        /////////////////////////////
        // Goal
        // 1. sample+preload pins with enable and reset : O_fabric = 28'b0000_0000_0000_0000_0000_0000_0011;
        // 2. extest to drive the input pins of the fpga
        // 3. Shift pin values with only enable WHILE IN EXTEST : O_fabric = 28'b0000_0000_0000_0000_0000_0000_0010;
        // 4. RTI to let the fpga live
        // 5. SAMPLE ? just to see

        // Go from TLR to shift IR
        jtag_tms = 1'b0;
        @(negedge jtag_tck);
        jtag_rti_goto_shiftIR();
        // Shift SAMPLE/PRELOAD instruction
        jtag_shift_goto_selectDR (
            .values_tdi(4'b0001),
            .values_tdo(values_shift_tdo),
            .nbr_values(4)
        );

        // SelectDR -> ShiftDR
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);
        // Shift preload value
        jtag_shift_goto_selectDR(
            .values_tdi({{(NumberPin*3-6){1'b0}}, 6'b100100}),
            .values_tdo(values_shift_tdo),
            .nbr_values(NumberPin*3)
        );
        $display("Pin values when first preloading values: %B", values_shift_tdo);

        // SelectDR -> ShiftIR
        jtag_tms = 1'b1;
        @(negedge jtag_tck);
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);
        // Shift EXTEST instruction
        jtag_shift_goto_rti (
            .values_tdi(4'b0110),
            .values_tdo(values_shift_tdo),
            .nbr_values(4)
        );

        // Wait a bit
        jtag_tms = 1'b0;
        repeat (5) @(negedge jtag_tck);

        // RTI -> ShiftDR
        jtag_rti_goto_shiftDR();
        // Shift new input values
        jtag_shift_goto_selectDR(
            .values_tdi({{(NumberPin*3-6){1'b0}}, 6'b100000}),
            .values_tdo(values_shift_tdo),
            .nbr_values(NumberPin*3)
        );
        $display("Pin values when preloading values the second time: %B", values_shift_tdo);
        // Setting up the REAL input pins of the top so that they coincide
        // with the preloaded value
        O_top = 28'b0000_0010;

        // SelectDR -> ShiftIR
        jtag_tms = 1'b1;
        @(negedge jtag_tck);
        jtag_tms = 1'b0;
        repeat (2) @(negedge jtag_tck);
        // Shift SAMPLE_PRELOAD instruction
        jtag_shift_goto_rti (
            .values_tdi(4'b0001),
            .values_tdo(values_shift_tdo),
            .nbr_values(4)
        );
        jtag_tms = 1'b0;


        /////////////////////////////////////
        // Printing the counter pin values //
        /////////////////////////////////////
        for (i = 0; i < 100; i = i + 1) begin
            @(negedge CLK);
            $display("fabric(I_top) = 0x%X, fabric(T_top) = 0x%X", I_top, T_top);
        end

        /////////////////
        // SAMPLE pins //
        /////////////////
        jtag_rti_goto_shiftDR();
        jtag_shift_goto_rti(
            .values_tdi({NumberPin*3{1'b0}}),
            .values_tdo(values_shift_tdo),
            .nbr_values(NumberPin*3)
        );
        jtag_tms = 1'b0;
        $display("Sample: %B", values_shift_tdo);

        repeat (100) @(negedge jtag_tck);

        $finish;
    end





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
