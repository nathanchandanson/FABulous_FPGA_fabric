module top(
    input  wire        clk,
    input  wire [27:0] io_in,
    output wire [27:0] io_out,
    output wire [27:0] io_oeb
);

    // Master OBI
    wire        REQ;
    wire        WE;
    wire [3: 0] BE;
    wire [23:0] ADDR;
    wire [31:0] WDATA;
    wire        GNT;
    wire        RVALID;
    wire [31:0] RDATA;

    // Control signals
    wire rst;
    wire valid, valid_strobe;
    wire write_en_d;
    wire [8:0]  address_d;
    wire [15:0] data_d;
    reg  [8:0]  address_q;
    reg  [15:0] data_q;
    reg write_en_q;
    reg valid_q;

    localparam IDLE = 0,
               REQUEST = 1,
               READ = 2,
               WRITE = 3;
    reg [1:0] state_d;
    reg [1:0] state_q;

    assign rst = io_in[27];
    assign valid      = io_in[26];
    assign write_en_d = io_in[25];
    assign address_d  = io_in[24:16];
    assign data_d     = io_in[15:0];
    always @(posedge clk) begin
        valid_q <= valid;
    end
    assign valid_strobe = (valid_q == 1'b0 && valid == 1'b1) ? 1'b1 : 1'b0;
    always @(posedge clk) begin
        if (rst) begin
            address_q  <= 9'd0;
            data_q     <= 16'd0;
            write_en_q <= 1'b0;
        end else if (state_q == IDLE) begin
            address_q  <= address_d;
            data_q     <= data_d;
            write_en_q <= write_en_d;
        end
    end


    // Assign output
    assign io_oeb = 28'd0;
    assign io_out = {address_q[7:0], data_q[15:0], valid_strobe, 1'd0, state_q};
    // assign io_out = {RDATA[23:0], 2'd0, state_q};
    // assign io_out = (state_q == READ && RVALID) ? RDATA[27:0] : 28'd0;

    // FSM
    always @(*) begin
        state_d = state_q;
        case(state_q)
            IDLE: begin
                if (valid_strobe) state_d = REQUEST;
            end
            REQUEST: begin
                if (GNT) begin
                    if (write_en_q) state_d = WRITE;
                    else            state_d = READ;
                end
            end
            READ: begin
                if (RVALID) state_d = IDLE;
            end
            WRITE: begin
                if (RVALID) state_d = IDLE;
            end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state_q <= IDLE;
        end else begin
            state_q <= state_d;
        end
    end

    // Assign the OBI signals
    assign REQ   = (state_q == REQUEST) ? 1'b1 : 1'b0;
    assign WE    = write_en_q;
    assign BE    = 4'b1111;
    assign ADDR  = {15'd0, address_q};
    assign WDATA = {16'd0, data_q};

    OBI_MASTER_wrapper OBI_MASTER_wrapper_inst (
        .REQ(REQ),
        .WE(WE),
        .BE(BE),
        .ADDR(ADDR),
        .WDATA(WDATA),

        .GNT(GNT),
        .RVALID(RVALID),
        .RDATA(RDATA)
    );

endmodule
