`timescale 1ps/1ps
module rv32_zbkb_cvxif_pipelined_tb;
    wire [27:0] I_top;
    wire [27:0] T_top;
    reg [27:0] O_top = 0;
    // XIF interface
    reg         ISSUE_VALID_top               = 1'b0;
    wire        ISSUE_READY_top;
    reg  [31:0] ISSUE_REQ_INSTR_top           = 32'd0;
    reg  [3:0]  ISSUE_REQ_ID_top              = 4'd0;
    wire        ISSUE_RESP_ACCEPT_top;
    wire        ISSUE_RESP_WRITEBACK_top;
    wire [2:0]  ISSUE_RESP_REGISTER_READ_top;
    reg  [3:0]  REGISTER_ID_top               = 4'd0;
    wire        REGISTER_READY_top;
    reg  [31:0] REGISTER_RSA_top              = 32'd0;
    reg  [31:0] REGISTER_RSB_top              = 32'd0;
    reg  [1:0]  REGISTER_RS_VALID_top         = 2'd0;
    reg         REGISTER_VALID_top            = 1'd0;
    reg  [3:0]  COMMIT_ID_top                 = 4'd0;
    reg         COMMIT_KILL_top               = 1'd0;
    reg         COMMIT_VALID_top              = 1'd0;
    wire [31:0] RESULT_DATA_top;
    wire [3:0]  RESULT_ID_top;
    wire [4:0]  RESULT_RD_top;
    reg         RESULT_READY_top              = 1'd0;
    wire        RESULT_VALID_top;
    wire        RESULT_WE_top;
    // OBI slave interface
    reg  [0:0]  SLAVE_REQ_top;
    reg  [0:0]  SLAVE_WE_top;
    reg  [3:0]  SLAVE_BE_top;
    reg  [23:0] SLAVE_ADDR_top;
    reg  [31:0] SLAVE_WDATA_top;
    wire [0:0]  SLAVE_GNT_top;
    wire [0:0]  SLAVE_RVALID_top;
    wire [31:0] SLAVE_RDATA_top;
    // OBI master interface
    wire [0:0]  MASTER_REQ_top;
    wire [0:0]  MASTER_WE_top;
    wire [3:0]  MASTER_BE_top;
    wire [23:0] MASTER_ADDR_top;
    wire [31:0] MASTER_WDATA_top;
    reg  [0:0]  MASTER_GNT_top;
    reg  [0:0]  MASTER_RVALID_top;
    reg  [31:0] MASTER_RDATA_top;

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
        // OBI master interface
        .MASTER_REQ_top(MASTER_REQ_top),
        .MASTER_WE_top(MASTER_WE_top),
        .MASTER_BE_top(MASTER_BE_top),
        .MASTER_ADDR_top(MASTER_ADDR_top),
        .MASTER_WDATA_top(MASTER_WDATA_top),
        .MASTER_GNT_top(MASTER_GNT_top),
        .MASTER_RVALID_top(MASTER_RVALID_top),
        .MASTER_RDATA_top(MASTER_RDATA_top),
        // OBI slave interface
        .SLAVE_REQ_top(SLAVE_REQ_top),
        .SLAVE_WE_top(SLAVE_WE_top),
        .SLAVE_BE_top(SLAVE_BE_top),
        .SLAVE_ADDR_top(SLAVE_ADDR_top),
        .SLAVE_WDATA_top(SLAVE_WDATA_top),
        .SLAVE_GNT_top(SLAVE_GNT_top),
        .SLAVE_RVALID_top(SLAVE_RVALID_top),
        .SLAVE_RDATA_top(SLAVE_RDATA_top),
        // clk, rst, config
        .CLK(CLK),
        .resetn(resetn),
        .SelfWriteStrobe(SelfWriteStrobe),
        .SelfWriteData(SelfWriteData),
        // JTAG
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
    always #500000 CLK = (CLK === 1'b0);
    always #500000 jtag_tck = (jtag_tck === 1'b0);

    // Testbench tracking arrays
    localparam NUM_TESTS = 10;
    reg [31:0] reg_a [NUM_TESTS];
    reg [31:0] reg_b [NUM_TESTS];
    reg [31:0] result;
    reg [31:0] instruction;
    integer i;

    initial begin
        if ($value$plusargs("output_waveform=%s", output_waveform_arg)) begin
            $dumpfile(output_waveform_arg);
            $dumpvars(0, rv32_zbkb_cvxif_pipelined_tb);
            $display("Output waveform set to %s", output_waveform_arg);
        end
    end

    initial begin
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

        /////////////////
        // Programming //
        /////////////////
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

        ///////////////////
        // Starting test //
        ///////////////////
        jtag_tms = 1'b1;
        O_top = 28'b0000_0000_0000_0000_0000_0000_0001;
        repeat (100) @(negedge jtag_tck);
        O_top = 28'b0000_0000_0000_0000_0000_0000_0000;

        // Generate random values
        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            reg_a[i] = $urandom;
            reg_b[i] = $urandom;
        end
        repeat (10) @(negedge CLK);


        // Launch CVXIF transactions
        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            @(posedge CLK);
            // ROL
            instruction = {7'b0110000, i[4:0], i[4:0] + 5'd1, 3'b001, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != (reg_a[i] << reg_b[i][4:0] | reg_a[i] >> (32-reg_b[i][4:0]))) $fatal(1,"Error in ROL");
            // repeat (10) @(negedge CLK);

            // ROR
            instruction = {7'b0110000, i[4:0], i[4:0] + 5'd1, 3'b101, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != (reg_a[i] >> reg_b[i][4:0] | reg_a[i] << (32-reg_b[i][4:0]))) $fatal(1,"Error in ROR");
            // repeat (10) @(negedge CLK);

            // ANDN
            instruction = {7'b0100000, i[4:0], i[4:0] + 5'd1, 3'b111, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != (reg_a[i] & ~reg_b[i])) $fatal(1,"Error in ANDN");

            // ORN
            instruction = {7'b0100000, i[4:0], i[4:0] + 5'd1, 3'b110, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != (reg_a[i] | ~reg_b[i])) $fatal(1,"Error in ORN");

            // XNOR
            instruction = {7'b0100000, i[4:0], i[4:0] + 5'd1, 3'b100, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != ~(reg_a[i] ^ reg_b[i])) $fatal(1,"Error in XNOR");

            // PACKH
            instruction = {7'b0000100, i[4:0], i[4:0] + 5'd1, 3'b111, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != {16'd0, reg_b[i][7:0], reg_a[i][7:0]}) $fatal(1,"Error in PACKH");

            // PACK
            instruction = {7'b0000100, i[4:0], i[4:0] + 5'd1, 3'b100, i[4:0] + 5'd2, 7'b0110011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != {reg_b[i][15:0], reg_a[i][15:0]}) $fatal(1,"Error in PACK");

            // RORI
            // Treat reg_b random value as the immediate shamt
            instruction = {7'b0110000, reg_b[i][4:0], i[4:0] + 5'd1, 3'b101, i[4:0] + 5'd2, 7'b0010011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != (reg_a[i] >> reg_b[i][4:0] | reg_a[i] << (32-reg_b[i][4:0]))) $fatal(1,"Error in RORI");

            // BREV8
            instruction = {12'b011010000111, i[4:0] + 5'd1, 3'b101, i[4:0] + 5'd2, 7'b0010011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != { reg_a[i][24], reg_a[i][25], reg_a[i][26], reg_a[i][27], reg_a[i][28], reg_a[i][29], reg_a[i][30], reg_a[i][31],
                            reg_a[i][16], reg_a[i][17], reg_a[i][18], reg_a[i][19], reg_a[i][20], reg_a[i][21], reg_a[i][22], reg_a[i][23],
                            reg_a[i][ 8], reg_a[i][ 9], reg_a[i][10], reg_a[i][11], reg_a[i][12], reg_a[i][13], reg_a[i][14], reg_a[i][15],
                            reg_a[i][ 0], reg_a[i][ 1], reg_a[i][ 2], reg_a[i][ 3], reg_a[i][ 4], reg_a[i][ 5], reg_a[i][ 6], reg_a[i][ 7]  }) $fatal(1,"Error in BREV8");

            // REV8
            instruction = {12'b011010011000, i[4:0] + 5'd1, 3'b101, i[4:0] + 5'd2, 7'b0010011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != {reg_a[i][7:0],reg_a[i][15:8],reg_a[i][23:16],reg_a[i][31:24]}) $fatal(1,"Error in REV8");

            // ZIP
            instruction = {12'b000010001111, i[4:0] + 5'd1, 3'b001, i[4:0] + 5'd2, 7'b0010011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != { reg_a[i][31], reg_a[i][15],
                            reg_a[i][30], reg_a[i][14],
                            reg_a[i][29], reg_a[i][13],
                            reg_a[i][28], reg_a[i][12],
                            reg_a[i][27], reg_a[i][11],
                            reg_a[i][26], reg_a[i][10],
                            reg_a[i][25], reg_a[i][ 9],
                            reg_a[i][24], reg_a[i][ 8],
                            reg_a[i][23], reg_a[i][ 7],
                            reg_a[i][22], reg_a[i][ 6],
                            reg_a[i][21], reg_a[i][ 5],
                            reg_a[i][20], reg_a[i][ 4],
                            reg_a[i][19], reg_a[i][ 3],
                            reg_a[i][18], reg_a[i][ 2],
                            reg_a[i][17], reg_a[i][ 1],
                            reg_a[i][16], reg_a[i][ 0]}) $fatal(1,"Error in ZIP");

            // UNZIP
            instruction = {12'b000010001111, i[4:0] + 5'd1, 3'b101, i[4:0] + 5'd2, 7'b0010011};
            custom_instruction (instruction, reg_a[i], reg_b[i], i % 16, 1'b0, 0, result);
            if (result != { reg_a[i][31], reg_a[i][29], reg_a[i][27], reg_a[i][25],
                            reg_a[i][23], reg_a[i][21], reg_a[i][19], reg_a[i][17],
                            reg_a[i][15], reg_a[i][13], reg_a[i][11], reg_a[i][ 9],
                            reg_a[i][ 7], reg_a[i][ 5], reg_a[i][ 3], reg_a[i][ 1],

                            reg_a[i][30], reg_a[i][28], reg_a[i][26], reg_a[i][24],
                            reg_a[i][22], reg_a[i][20], reg_a[i][18], reg_a[i][16],
                            reg_a[i][14], reg_a[i][12], reg_a[i][10], reg_a[i][ 8],
                            reg_a[i][ 6], reg_a[i][ 4], reg_a[i][ 2], reg_a[i][ 0]}) $fatal(1,"Error in UNZIP");
            repeat (10) @(negedge CLK);

            // UNKNOWN
        end
        repeat(10) @(posedge CLK);

        $finish;
    end

    ////////////////////////
    // Custom instruction //
    ////////////////////////
    task automatic custom_instruction;
        input  [31:0] instr;
        input  [31:0] opa;
        input  [31:0] opb;
        input  [3:0]  id;
        input         should_kill;
        input integer mem_delay_cycles;
        output [31:0] result;

        begin
            $display("[XIF TX] Instruction {rs1_addr=%d, rs2_addr=%d, rd_addr=%d, opcode=7'h5B} with id=%d, rs1=%d, rs2=%d issued at %0t ns", instr[19:15], instr[24:20], instr[11:7], id, opa, opb, $time);

            ///////////////////////////////////////////
            // Issue, Register and Commit interfaces //
            ///////////////////////////////////////////
            // NOTE: This only works for processors that have X_ISSUE_REGISTER_SPLIT = 0 => Issue and register are issued at the same time.
            // NOTE: This is for processors that commit at the same time they issue/register => Ex.: cv32e20
            ISSUE_VALID_top     = 1'b1;
            ISSUE_REQ_INSTR_top = instr;
            ISSUE_REQ_ID_top    = id;

            REGISTER_VALID_top    = 1'b1;
            REGISTER_ID_top       = id;
            REGISTER_RSA_top      = opa;
            REGISTER_RSB_top      = opb;
            REGISTER_RS_VALID_top = 2'b11;

            COMMIT_VALID_top = 1'b1;
            COMMIT_ID_top    = id;
            COMMIT_KILL_top  = should_kill;

            // Wait for the clock edge where the CVXIF interface accepts the instruction
            do begin
                @(posedge CLK);
            end while (!REGISTER_READY_top && !ISSUE_READY_top);

            if (!ISSUE_RESP_ACCEPT_top) begin
                $display("CVXIF instruction rejected.");
                disable custom_instruction;
            end else $display("CVXIF instruction accepted.");

            // De-assert immediately on the next cycle
            ISSUE_VALID_top = 1'b0;
            ISSUE_REQ_INSTR_top = 32'd0;
            ISSUE_REQ_ID_top    = 4'd0;

            REGISTER_VALID_top    = 1'b0;
            REGISTER_ID_top       = 4'd0;
            REGISTER_RSA_top      = 32'd0;
            REGISTER_RSB_top      = 32'd0;
            REGISTER_RS_VALID_top = 2'd0;

            COMMIT_VALID_top = 1'b0;
            COMMIT_ID_top    = 4'd0;
            COMMIT_KILL_top  = 1'b0;

            //////////////////////
            // Result interface //
            //////////////////////
            // Arbitrary delay (pipeline stall)
            repeat (mem_delay_cycles) begin
                @(posedge CLK);
            end

            RESULT_READY_top = 1'b1;

            // do begin
            //     @(posedge CLK);
            // end while (!RESULT_VALID_top);
            #1;
            while (!RESULT_VALID_top) begin
                @(posedge CLK);
            end
            result = RESULT_DATA_top;

            $display("[XIF RX] Response received for ID %d. result.id=%d, result.data=%d, result.rd=%d, result.we=%b at %0t ns", 
                     id, RESULT_ID_top, RESULT_DATA_top, RESULT_RD_top, RESULT_WE_top, $time);
            $display("");

            RESULT_READY_top = 1'b0;
        end
    endtask

    // JTAG
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
