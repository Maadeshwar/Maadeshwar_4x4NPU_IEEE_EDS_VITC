`default_nettype none

// Original two-lane INT4 neural datapath with a three-process FSM.
module npu4_core (
    input  wire [7:0] data_in,
    input  wire [2:0] command,
    input  wire [3:0] parameter_in,
    input  wire       command_valid,
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output wire [3:0] result,
    output reg        done,
    output reg        result_valid,
    output reg        overflow,
    output wire       accumulator_negative
);
    localparam CMD_NOP        = 3'b000;
    localparam CMD_CLEAR      = 3'b001;
    localparam CMD_BIAS_LOW   = 3'b010;
    localparam CMD_BIAS_HIGH  = 3'b011;
    localparam CMD_MAC        = 3'b100;
    localparam CMD_RELU       = 3'b101;
    localparam CMD_LINEAR     = 3'b110;
    localparam CMD_READ_ACC   = 3'b111;

    localparam ST_IDLE = 2'd0;
    localparam ST_EXEC = 2'd1;
    localparam ST_DONE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] command_q;
    reg [7:0] data_q;
    reg [3:0] parameter_q;
    reg [3:0] bias_low [0:1];
    reg signed [15:0] accumulator [0:1];
    reg [3:0] result_q;

    wire lane = data_q[0];
    wire signed [3:0] activation = $signed(data_q[3:0]);
    wire signed [3:0] weight0 = $signed(data_q[7:4]);
    wire signed [3:0] weight1 = $signed(parameter_q);
    wire signed [7:0] product0;
    wire signed [7:0] product1;
    wire signed [16:0] sum0 = {accumulator[0][15], accumulator[0]} +
                              {{9{product0[7]}}, product0};
    wire signed [16:0] sum1 = {accumulator[1][15], accumulator[1]} +
                              {{9{product1[7]}}, product1};
    wire signed [15:0] selected_acc = lane ? accumulator[1] : accumulator[0];
    wire [3:0] relu_result;
    wire [3:0] linear_result;

    int4_multiplier mult0(.a(activation), .b(weight0), .product(product0));
    int4_multiplier mult1(.a(activation), .b(weight1), .product(product1));
    int4_quantizer quant_relu(
        .value(selected_acc), .shift_amount(parameter_q), .relu_enable(1'b1),
        .result(relu_result)
    );
    int4_quantizer quant_linear(
        .value(selected_acc), .shift_amount(parameter_q), .relu_enable(1'b0),
        .result(linear_result)
    );

    assign result = result_q;
    assign accumulator_negative = selected_acc[15];

    // FSM process 1: registered state.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else state <= next_state;
    end

    // FSM process 2: next-state logic.
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: if (enable && command_valid) next_state = ST_EXEC;
            ST_EXEC: next_state = ST_DONE;
            ST_DONE: next_state = ST_IDLE;
            default: next_state = ST_IDLE;
        endcase
    end

    // FSM process 3: command capture, datapath, and registered outputs.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            command_q <= CMD_NOP;
            data_q <= 8'd0;
            parameter_q <= 4'd0;
            bias_low[0] <= 4'd0;
            bias_low[1] <= 4'd0;
            accumulator[0] <= 16'sd0;
            accumulator[1] <= 16'sd0;
            result_q <= 4'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            overflow <= 1'b0;
        end else begin
            done <= 1'b0;

            if (state == ST_IDLE && enable && command_valid) begin
                command_q <= command;
                data_q <= data_in;
                parameter_q <= parameter_in;
            end

            if (state == ST_EXEC) begin
                case (command_q)
                    CMD_CLEAR: begin
                        bias_low[0] <= 4'd0;
                        bias_low[1] <= 4'd0;
                        accumulator[0] <= 16'sd0;
                        accumulator[1] <= 16'sd0;
                        result_q <= 4'd0;
                        result_valid <= 1'b0;
                        overflow <= 1'b0;
                    end
                    CMD_BIAS_LOW: begin
                        bias_low[lane] <= parameter_q;
                    end
                    CMD_BIAS_HIGH: begin
                        accumulator[lane] <= {{8{parameter_q[3]}}, parameter_q,
                                               bias_low[lane]};
                        result_valid <= 1'b0;
                        overflow <= 1'b0;
                    end
                    CMD_MAC: begin
                        if (sum0 > 17'sd32767) begin
                            accumulator[0] <= 16'sh7fff;
                            overflow <= 1'b1;
                        end else if (sum0 < -17'sd32768) begin
                            accumulator[0] <= 16'sh8000;
                            overflow <= 1'b1;
                        end else begin
                            accumulator[0] <= sum0[15:0];
                        end
                        if (sum1 > 17'sd32767) begin
                            accumulator[1] <= 16'sh7fff;
                            overflow <= 1'b1;
                        end else if (sum1 < -17'sd32768) begin
                            accumulator[1] <= 16'sh8000;
                            overflow <= 1'b1;
                        end else begin
                            accumulator[1] <= sum1[15:0];
                        end
                    end
                    CMD_RELU: begin
                        result_q <= relu_result;
                        result_valid <= 1'b1;
                        done <= 1'b1;
                    end
                    CMD_LINEAR: begin
                        result_q <= linear_result;
                        result_valid <= 1'b1;
                        done <= 1'b1;
                    end
                    CMD_READ_ACC: begin
                        case (parameter_q[1:0])
                            2'd0: result_q <= selected_acc[3:0];
                            2'd1: result_q <= selected_acc[7:4];
                            2'd2: result_q <= selected_acc[11:8];
                            default: result_q <= selected_acc[15:12];
                        endcase
                        result_valid <= 1'b1;
                        done <= 1'b1;
                    end
                    default: begin end
                endcase
            end
        end
    end
endmodule

`default_nettype wire
