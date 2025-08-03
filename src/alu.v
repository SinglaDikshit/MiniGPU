`timescale 1ns/1ns
module alu (
    input clk,
    input reset,
    input enable,
    input [2:0] core_state,
    input [1:0] decoded_alu_arithmetic_mux,
    input decoded_alu_output_mux,
    input [7:0] rs,
    input [7:0] rt,
    output reg [7:0] alu_out
);

    // Internal register to hold output
    reg [7:0] internal_result;

    always @(posedge clk) begin
        if (reset) begin
            alu_out <= 8'b0;
            internal_result <= 8'b0;
        end
        else if (enable && core_state == 3'b101) begin // EXECUTE phase
            if (decoded_alu_output_mux == 1'b1) begin
                // Compute NZP flags
                reg N, Z, P;
                if (rs < rt) begin
                    N = 1'b1;
                    Z = 1'b0;
                    P = 1'b0;
                end
                else if (rs == rt) begin
                    N = 1'b0;
                    Z = 1'b1;
                    P = 1'b0;
                end
                else begin // rs > rt
                    N = 1'b0;
                    Z = 1'b0;
                    P = 1'b1;
                end
                alu_out <= {5'b00000, N, Z, P};
            end
            else begin
                // Perform arithmetic operation
                case (decoded_alu_arithmetic_mux)
                    2'b00: internal_result = rs + rt;        // ADD
                    2'b01: internal_result = rs - rt;        // SUB
                    2'b10: internal_result = rs * rt;        // MUL (lower 8 bits)
                    2'b11: begin                             // DIV
                        if (rt != 8'b0)
                            internal_result = rs / rt;
                        else
                            internal_result = 8'bx; // undefined behavior
                    end
                    default: internal_result = 8'b0;
                endcase
                alu_out <= internal_result;
            end
        end
    end

endmodule