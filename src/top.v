// File: top.v (Modified for Flattened Bus Interface)
`default_nettype none

module top #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4,
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire device_control_write_enable,
    input wire [7:0] device_control_data,

    // Flattened Program memory interface
    input wire [15:0] prog_mem_read_data,
    input wire prog_mem_read_ready,
    output wire prog_mem_read_valid,
    output wire [ADDR_BITS-1:0] prog_mem_read_address,

    // Flattened Data memory interface  
    input wire [DATA_BITS*4-1:0] data_mem_read_data,
    input wire [3:0] data_mem_read_ready,
    input wire [3:0] data_mem_write_ready,
    output wire [3:0] data_mem_read_valid,
    output wire [3:0] data_mem_write_valid,
    output wire [ADDR_BITS*4-1:0] data_mem_read_address,
    output wire [ADDR_BITS*4-1:0] data_mem_write_address,
    output wire [DATA_BITS*4-1:0] data_mem_write_data,

    output wire done
);

    // Device Control Register
    wire [7:0] thread_count;

    device_control_register dcr (
        .clk(clk),
        .reset(reset),
        .device_control_write_enable(device_control_write_enable),
        .device_control_data(device_control_data),
        .thread_count(thread_count)
    );

    // Dispatcher
    wire [NUM_CORES-1:0] core_start;
    wire [NUM_CORES-1:0] core_reset;
    wire [NUM_CORES-1:0] core_done;
    wire [NUM_CORES*4-1:0] core_block_id;
    wire [NUM_CORES*8-1:0] core_thread_count;

    dispatcher #(
        .NUM_CORES(NUM_CORES),
        .THREADS_PER_BLOCK(THREADS_PER_BLOCK)
    ) disp (
        .clk(clk),
        .reset(reset),
        .start(start),
        .thread_count(thread_count),
        .core_done(core_done),
        .core_start(core_start),
        .core_reset(core_reset),
        .core_block_id(core_block_id),
        .core_thread_count(core_thread_count),
        .done(done)
    );

    // Memory Controller for data memory
    wire [NUM_CORES*THREADS_PER_BLOCK-1:0] consumer_read_valid;
    wire [NUM_CORES*THREADS_PER_BLOCK-1:0] consumer_write_valid;
    wire [NUM_CORES*THREADS_PER_BLOCK*ADDR_BITS-1:0] consumer_read_address;
    wire [NUM_CORES*THREADS_PER_BLOCK*ADDR_BITS-1:0] consumer_write_address;
    wire [NUM_CORES*THREADS_PER_BLOCK*DATA_BITS-1:0] consumer_write_data;
    wire [NUM_CORES*THREADS_PER_BLOCK-1:0] consumer_read_ready;
    wire [NUM_CORES*THREADS_PER_BLOCK-1:0] consumer_write_ready;
    wire [NUM_CORES*THREADS_PER_BLOCK*DATA_BITS-1:0] consumer_read_data;

    memory_controller #(
        .ADDR_BITS(ADDR_BITS),
        .DATA_BITS(DATA_BITS),
        .NUM_CONSUMERS(NUM_CORES*THREADS_PER_BLOCK),
        .NUM_CHANNELS(4),
        .WRITE_ENABLE(1)
    ) mem_ctrl (
        .clk(clk),
        .reset(reset),
        .consumer_read_valid(consumer_read_valid),
        .consumer_write_valid(consumer_write_valid),
        .consumer_read_address(consumer_read_address),
        .consumer_write_address(consumer_write_address),
        .consumer_write_data(consumer_write_data),
        .consumer_read_ready(consumer_read_ready),
        .consumer_write_ready(consumer_write_ready),
        .consumer_read_data(consumer_read_data),
        .mem_read_valid(data_mem_read_valid),
        .mem_write_valid(data_mem_write_valid),
        .mem_read_address(data_mem_read_address),
        .mem_write_address(data_mem_write_address),
        .mem_write_data(data_mem_write_data),
        .mem_read_ready(data_mem_read_ready),
        .mem_write_ready(data_mem_write_ready),
        .mem_read_data(data_mem_read_data)
    );

    // GPU cores instantiation placeholder
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : gpu_cores
            // Place GPU core module instantiation here with unflattened bus split logic
        end
    endgenerate

endmodule
