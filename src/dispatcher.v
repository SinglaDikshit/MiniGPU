`timescale 1ns/1ns
module dispatcher #(
    parameter NUM_CORES = 2,
    parameter THREADS_PER_BLOCK = 4
) (
    input clk,
    input reset,
    input start,
    input [7:0] thread_count,
    input [NUM_CORES-1:0] core_done,

    output reg [NUM_CORES-1:0] core_start,
    output reg [NUM_CORES-1:0] core_reset,
    output reg [NUM_CORES*4-1:0] core_block_id,    // 4 bits per core
    output reg [NUM_CORES*8-1:0] core_thread_count, // 8 bits per core
    output reg done
);

    // FSM states
    localparam RESET_STATE = 2'b00;
    localparam START_STATE = 2'b01;
    localparam RUNNING = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state, next_state;

    // Block management
    reg [7:0] total_blocks;
    reg [7:0] blocks_dispatched;
    reg [7:0] blocks_done;
    reg [3:0] next_block_id;

    // Core management
    reg [NUM_CORES-1:0] core_idle;

    integer i;

    // Calculate total blocks
    always @(*) begin
        total_blocks = (thread_count + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    end

    // State machine
    always @(posedge clk) begin
        if (reset) begin
            state <= RESET_STATE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            RESET_STATE: begin
                if (start)
                    next_state = START_STATE;
                else
                    next_state = RESET_STATE;
            end

            START_STATE: begin
                next_state = RUNNING;
            end

            RUNNING: begin
                if (blocks_done >= total_blocks)
                    next_state = DONE_STATE;
                else
                    next_state = RUNNING;
            end

            DONE_STATE: begin
                if (!start)
                    next_state = RESET_STATE;
                else
                    next_state = DONE_STATE;
            end

            default: next_state = RESET_STATE;
        endcase
    end

    // Output logic and block management
    always @(posedge clk) begin
        if (reset || state == RESET_STATE) begin
            // Reset all counters and core signals
            blocks_dispatched <= 8'b0;
            blocks_done <= 8'b0;
            next_block_id <= 4'b0;
            core_start <= {NUM_CORES{1'b0}};
            core_reset <= {NUM_CORES{1'b1}};  // Put cores in reset
            core_block_id <= {NUM_CORES*4{1'b0}};
            core_thread_count <= {NUM_CORES*8{1'b0}};
            core_idle <= {NUM_CORES{1'b1}};
            done <= 1'b0;
        end
        else begin
            case (state)
                START_STATE: begin
                    // Release all cores from reset
                    core_reset <= {NUM_CORES{1'b0}};
                    // Start dispatching blocks to available cores
                    for (i = 0; i < NUM_CORES; i = i + 1) begin
                        if (blocks_dispatched < total_blocks) begin
                            core_start[i] <= 1'b1;
                            core_block_id[i*4 +: 4] <= next_block_id;

                            // Calculate thread count for this block
                            if ((next_block_id + 1) * THREADS_PER_BLOCK <= thread_count) begin
                                core_thread_count[i*8 +: 8] <= THREADS_PER_BLOCK;
                            end
                            else begin
                                // Last block may have fewer threads
                                core_thread_count[i*8 +: 8] <= thread_count - (next_block_id * THREADS_PER_BLOCK);
                            end

                            blocks_dispatched <= blocks_dispatched + 1;
                            next_block_id <= next_block_id + 1;
                            core_idle[i] <= 1'b0;
                        end
                    end
                end

                RUNNING: begin
                    // Handle core completion and dispatch new blocks
                    for (i = 0; i < NUM_CORES; i = i + 1) begin
                        if (core_done[i] && !core_idle[i]) begin
                            blocks_done <= blocks_done + 1;
                            core_start[i] <= 1'b0;

                            // Reset core and dispatch new block if available
                            if (blocks_dispatched < total_blocks) begin
                                core_reset[i] <= 1'b1;  // Reset core
                                // In next cycle, release reset and start new block
                            end
                            else begin
                                core_idle[i] <= 1'b1;
                            end
                        end
                        else if (core_reset[i] && blocks_dispatched < total_blocks) begin
                            // Release reset and start new block
                            core_reset[i] <= 1'b0;
                            core_start[i] <= 1'b1;
                            core_block_id[i*4 +: 4] <= next_block_id;

                            // Calculate thread count for this block
                            if ((next_block_id + 1) * THREADS_PER_BLOCK <= thread_count) begin
                                core_thread_count[i*8 +: 8] <= THREADS_PER_BLOCK;
                            end
                            else begin
                                core_thread_count[i*8 +: 8] <= thread_count - (next_block_id * THREADS_PER_BLOCK);
                            end

                            blocks_dispatched <= blocks_dispatched + 1;
                            next_block_id <= next_block_id + 1;
                            core_idle[i] <= 1'b0;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    core_start <= {NUM_CORES{1'b0}};
                end
            endcase
        end
    end

endmodule