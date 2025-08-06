// Modified GPU Testbench (gpu_tb.v) compatible with flattened top-level interface
`default_nettype none
`timescale 1ns/1ns

module gpu_tb;

  // Parameters
  parameter DATA_MEM_ADDR_BITS = 8;
  parameter DATA_MEM_DATA_BITS = 8;
  parameter PROGRAM_MEM_ADDR_BITS = 8;
  parameter PROGRAM_MEM_DATA_BITS = 16;

  // Testbench signals
  reg clk, reset, start, dcr_write_en;
  reg [7:0] device_control_data;
  wire done;

  // Flattened Memory Interface
  reg [PROGRAM_MEM_DATA_BITS-1:0] prog_mem [0:(1<<PROGRAM_MEM_ADDR_BITS)-1];
  reg [7:0] data_mem [0:(1<<DATA_MEM_ADDR_BITS)-1];

  wire prog_mem_read_ready;
  reg [DATA_MEM_DATA_BITS-1:0] data_mem_read_data;
  reg data_mem_read_ready;
  reg data_mem_write_ready;

  wire [15:0] prog_mem_read_data;
  wire [7:0] prog_mem_read_address;
  wire prog_mem_read_valid;

  wire data_mem_read_valid;
  wire data_mem_write_valid;
  wire [7:0] data_mem_read_address;
  wire [7:0] data_mem_write_address;
  wire [7:0] data_mem_write_data;

  // Clock Generation
  initial clk = 0;
  always #25 clk = ~clk;

  // Hook-up for Program Memory Read
  assign prog_mem_read_data = prog_mem[prog_mem_read_address];
  assign prog_mem_read_ready = prog_mem_read_valid;

  // Hook-up for Data Memory Read/Write
  always @(posedge clk) begin
    if (data_mem_write_valid)
      data_mem[data_mem_write_address] <= data_mem_write_data;
    data_mem_read_data <= data_mem[data_mem_read_address];
    data_mem_read_ready <= data_mem_read_valid;
    data_mem_write_ready <= data_mem_write_valid;
  end

  // Program Memory Initialization
  integer i;
  initial begin
    for (i = 0; i < (1 << PROGRAM_MEM_ADDR_BITS); i = i + 1) begin
      prog_mem[i] = 16'b0;
    end
    // Add instructions as needed...
  end

  // Data Memory Initialization
  integer j;
  initial begin
    for (j = 0; j < (1 << DATA_MEM_ADDR_BITS); j = j + 1) begin
      data_mem[j] = 8'b0;
    end
  end

  // Reset Sequence and Kernel Execution
  initial begin
    @(posedge clk);
    reset = 1;
    dcr_write_en = 0;
    start = 0;
    @(posedge clk);
    reset = 0;

    @(posedge clk);
    device_control_data = 8'd8;
    dcr_write_en = 1;
    @(posedge clk);
    dcr_write_en = 0;

    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    // Wait for done
    wait (done);
    $display("Kernel finished");
    $finish;
  end

  // DUT Instance (flattened interface)
  top gpu_inst (
    .clk(clk),
    .reset(reset),
    .start(start),
    .device_control_write_enable(dcr_write_en),
    .device_control_data(device_control_data),
    .prog_mem_read_data(prog_mem_read_data),
    .prog_mem_read_ready(prog_mem_read_ready),
    .prog_mem_read_valid(prog_mem_read_valid),
    .prog_mem_read_address(prog_mem_read_address),
    .data_mem_read_data(data_mem_read_data),
    .data_mem_read_ready(data_mem_read_ready),
    .data_mem_write_ready(data_mem_write_ready),
    .data_mem_read_valid(data_mem_read_valid),
    .data_mem_write_valid(data_mem_write_valid),
    .data_mem_read_address(data_mem_read_address),
    .data_mem_write_address(data_mem_write_address),
    .data_mem_write_data(data_mem_write_data),
    .done(done)
  );

endmodule
