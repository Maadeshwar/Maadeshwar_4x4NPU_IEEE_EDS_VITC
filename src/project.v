`default_nettype none

// Tiny Tapeout / IHP SG13G2 StreamDot-4 accelerator.
//
// Inputs
//   ui_in[3:0] : signed two's-complement operand A (-8..7)
//   ui_in[7:4] : signed two's-complement operand B (-8..7)
//   uio_in[0]  : VALID; add A*B on the next rising edge
//   uio_in[1]  : CLEAR; clear accumulator and sticky overflow
//   uio_in[3:2]: output page select
//   uio_in[4]  : CONTINUOUS mode; keep accepting MACs beyond four terms
//   uio_in[7:5]: activation/output mode
//
// Outputs
//   page 0: uo_out = activation-mode output derived from the accumulator
//   page 1: uo_out[3:0] = accumulator bits [11:8]
//   page 2: uo_out[0] = sticky saturation/overflow flag
//   page 3: uo_out[0] = accepted, uo_out[1] = ready,
//            uo_out[2] = four-term DONE, uo_out[4:3] = term count
//
// The 12-bit signed accumulator saturates at -2048 and +2047. CLEAR has
// priority over VALID. The design has no inferred memories or analog blocks.
module tt_um_streamdot4 (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);
    localparam signed [11:0] ACC_MAX = 12'sd2047;
    localparam signed [11:0] ACC_MIN = -12'sd2048;

    reg signed [11:0] acc;
    reg                overflow;
    reg                accepted;
    reg                dot_done;
    reg        [1:0]   term_count;

    wire signed [3:0] a = $signed(ui_in[3:0]);
    wire signed [3:0] b = $signed(ui_in[7:4]);
    wire signed [7:0] a_ext = {{4{a[3]}}, a};
    wire signed [7:0] b_ext = {{4{b[3]}}, b};
    wire signed [7:0] product = a_ext * b_ext;
    wire signed [12:0] extended_sum =
        {{1{acc[11]}}, acc} + {{5{product[7]}}, product};
    wire continuous_mode = uio_in[4];
    wire [2:0] activation_mode = uio_in[7:5];
    wire do_clear = ena && uio_in[1];
    wire do_mac = ena && uio_in[0] && !uio_in[1] &&
                  (continuous_mode || !dot_done);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc      <= 12'sd0;
            overflow <= 1'b0;
            accepted <= 1'b0;
            dot_done <= 1'b0;
            term_count <= 2'd0;
        end else begin
            accepted <= 1'b0;

            if (do_clear) begin
                acc      <= 12'sd0;
                overflow <= 1'b0;
                dot_done <= 1'b0;
                term_count <= 2'd0;
            end else if (do_mac) begin
                accepted <= 1'b1;
                if (!continuous_mode) begin
                    if (term_count == 2'd3) begin
                        dot_done <= 1'b1;
                    end else begin
                        term_count <= term_count + 1'b1;
                    end
                end
                if (extended_sum > 13'sd2047) begin
                    acc      <= ACC_MAX;
                    overflow <= 1'b1;
                end else if (extended_sum < -13'sd2048) begin
                    acc      <= ACC_MIN;
                    overflow <= 1'b1;
                end else begin
                    acc <= extended_sum[11:0];
                end
            end
        end
    end

    wire signed [12:0] acc_ext = {acc[11], acc};
    wire signed [12:0] abs_ext = acc_ext[12] ? -acc_ext : acc_ext;
    reg [7:0] output_page;
    always @(*) begin
        case (uio_in[3:2])
            2'd0: begin
                case (activation_mode)
                    3'd0: output_page = acc[7:0];
                    3'd1: output_page = acc[11] ? 8'h00 : acc[7:0];
                    3'd2: output_page = abs_ext[7:0];
                    3'd3: output_page = (acc > 0) ? 8'h01 : 8'h00;
                    3'd4: begin
                        if (acc > 12'sd127) output_page = 8'h7f;
                        else if (acc < -12'sd128) output_page = 8'h80;
                        else output_page = acc[7:0];
                    end
                    3'd5: output_page = acc[11] ? 8'hff : 8'h00;
                    default: output_page = acc[7:0];
                endcase
            end
            2'd1: output_page = {4'b0000, acc[11:8]};
            2'd2: output_page = {7'b0000000, overflow};
            default: output_page = {3'b000, term_count, dot_done,
                                    ena && rst_n, accepted};
        endcase
    end

    assign uo_out  = output_page;
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

endmodule

`default_nettype wire
