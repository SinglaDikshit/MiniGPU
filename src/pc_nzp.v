module pc_nzp(
input [7:0] alu_out,
input clk,
input reset,
input [2:0] core_state,
input [7:0] current_pc,
input branch_enable,
input nzp_write_enable,
input [2:0]decoded_nzp,
input [7:0]immediate,
input enable,
output reg next_pc,
output reg nzp_flags
);
reg [2:0] internal_nzp;

always@(posedge clk)
begin
if(reset)
begin
next_pc<= 8'b0;
nzp_flags<= 3'b0;
internal_nzp<= 3'b0;
end
else begin
if (core_state == 3'b110 && nzp_write_enable) begin
internal_nzp <=alu_out[2:0];
nzp_flags <= alu_out[2:0]; end

// Update PC during EXECUTE state
            if (enable && core_state == 3'b101) begin // EXECUTE state
                if (branch_enable) begin
                    // Check branch condition using decoded_nzp and current nzp_flags
                    reg branch_taken;
                    branch_taken = 1'b0;

                    // Check N flag
                    if (decoded_nzp[2] && internal_nzp[2]) // N flag
                        branch_taken = 1'b1;
                    // Check Z flag    
                    if (decoded_nzp[1] && internal_nzp[1]) // Z flag
                        branch_taken = 1'b1;
                    // Check P flag
                    if (decoded_nzp[0] && internal_nzp[0]) // P flag
                        branch_taken = 1'b1;

                    if (branch_taken)
                        next_pc <= immediate;
                    else
                        next_pc <= current_pc + 1;
                end
                else begin
                    // Linear flow
                    next_pc <= current_pc + 1;
                end
            end
        end
    end

endmodule