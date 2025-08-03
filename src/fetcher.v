module fetcher (
    input wire clk,
    input wire reset,
    input wire [7:0] current_pc,
    input wire [2:0] scheduler_state,
    input wire mem_read_ready,
    input wire [15:0] mem_read_data,

    output reg [7:0] mem_read_address,
    output reg [2:0] fetcher_state,
    output reg mem_read_valid,
    output reg [15:0] instruction
);

    // FSM states
    localparam IDLE = 3'b000;
    localparam FETCHING = 3'b001;
    localparam FETCHED = 3'b010;

    reg [2:0] next_state;

    // State machine
    always @(posedge clk) begin
        if (reset) begin
            fetcher_state <= IDLE;
            mem_read_address <= 8'b0;
            mem_read_valid <= 1'b0;
            instruction <= 16'b0;
        end
        else begin
            fetcher_state <= next_state;

            case (fetcher_state)
                IDLE: begin
                    // Default state after reset
                    mem_read_valid <= 1'b0;
                    instruction <= 16'b0;
                    mem_read_address <= 8'b0;
                end

                FETCHING: begin
                    // Assert memory read request
                    mem_read_valid <= 1'b1;
                    mem_read_address <= current_pc;

                    // Wait for memory acknowledgment
                    if (mem_read_ready) begin
                        // Latch instruction data
                        instruction <= mem_read_data;
                        mem_read_valid <= 1'b0;
                    end
                end

                FETCHED: begin
                    // Hold fetched instruction stable
                    // Instruction remains available for core to consume
                    // mem_read_valid remains low
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (fetcher_state)
            IDLE: begin
                if (scheduler_state == 3'b001) // FETCH state
                    next_state = FETCHING;
                else
                    next_state = IDLE;
            end

            FETCHING: begin
                if (mem_read_ready)
                    next_state = FETCHED;
                else
                    next_state = FETCHING;
            end

            FETCHED: begin
                if (scheduler_state == 3'b010) // DECODE state
                    next_state = IDLE;
                else
                    next_state = FETCHED;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule