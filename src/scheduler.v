module scheduler (
    input wire clk,
    input wire reset,
    input wire start,
    input wire memory_read_enable,
    input wire memory_write_enable,
    input wire decoded_return,
    input wire [2:0] fetcher_state,
    input wire [1:0] lsu_state_thread0,
    input wire [1:0] lsu_state_thread1,
    input wire [1:0] lsu_state_thread2,
    input wire [1:0] lsu_state_thread3,
    input wire [7:0] next_pc_thread0,
    input wire [7:0] next_pc_thread1,
    input wire [7:0] next_pc_thread2,
    input wire [7:0] next_pc_thread3,

    output reg [7:0] current_pc,
    output reg [2:0] scheduler_state,
    output reg done
);

    // FSM states
    localparam IDLE    = 3'b000;
    localparam FETCH   = 3'b001;
    localparam DECODE  = 3'b010;
    localparam REQUEST = 3'b011;
    localparam WAIT    = 3'b100;
    localparam EXECUTE = 3'b101;
    localparam UPDATE  = 3'b110;
    localparam DONE    = 3'b111;

    reg [2:0] next_state;
    reg [15:0] pipeline_instruction;
    reg any_lsu_waiting;
    reg instr_fetched;

    // Check if any LSU is waiting
    always @(*) begin
        any_lsu_waiting = (lsu_state_thread0 == 2'b01 || lsu_state_thread0 == 2'b10) ||
                         (lsu_state_thread1 == 2'b01 || lsu_state_thread1 == 2'b10) ||
                         (lsu_state_thread2 == 2'b01 || lsu_state_thread2 == 2'b10) ||
                         (lsu_state_thread3 == 2'b01 || lsu_state_thread3 == 2'b10);
    end

    // Check if instruction is fetched
    always @(*) begin
        instr_fetched = (fetcher_state == 3'b010); // FETCHED state
    end

    // State machine
    always @(posedge clk) begin
        if (reset) begin
            scheduler_state <= IDLE;
            current_pc <= 8'b0;
            done <= 1'b0;
            pipeline_instruction <= 16'b0;
        end
        else begin
            scheduler_state <= next_state;

            case (scheduler_state)
                IDLE: begin
                    // Reset internal registers
                    current_pc <= 8'b0; // Entry point
                    done <= 1'b0;
                    pipeline_instruction <= 16'b0;
                end

                FETCH: begin
                    // Wait for fetcher to complete
                    // Current PC is sent to instruction memory
                end

                DECODE: begin
                    // Decode instruction fields and set control signals
                    // This is handled by the decoder module
                end

                REQUEST: begin
                    // Activate LSUs if memory operation needed
                    // Memory operations are initiated here
                end

                WAIT: begin
                    // Poll all LSU states and stall until complete
                end

                EXECUTE: begin
                    // Perform ALU operations and calculate branch targets
                    // Compute next PC for each thread
                end

                UPDATE: begin
                    // Update register file and commit next PC values
                    if (!decoded_return) begin
                        // Converge next PC values from all threads
                        // For simplicity, using thread0's next PC (SIMD assumption)
                        current_pc <= next_pc_thread0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (scheduler_state)
            IDLE: begin
                if (start)
                    next_state = FETCH;
                else
                    next_state = IDLE;
            end

            FETCH: begin
                if (instr_fetched)
                    next_state = DECODE;
                else
                    next_state = FETCH;
            end

            DECODE: begin
                next_state = REQUEST;
            end

            REQUEST: begin
                if (memory_read_enable || memory_write_enable)
                    next_state = WAIT;
                else
                    next_state = EXECUTE;
            end

            WAIT: begin
                if (!any_lsu_waiting)
                    next_state = EXECUTE;
                else
                    next_state = WAIT;
            end

            EXECUTE: begin
                if (decoded_return)
                    next_state = DONE;
                else
                    next_state = UPDATE;
            end

            UPDATE: begin
                if (decoded_return)
                    next_state = DONE;
                else
                    next_state = FETCH;
            end

            DONE: begin
                next_state = DONE; // Stay in done state
            end

            default: next_state = IDLE;
        endcase
    end

endmodule