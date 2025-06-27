module register_file (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [2:0] core_state,
    input wire [3:0] block_id,
    input wire [3:0] thread_id,
    input wire [3:0] threads_per_block,
    input wire [3:0] read_addr1,
    input wire [3:0] read_addr2,
    input wire [3:0] write_addr,
    input wire [7:0] write_data,
    input wire write_enable,
    output wire [7:0] read_data1,
    output wire [7:0] read_data2
);

    // 16 registers, each 8 bits wide
    reg [7:0] registers [15:0];

    // Dedicated registers for GPU constants
    parameter BLOCK_ID_REG = 4'd13;      // Register 13 for block ID
    parameter THREAD_ID_REG = 4'd14;     // Register 14 for thread ID
    parameter THREADS_PB_REG = 4'd15;    // Register 15 for threads per block

    // Continuous assignment for read operations
    assign read_data1 = registers[read_addr1];
    assign read_data2 = registers[read_addr2];

    always @(posedge clk) begin
        if (reset) begin
            // Clear all registers on reset
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                registers[i] <= 8'b0;
            end
        end
        else if (enable && core_state == 3'b011) begin // REQUEST state
            // Update dedicated registers
            registers[BLOCK_ID_REG] <= block_id;
            registers[THREAD_ID_REG] <= thread_id;
            registers[THREADS_PB_REG] <= threads_per_block;

            // Handle write operations
            if (write_enable) begin
                registers[write_addr] <= write_data;
            end
        end
    end

endmodule