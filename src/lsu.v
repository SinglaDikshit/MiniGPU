module lsu(
    input clk,
    input reset,
    input enable,
    input [7:0] core_state,
    input [7:0] rs,
    input [7:0] rt,
    input decoded_mem_read_enable,
    input decoded_mem_write_enable,
    output reg mem_read_valid,
    output reg [7:0] mem_read_address, 
    input mem_read_ready,
    input [7:0] mem_read_data,
    output reg mem_write_valid,
    output reg [7:0] mem_write_address,
    input mem_write_data,
    input [7:0] mem_write_ready,
    output reg [7:0] lsu_out,
    output reg [1:0] lsu_state
);

localparam IDLE = 2'd0,
           REQUEST = 2'd1,
           WAIT = 2'd2,
           DONE = 2'd3;

always @(posedge clk) begin
    if (reset) begin
        lsu_out <= 8'd0;
        lsu_state <= IDLE;
        mem_read_address <= 8'd0;
        mem_read_valid <= 1'b0;
        mem_write_valid <= 1'b0;
        mem_write_address <= 8'd0;
    end else begin
        if (enable) begin
            // Memory Read FSM
            if (decoded_mem_read_enable) begin
                case (lsu_state)
                    IDLE: begin
                        if (core_state == 8'd1)
                            lsu_state <= REQUEST;
                    end
                    REQUEST: begin
                        mem_read_valid <= 1'b1;
                        mem_read_address <= rs;
                        lsu_state <= WAIT;
                    end
                    WAIT: begin
                        if (mem_read_ready) begin
                            lsu_out <= mem_read_data;
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin
                        if (core_state == 8'd3) begin
                            lsu_state <= IDLE;
                            mem_read_valid <= 1'b0;
                        end
                    end
                endcase
            end

            // Memory Write FSM
            if (decoded_mem_write_enable) begin
                case (lsu_state)
                    IDLE: begin
                        if (core_state == 8'd1)
                            lsu_state <= REQUEST;
                    end
                    REQUEST: begin
                        mem_write_valid <= 1'b1;
                        mem_write_address <= rs;
                        lsu_state <= WAIT;
                    end
                    WAIT: begin
                        if (mem_write_data) begin
                            lsu_out <= mem_write_ready;
                            lsu_state <= DONE;
                        end
                    end
                    DONE: begin
                        if (core_state == 8'd3) begin
                            lsu_state <= IDLE;
                            mem_write_valid <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
end

endmodule
