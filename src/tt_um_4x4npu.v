`default_nettype none

module tt_um_4x4npu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire [3:0] result;
    wire done, result_valid, overflow, accumulator_negative;

    npu4_core core (
        .data_in(ui_in),
        .command(uio_in[2:0]),
        .parameter_in(uio_in[7:4]),
        .command_valid(uio_in[3]),
        .clk(clk), .rst_n(rst_n), .enable(ena),
        .result(result), .done(done), .result_valid(result_valid),
        .overflow(overflow), .accumulator_negative(accumulator_negative)
    );

    assign uo_out = {result_valid, accumulator_negative, overflow, done, result};
    assign uio_out = 8'h00;
    assign uio_oe = 8'h00;
endmodule

`default_nettype wire
