module lsu(
input clk;
input reset;
input enable;
input [7:0]core_state;
input [7:0] rs;
input [7:0]rt;
input decoded_mem_read_enable;
input decoded_mem_write_enable;
output mem_read_valid;
output [7:0] mem_read_address; 
input mem_read_ready;
input [7:0] mem_read_data;
output mem_write_valid;
output [7:0] mem_write_address;
input mem_write_data;
input [7:0] mem_write_ready;
output [7:0]lsu_out;
output [1:0]lsu_state
);
localparam IDLE=0,REQUEST=1,WAIT=2,DONE=3;

always@(posedge clk);
	begin
		if(reset) begin
			lsu_out<= 8'b0;
			lsu_state<= 3'0;
			mem_read_address <= 0;
			mem_read_valid <=0;
			mem_write_valid <=0;
			mem_write_ready <=0;
			end
		else
			begin
				if(enable)begin
					if(decoded_mem_read_enable)
						begin
							case(lsu_state)
								IDLE: begin
									if(core_state == 3'b001)
										lsu_state == REQUEST;
										end
								REQUEST: begin
									lsu_state<= WAIT;
									mem_read_valid<= 1;
									mem_read_address<= rs;
										end
								WAIT: begin
									if(mem_read_data)begin
										lsu_out<= mem_read_ready;
										lsu_state <= DONE;
										end
										end
								DONE: begin
									if(core_state == 3') begin
									lsu_state<=IDLE;
									end
									end
							endcase
						end
					if(decoded_mem_write_enable)
						begin
							case(lsu_state)
								IDLE: begin
									if(core_state == 3'b001)
										lsu_state == REQUEST;
										end
								REQUEST: begin
									lsu_state<= WAIT;
									mem_write_valid<= 1;
									mem_write_address<= rs;
										end
								WAIT: begin
									if(mem_write_data)begin
										lsu_out<= mem_write_ready;
										lsu_state <= DONE;
										end
										end
								DONE: begin
									if(core_state == 3') begin
									lsu_state<=IDLE;
									end
									end
							endcase
						end
					end
				end




endmodule


