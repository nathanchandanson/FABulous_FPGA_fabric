module chacha20_qr (
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [31:0] c_i,
    input  logic [31:0] d_i,
    input  logic        valid_i,
    output logic        ready_o,

    output logic [31:0] a_o,
    output logic [31:0] b_o,
    output logic [31:0] c_o,
    output logic [31:0] d_o,
    output logic        done_o
);

    // a += b; d ^= a; d = CHACHA20_ROTL(d, 16);
    // c += d; b ^= c; b = CHACHA20_ROTL(b, 12);
    // a += b; d ^= a; d = CHACHA20_ROTL(d,  8);
    // c += d; b ^= c; b = CHACHA20_ROTL(b,  7)
    typedef enum logic [2:0] {
        StIdle,
        StAxr0,
        StAxr1,
        StAxr2,
        StAxr3
    } state_e;
    state_e state_d, state_q;

    logic [31:0] a_d, b_d, c_d, d_d;
    logic [31:0] a_q, b_q, c_q, d_q;

    logic [31:0] x_i, y_i, z_i, shamt_i;
    logic [31:0] x_o, z_o;

    ////////////////////
    // State handling //
    ////////////////////
    // Sequential update
    always_ff @(posedge clk_i) begin
        if (rst_i) state_q <= StIdle;
        else       state_q <= state_d;
    end

    // Combinational update
    always_comb begin
        state_d = state_q;
        unique case (state_q)
            StIdle: if (valid_i) state_d = StAxr0;
            StAxr0:              state_d = StAxr1;
            StAxr1:              state_d = StAxr2;
            StAxr2:              state_d = StAxr3;
            StAxr3:              state_d = valid_i ? StAxr0 : StIdle;
            default:             state_d = StIdle;
        endcase
    end

    //////////////////////////////
    // Signals/outputs handling //
    //////////////////////////////
    // Sequential update
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            a_q <= '0;
            b_q <= '0;
            c_q <= '0;
            d_q <= '0;
            a_o <= '0;
            b_o <= '0;
            c_o <= '0;
            d_o <= '0;
            done_o <= 1'b0;
        end else begin
            if (state_q == StAxr3) begin
                // NOTE: At the end, only b and c are recomputed: a and d are
                // the previous ones
                a_o <= a_q;
                b_o <= z_o;
                c_o <= x_o;
                d_o <= d_q;
            end

            a_q <= a_d;
            b_q <= b_d;
            c_q <= c_d;
            d_q <= d_d;

            done_o <= (state_q == StAxr3) ? 1'b1 : 1'b0;
        end
    end

    // Combinational update
    always_comb begin
        // Addition XOR Rotate inputs
        x_i     = '0;
        y_i     = '0;
        z_i     = '0;
        shamt_i = '0;
        // Current values
        a_d = a_q;
        b_d = b_q;
        c_d = c_q;
        d_d = d_q;
        // Output values
        ready_o = (state_q == StIdle || state_q == StAxr3);

        unique case (state_q)
            StIdle: begin
                if (valid_i) begin
                    a_d = a_i;
                    b_d = b_i;
                    c_d = c_i;
                    d_d = d_i;
                end
            end
            StAxr0: begin
                // Inputs
                x_i     = a_q;
                y_i     = b_q;
                z_i     = d_q;
                shamt_i = 'd16;
                // Outputs
                a_d     = x_o;
                d_d     = z_o;
            end
            StAxr1: begin
                // Inputs
                x_i     = c_q;
                y_i     = d_q;
                z_i     = b_q;
                shamt_i = 'd12;
                // Outputs
                c_d     = x_o;
                b_d     = z_o;
            end
            StAxr2: begin
                // Inputs
                x_i     = a_q;
                y_i     = b_q;
                z_i     = d_q;
                shamt_i = 'd8;
                // Outputs
                a_d     = x_o;
                d_d     = z_o;
            end
            StAxr3: begin
                // Inputs
                x_i     = c_q;
                y_i     = d_q;
                z_i     = b_q;
                shamt_i = 'd7;
                // Outputs: useless ?
                c_d     = x_o;
                b_d     = z_o;
                if (valid_i) begin
                    a_d = a_i;
                    b_d = b_i;
                    c_d = c_i;
                    d_d = d_i;
                end
            end
        endcase
    end

    chacha20_axr i_chacha20_axr(
        .x_i,
        .y_i,
        .z_i,
        .shamt_i,

        .x_o,
        .z_o
    );

endmodule
