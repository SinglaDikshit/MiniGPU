module memory_controller #(
    parameter ADDR_BITS = 8,
    parameter DATA_BITS = 8,
    parameter NUM_CONSUMERS = 8,  // 2 cores * 4 threads each
    parameter NUM_CHANNELS = 2,
    parameter WRITE_ENABLE = 1
) (
    input wire clk,
    input wire reset,

    // Consumer interface
    input wire [NUM_CONSUMERS-1:0] consumer_read_valid,
    input wire [NUM_CONSUMERS-1:0] consumer_write_valid,
    input wire [NUM_CONSUMERS*ADDR_BITS-1:0] consumer_read_address,
    input wire [NUM_CONSUMERS*ADDR_BITS-1:0] consumer_write_address,
    input wire [NUM_CONSUMERS*DATA_BITS-1:0] consumer_write_data,

    output reg [NUM_CONSUMERS-1:0] consumer_read_ready,
    output reg [NUM_CONSUMERS-1:0] consumer_write_ready,
    output reg [NUM_CONSUMERS*DATA_BITS-1:0] consumer_read_data,

    // Memory interface
    output reg [NUM_CHANNELS-1:0] mem_read_valid,
    output reg [NUM_CHANNELS-1:0] mem_write_valid,
    output reg [NUM_CHANNELS*ADDR_BITS-1:0] mem_read_address,
    output reg [NUM_CHANNELS*ADDR_BITS-1:0] mem_write_address,
    output reg [NUM_CHANNELS*DATA_BITS-1:0] mem_write_data,

    input wire [NUM_CHANNELS-1:0] mem_read_ready,
    input wire [NUM_CHANNELS-1:0] mem_write_ready,
    input wire [NUM_CHANNELS*DATA_BITS-1:0] mem_read_data
);

    // FSM states for each channel
    localparam IDLE = 2'b00;
    localparam READ_WAITING = 2'b01;
    localparam WRITE_WAITING = 2'b10;
    localparam RELAYING = 2'b11;

    // Channel state and control
    reg [1:0] channel_state [NUM_CHANNELS-1:0];
    reg [NUM_CONSUMERS-1:0] consumer_served;
    reg [$clog2(NUM_CONSUMERS)-1:0] serving_consumer [NUM_CHANNELS-1:0];
    reg [DATA_BITS-1:0] channel_read_data [NUM_CHANNELS-1:0];

    // Priority encoder signals for each channel
    wire [NUM_CONSUMERS-1:0] available_read_requests [NUM_CHANNELS-1:0];
    wire [NUM_CONSUMERS-1:0] available_write_requests [NUM_CHANNELS-1:0];
    wire [NUM_CONSUMERS-1:0] any_available_requests [NUM_CHANNELS-1:0];
    wire [$clog2(NUM_CONSUMERS)-1:0] selected_consumer [NUM_CHANNELS-1:0];
    wire request_found [NUM_CHANNELS-1:0];

    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin : channel_arbiters
            // Find available requests (not already being served)
            assign available_read_requests[ch] = consumer_read_valid & ~consumer_served;
            assign available_write_requests[ch] = (WRITE_ENABLE ? consumer_write_valid : {NUM_CONSUMERS{1'b0}}) & ~consumer_served;
            assign any_available_requests[ch] = available_read_requests[ch] | available_write_requests[ch];
            assign request_found[ch] = |any_available_requests[ch];

            // Priority encoder - finds lowest numbered available consumer
            // This replaces the problematic loop
            assign selected_consumer[ch] = 
                any_available_requests[ch][0] ? 3'd0 :
                any_available_requests[ch][1] ? 3'd1 :
                any_available_requests[ch][2] ? 3'd2 :
                any_available_requests[ch][3] ? 3'd3 :
                any_available_requests[ch][4] ? 3'd4 :
                any_available_requests[ch][5] ? 3'd5 :
                any_available_requests[ch][6] ? 3'd6 :
                3'd7; // Default to last consumer
        end
    endgenerate

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            // Reset all channels and consumer signals
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                channel_state[i] <= IDLE;
                serving_consumer[i] <= 0;
                channel_read_data[i] <= 0;
            end
            consumer_served <= 0;
            consumer_read_ready <= 0;
            consumer_write_ready <= 0;
            consumer_read_data <= 0;
            mem_read_valid <= 0;
            mem_write_valid <= 0;
            mem_read_address <= 0;
            mem_write_address <= 0;
            mem_write_data <= 0;
        end
        else begin
            // Process each channel independently
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                case (channel_state[i])
                    IDLE: begin
                        if (request_found[i]) begin
                            serving_consumer[i] <= selected_consumer[i];
                            consumer_served[selected_consumer[i]] <= 1'b1;
                            
                            if (available_read_requests[i][selected_consumer[i]]) begin
                                // Start read operation
                                mem_read_valid[i] <= 1'b1;
                                mem_read_address[i*ADDR_BITS +: ADDR_BITS] <= 
                                    consumer_read_address[selected_consumer[i]*ADDR_BITS +: ADDR_BITS];
                                channel_state[i] <= READ_WAITING;
                            end
                            else if (available_write_requests[i][selected_consumer[i]]) begin
                                // Start write operation
                                mem_write_valid[i] <= 1'b1;
                                mem_write_address[i*ADDR_BITS +: ADDR_BITS] <= 
                                    consumer_write_address[selected_consumer[i]*ADDR_BITS +: ADDR_BITS];
                                mem_write_data[i*DATA_BITS +: DATA_BITS] <= 
                                    consumer_write_data[selected_consumer[i]*DATA_BITS +: DATA_BITS];
                                channel_state[i] <= WRITE_WAITING;
                            end
                        end
                    end

                    READ_WAITING: begin
                        if (mem_read_ready[i]) begin
                            // Capture read data and prepare to relay
                            channel_read_data[i] <= mem_read_data[i*DATA_BITS +: DATA_BITS];
                            mem_read_valid[i] <= 1'b0;
                            channel_state[i] <= RELAYING;
                        end
                    end

                    WRITE_WAITING: begin
                        if (mem_write_ready[i]) begin
                            // Write completed, prepare to relay acknowledgment
                            mem_write_valid[i] <= 1'b0;
                            channel_state[i] <= RELAYING;
                        end
                    end

                    RELAYING: begin
                        // Send data/acknowledgment back to consumer
                        if (consumer_read_valid[serving_consumer[i]]) begin
                            consumer_read_ready[serving_consumer[i]] <= 1'b1;
                            consumer_read_data[serving_consumer[i]*DATA_BITS +: DATA_BITS] <= 
                                channel_read_data[i];
                        end
                        else if (consumer_write_valid[serving_consumer[i]]) begin
                            consumer_write_ready[serving_consumer[i]] <= 1'b1;
                        end

                        // Wait for consumer to deassert valid signal
                        if (!consumer_read_valid[serving_consumer[i]] && 
                            !consumer_write_valid[serving_consumer[i]]) begin
                            consumer_served[serving_consumer[i]] <= 1'b0;
                            consumer_read_ready[serving_consumer[i]] <= 1'b0;
                            consumer_write_ready[serving_consumer[i]] <= 1'b0;
                            channel_state[i] <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule