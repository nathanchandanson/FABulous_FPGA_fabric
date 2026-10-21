`timescale 1ps/1ps
module sram_tb;
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


    // Bitstream signals
    localparam MAX_BITBYTES = 20000;
    reg [7:0] bitstream[0:MAX_BITBYTES-1];

    reg [31:0] current_word;
    reg [2047:0] bitstream_hex_arg; // 256 bytes for characters
    reg [2047:0] output_waveform_arg; // 256 bytes for characters

    // Clk gen
    always #50 CLK = (CLK === 1'b0);
    always #50 jtag_tck = (jtag_tck === 1'b0);

    // Testbench tracking arrays
    reg [15:0] data [0:3]; // 4 words for the 4 SRAM blocks
    integer i;
    // Exact bit mappings derived from your 'top' module
    localparam REN_BIT            = 27; 
    localparam WEN_BIT            = 26; 
    localparam SRAM_SELECT_OFFSET = 24; // Bits [25:24]
    localparam ADDRESS_OFFSET     = 16; // Bits [23:16]

    initial begin

        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, sram_tb);
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

        jtag_tms = 1'b1;
        O_top = 28'b0;
        repeat (100) @(negedge jtag_tck);

        // Generate random values
        for (i = 0; i < 4; i = i + 1) begin
            data[i] = $urandom_range(0, 65535);
        end
        repeat (10) @(negedge CLK);

        // Writing
        $display("--- Starting Write Operations ---");
        for (i = 0; i < 4; i = i + 1) begin
            O_top = (1'b1 << WEN_BIT)            |
                    (i    << SRAM_SELECT_OFFSET) |
                    (8'hA5<< ADDRESS_OFFSET)     |
                    data[i];
            @(posedge CLK);
            #1;
        end

        O_top = 28'b0;
        repeat (20) @(posedge CLK);

        // Reading
        for (i = 0; i < 4; i = i + 1) begin
            O_top = (1'b1 << REN_BIT)            |
                    (i    << SRAM_SELECT_OFFSET) |
                    (8'hA5<< ADDRESS_OFFSET);
            @(posedge CLK);
            #1;

            $display("Time %0t | SRAM[%0d] | Read Payload: 0x%h | Expected: 0x%h", 
                     $time, i, I_top[15:0], data[i]);

            // Verify structural correctness of your complex custom data bit shuffles
            if (I_top[15:0] !== data[i]) begin
                $error("Assertion Failed! Data mismatch on SRAM %0d. Read: 0x%h, Expected: 0x%h", 
                       i, I_top[15:0], data[i]);
                $finish; 
            end
        end

        O_top = 28'b0;
        repeat(10) @(posedge CLK);

        $display("\nSuccess: All SRAM data swizzles and selections passed perfectly!");
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
