module pc_nzp(
input [7:0] alu_out;
input clk;
input reset;
input [2:0] core_state;
input [7:0] current_pc;
input branch_enable;
input nzp_write_enable;
input [2:0]nzp;
input [7:0]immediate;
input enable;
output reg next_pc;
output reg nzp_flags;
);
reg [2:0] internal;

always@(posedge clk)
begin
if(reset)
begin
next_pc<= 8'b0;
nzp_flags<= 3'b0;
internal<= 3'b0;
end
else begin
if (core state == 3'b110 && nzp_write_enable) begin
internal <=alu_out[2:0];
nzp_flags <= alu_out[2:0]; end
else
