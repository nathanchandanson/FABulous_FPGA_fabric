module eFPGA_Config #(
    parameter int NumberOfRows    = 16,
    parameter int FrameBitsPerRow = 32,
    parameter int NumberOfCols    = 13,
    parameter int MaxFramesPerCol = 20,
    parameter int DesyncFlagIdx   = 20,
    parameter logic[FrameBitsPerRow-1:0] SyncWord = FrameBitsPerRow'(32'hFAB0FAB1)
) (
    input logic clk_i,
    input logic reset_ni,

    input logic [FrameBitsPerRow-1:0] write_data_i,
    input logic                       write_valid_i,

    output logic [(FrameBitsPerRow*NumberOfRows)-1:0] fabric_frame_data_o,
    output logic [(MaxFramesPerCol*NumberOfCols)-1:0] fabric_frame_strobe_o,

    output logic fsm_synced_o
);

    logic [$clog2(NumberOfRows)-1:0] row_current_word;
    logic [FrameBitsPerRow-1:0] header_current_packet;

    ////////////////
    // Config FSM //
    ////////////////
    typedef enum {
        StIdle, StHeader, StPacket
    } state_e;

    state_e state_d, state_q;

    always_comb begin
        unique case (state_q)
            StIdle: begin
                if (write_valid_i && write_data_i == SyncWord) begin
                    state_d = StHeader;
                end else state_d = StIdle;
            end
            StHeader: begin
                if (write_valid_i) begin
                    if (write_data_i[DesyncFlagIdx] == 1'b1) state_d = StIdle;
                    else                                     state_d = StPacket;
                end else state_d = StHeader;
            end
            StPacket: begin
                if (write_valid_i && row_current_word == 0) state_d = StHeader;
                else state_d = StPacket;
            end
        endcase
    end

    always_ff @(posedge clk_i, negedge reset_ni) begin
        if (!reset_ni) begin
            state_q <= StIdle;
        end else begin
            state_q <= state_d;
        end
    end

    assign fsm_synced_o = (state_q != StIdle);

    ///////////////////////////////////
    // Capture and update the values //
    ///////////////////////////////////
    always_ff @(posedge clk_i) begin
        if (write_valid_i) begin
            unique case (state_q)
                StIdle: begin
                    header_current_packet <= '0;
                    row_current_word <= '0;
                end
                StHeader: begin
                    if (write_data_i[DesyncFlagIdx] == 1'b0) begin
                        header_current_packet <= write_data_i;
                        row_current_word <= NumberOfRows - 1'b1;
                    end
                end
                StPacket: begin
                    row_current_word <= row_current_word - 1'b1;
                end
            endcase
        end
    end

    /////////////////////////////
    // Write the fabric_data_o //
    /////////////////////////////
    generate
        for (genvar i = 0; i < NumberOfRows; i++) begin: gen_fabric_data_o
            always_latch begin
                if (row_current_word == i && state_q == StPacket && write_valid_i) begin
                    fabric_frame_data_o[FrameBitsPerRow*(i+1)-1:FrameBitsPerRow*i] = write_data_i;
                end
            end
        end
    endgenerate

    ///////////////////////////////
    // Write the fabric_strobe_o //
    ///////////////////////////////
    // if (st packet && write_valid && row_current_word == 0) strobe the correct frame bit
    generate
        for (genvar i = 0; i < NumberOfCols; i++) begin: gen_fabric_strobe_o
            assign fabric_frame_strobe_o[MaxFramesPerCol*(i+1)-1:MaxFramesPerCol*i]
                   = (state_q == StPacket && header_current_packet[31:27] == i && row_current_word == '0 && write_valid_i)
                      ? header_current_packet[19:0]
                      : '0;
        end
    endgenerate

endmodule
