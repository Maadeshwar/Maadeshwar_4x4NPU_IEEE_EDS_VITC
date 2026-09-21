`default_nettype none

module int4_quantizer (
    input  wire signed [15:0] value,
    input  wire [3:0] shift_amount,
    input  wire relu_enable,
    output reg [3:0] result
);
    reg signed [15:0] activated;
    reg signed [15:0] shifted;

    always @(*) begin
        activated = (relu_enable && value < 0) ? 16'sd0 : value;
        shifted = activated >>> shift_amount;
        if (shifted > 16'sd7)
            result = 4'h7;
        else if (shifted < -16'sd8)
            result = 4'h8;
        else
            result = shifted[3:0];
    end
endmodule

`default_nettype wire
