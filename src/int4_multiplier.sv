`default_nettype none

module int4_multiplier (
    input  wire signed [3:0] a,
    input  wire signed [3:0] b,
    output wire signed [7:0] product
);
    assign product = a * b;
endmodule

`default_nettype wire
