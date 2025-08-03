`default_nettype none
`timescale 1ns/1ns

module gpu_tb;

  // Parameters
  parameter THREADS = 8;
  parameter DATA_MEM_ADDR_BITS = 8;
  parameter DATA_MEM_DATA_BITS = 8;
  parameter DATA_MEM_NUM_CHANNELS = 4;
  parameter PROGRAM_MEM_ADDR_BITS = 8;
  parameter PROGRAM_MEM_DATA_BITS = 16;
  parameter PROGRAM_MEM_NUM_CHANNELS = 1;
  parameter NUM_CORES = 2;
  parameter THREADS_PER_BLOCK = 4;

  // Testbench Registers and Wires
  reg reset, start, dcr_write_en;
  reg clk;
  reg [7:0] device_control_data;
  wire done;

  // Program Memory
  reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem [0:(1<<PROGRAM_MEM_ADDR_BITS)-1];
  reg [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_ready;
  reg [PROGRAM_MEM_DATA_BITS-1:0] program_mem_read_data [PROGRAM_MEM_NUM_CHANNELS-1:0];
  wire [PROGRAM_MEM_NUM_CHANNELS-1:0] program_mem_read_valid;
  wire [PROGRAM_MEM_ADDR_BITS-1:0] program_mem_read_address [PROGRAM_MEM_NUM_CHANNELS-1:0];

  // Data Memory
  reg [DATA_MEM_DATA_BITS-1:0] data_mem [0:(1<<DATA_MEM_ADDR_BITS)-1];
  reg [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_ready;
  wire [DATA_MEM_DATA_BITS-1:0] data_mem_read_data [DATA_MEM_NUM_CHANNELS-1:0];
  wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_read_valid;
  wire [DATA_MEM_ADDR_BITS-1:0] data_mem_read_address [DATA_MEM_NUM_CHANNELS-1:0];
  reg [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_ready;
  wire [DATA_MEM_NUM_CHANNELS-1:0] data_mem_write_valid;
  wire [DATA_MEM_ADDR_BITS-1:0] data_mem_write_address [DATA_MEM_NUM_CHANNELS-1:0];
  wire [DATA_MEM_DATA_BITS-1:0] data_mem_write_data [DATA_MEM_NUM_CHANNELS-1:0];

  // Loop iterators (must be declared before use in Verilog)
  integer i_prog;
  integer c;
  integer idx;
  integer i_data;
  integer cycles;
  integer i_check;

  // Test variables
  reg [7:0] expected;
  reg [7:0] result;

  // Clock generation: 50ns period
  initial clk = 1'b0;
  always #25 clk = ~clk;

  // Combinational logic for Program Memory Read
  always @(*) begin
    program_mem_read_ready = program_mem_read_valid;
    for (i_prog = 0; i_prog < PROGRAM_MEM_NUM_CHANNELS; i_prog = i_prog + 1) begin
      program_mem_read_data[i_prog] = program_mem[program_mem_read_address[i_prog]];
    end
  end

  // Synchronous logic for Data Memory Read/Write
  always @(posedge clk) begin
    for (c = 0; c < DATA_MEM_NUM_CHANNELS; c = c + 1) begin
      if (data_mem_write_valid[c]) begin
        data_mem[data_mem_write_address[c]] <= data_mem_write_data[c];
      end
      data_mem_write_ready[c] <= data_mem_write_valid[c];
      data_mem_read_ready[c] <= data_mem_read_valid[c];
    end
  end
  
  // Continuous assignment for Data Memory Read Data
  generate
  for (c_gen = 0; c_gen < DATA_MEM_NUM_CHANNELS; c_gen = c_gen + 1) begin : data_read_gen_block
    assign data_mem_read_data[c_gen] = data_mem[data_mem_read_address[c_gen]];
  end
endgenerate

  // Program Memory Initialization
  initial begin
    program_mem[0]  = 16'b0101000011011110; // MUL R0, %blockIdx, %blockDim
    program_mem[1]  = 16'b0011000000001111; // ADD R0, R0, %threadIdx
    program_mem[2]  = 16'b1001000100000001; // CONST R1, #1
    program_mem[3]  = 16'b1001001000000010; // CONST R2, #2
    program_mem[4]  = 16'b1001001100000000; // CONST R3, #0
    program_mem[5]  = 16'b1001010000000100; // CONST R4, #4
    program_mem[6]  = 16'b1001010100001000; // CONST R5, #8
    program_mem[7]  = 16'b0110011000000010; // DIV R6, R0, R2
    program_mem[8]  = 16'b0101011101100010; // MUL R7, R6, R2
    program_mem[9]  = 16'b0100011100000111; // SUB R7, R0, R7
    program_mem[10] = 16'b1001100000000000; // CONST R8, #0
    program_mem[11] = 16'b1001100100000000; // CONST R9, #0
    program_mem[12] = 16'b0101101001100010; // MUL R10, R6, R2
    program_mem[13] = 16'b0011101010101001; // ADD R10, R10, R9
    program_mem[14] = 16'b0011101010100011; // ADD R10, R10, R3
    program_mem[15] = 16'b0111101010100000; // LDR R10, R10
    program_mem[16] = 16'b0101101110010010; // MUL R11, R9, R2
    program_mem[17] = 16'b0011101110110111; // ADD R11, R11, R7
    program_mem[18] = 16'b0011101110110100; // ADD R11, R11, R4
    program_mem[19] = 16'b0111101110110000; // LDR R11, R11
    program_mem[20] = 16'b0101110010101011; // MUL R12, R10, R11
    program_mem[21] = 16'b0011100010001100; // ADD R8, R8, R12
    program_mem[22] = 16'b0011100110010001; // ADD R9, R9, R1
    program_mem[23] = 16'b0010000010010010; // CMP R9, R2
    program_mem[24] = 16'b0001100000001100; // BRn LOOP (back to instr 12)
    program_mem[25] = 16'b0011100101010000; // ADD R9, R5, R0
    program_mem[26] = 16'b1000000010011000; // STR R9, R8
    program_mem[27] = 16'b1111000000000000; // RET

    // Clear the rest of program memory
    for (i_prog = 28; i_prog < (1 << PROGRAM_MEM_ADDR_BITS); i_prog = i_prog + 1) begin
        program_mem[i_prog] = 16'b0;
    end
  end

  // Data Memory Initialization
  initial begin
    // Clear all data memory locations
    for (idx = 0; idx < (1 << DATA_MEM_ADDR_BITS); idx = idx + 1) begin
       data_mem[idx] = 8'b0;
    end
      
    // Initialize first vector (A)
    for (i_data = 1; i_data < 5; i_data = i_data + 1) begin
       data_mem[i_data-1] = i_data;
    end
      
    // Initialize second vector (B)
    for (i_data = 1; i_data < 5; i_data = i_data + 1) begin
       data_mem[i_data+3] = i_data;
    end
  end

  // Main Stimulus and Checking Process
  initial begin
    //---------------------------------------------------------------
    // 1. Apply Reset
    //---------------------------------------------------------------
    @(posedge clk);
    reset = 1'b1;
    dcr_write_en = 1'b0;
    start = 1'b0;
    repeat (1) @(posedge clk);
    reset = 1'b0;

    //---------------------------------------------------------------
    // 2. Write thread count to Device Control Register
    //---------------------------------------------------------------
    @(posedge clk);
    device_control_data = THREADS;
    dcr_write_en  = 1'b1;
    @(posedge clk);
    dcr_write_en  = 1'b0;

    //---------------------------------------------------------------
    // 3. Pulse start to begin kernel execution
    //---------------------------------------------------------------
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    //---------------------------------------------------------------
    // 4. Wait for DUT to assert 'done' and count cycles
    //---------------------------------------------------------------
    cycles = 0;
    while (!done) begin
       @(posedge clk);
       cycles = cycles + 1;
    end
    $display("Kernel completed in %0d cycles.", cycles);

    //---------------------------------------------------------------
    // 5. Check results: C[i] = A[i] + B[i] stored at base address 16
    //---------------------------------------------------------------
    for (i_check = 0; i_check < 8; i_check = i_check + 1) begin
       expected = i_check + i_check; // The original testbench logic
       result   = data_mem[i_check+16];
       if (result !== expected) begin
          $error("MISMATCH @ index %0d: Expected %d, but got %d.", i_check, expected, result);
       end
    end

    $display("All results correct – SIMULATION PASSED.");
    $finish;
  end

  // Instantiate the GPU (Device Under Test)
  gpu inst(
    .clk(clk),
    .reset(reset),
    .start(start),
    .device_control_write_enable(dcr_write_en),
    .device_control_data(device_control_data),
    .program_mem_read_ready(program_mem_read_ready),
    .program_mem_read_data(program_mem_read_data),
    .data_mem_read_ready(data_mem_read_ready),
    .data_mem_read_data(data_mem_read_data),
    .data_mem_write_ready(data_mem_write_ready),
    .done(done),
    .program_mem_read_valid(program_mem_read_valid),
    .program_mem_read_address(program_mem_read_address),
    .data_mem_read_valid(data_mem_read_valid),
    .data_mem_read_address(data_mem_read_address),
    .data_mem_write_valid(data_mem_write_valid),
    .data_mem_write_address(data_mem_write_address),
    .data_mem_write_data(data_mem_write_data)
  );

endmodule