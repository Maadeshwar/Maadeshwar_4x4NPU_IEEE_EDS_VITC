`default_nettype none
module tb_tt_um_4x4npu;
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg ena, clk, rst_n;

    tt_um_4x4npu dut (.*);
endmodule
`default_nettype wire
