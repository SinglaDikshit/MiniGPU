module decoder (
    input clk,
    input reset,
    input [2:0] core_state,
    input [15:0] instruction,

    // Decoded address fields
    output reg [3:0] rd_address,
    output reg [3:0] rs_address,
    output reg [3:0] rt_address,
    output reg [2:0] decoded_nzp,
    output reg [7:0] immediate,

    // Control signals
    output reg register_write_enable,
    output reg memory_read_enable,
    output reg memory_write_enable,
    output reg nzp_write_enable,
    output reg [1:0] register_input_mux,
    output reg [1:0] alu_control,
    output reg alu_output_mux,
    output reg next_pc_mux,
    output reg decoded_return
);

    // Instruction format fields
    wire [3:0] opcode = instruction[15:12];
    wire [3:0] rd = instruction[11:8];
    wire [3:0] rs = instruction[7:4];
    wire [3:0] rt = instruction[3:0];
    wire [2:0] nzp = instruction[11:9];
    wire [7:0] imm8 = instruction[7:0];

    always @(posedge clk) begin
        if (reset) begin
            // Reset all outputs
            rd_address <= 4'b0;
            rs_address <= 4'b0;
            rt_address <= 4'b0;
            decoded_nzp <= 3'b0;
            immediate <= 8'b0;
            register_write_enable <= 1'b0;
            memory_read_enable <= 1'b0;
            memory_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            register_input_mux <= 2'b0;
            alu_control <= 2'b0;
            alu_output_mux <= 1'b0;
            next_pc_mux <= 1'b0;
            decoded_return <= 1'b0;
        end
        else if (core_state == 3'b010) begin // DECODE state
            // Default values
            register_write_enable <= 1'b0;
            memory_read_enable <= 1'b0;
            memory_write_enable <= 1'b0;
            nzp_write_enable <= 1'b0;
            register_input_mux <= 2'b00;
            alu_control <= 2'b00;
            alu_output_mux <= 1'b0;
            next_pc_mux <= 1'b0;
            decoded_return <= 1'b0;

            // Decode based on opcode
            case (opcode)
                4'b0000: begin // NOP
                    // No operation - all defaults
                end

                4'b0001: begin // BRnzp
                    decoded_nzp <= nzp;
                    immediate <= imm8;
                    next_pc_mux <= 1'b1;
                end

                4'b0010: begin // CMP
                    rs_address <= rs;
                    rt_address <= rt;
                    alu_control <= 2'b01; // SUB for comparison
                    alu_output_mux <= 1'b1; // Output NZP flags
                    nzp_write_enable <= 1'b1;
                end

                4'b0011: begin // ADD
                    rd_address <= rd;
                    rs_address <= rs;
                    rt_address <= rt;
                    alu_control <= 2'b00; // ADD
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b00; // ALU result
                end

                4'b0100: begin // SUB
                    rd_address <= rd;
                    rs_address <= rs;
                    rt_address <= rt;
                    alu_control <= 2'b01; // SUB
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b00; // ALU result
                end

                4'b0101: begin // MUL
                    rd_address <= rd;
                    rs_address <= rs;
                    rt_address <= rt;
                    alu_control <= 2'b10; // MUL
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b00; // ALU result
                end

                4'b0110: begin // DIV
                    rd_address <= rd;
                    rs_address <= rs;
                    rt_address <= rt;
                    alu_control <= 2'b11; // DIV
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b00; // ALU result
                end

                4'b0111: begin // LDR
                    rd_address <= rd;
                    rs_address <= rs;
                    memory_read_enable <= 1'b1;
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b01; // LSU result
                end

                4'b1000: begin // STR
                    rs_address <= rs;
                    rt_address <= rt;
                    memory_write_enable <= 1'b1;
                end

                4'b1001: begin // CONST
                    rd_address <= rd;
                    immediate <= imm8;
                    register_write_enable <= 1'b1;
                    register_input_mux <= 2'b10; // Immediate
                end

                4'b1111: begin // RET
                    decoded_return <= 1'b1;
                end

                default: begin
                    // Invalid instruction - maintain defaults
                end
            endcase
        end
    end

endmodule