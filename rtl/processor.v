`timescale 1ns / 1ps

module processor
(
    input clk, reset,
    input enable,

    output [31:0] Result,
    output reg fault,
    output [7:0] debug_pc,
    output reg [31:0] debug_writeback
);

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    wire [1:0] ALUOp;
    wire [3:0] ALU_CC;

    wire ALUSrc;
    wire MemtoReg;
    wire RegWrite;
    wire MemRead;
    wire MemWrite;

    wire [31:0] datapath_result;
    reg  [31:0] result_reg;

    assign Result = result_reg;

    wire [31:0] current_writeback;
    wire [4:0] rd;
    wire supported_encoding;
    wire memory_access_valid;
    wire instruction_valid;
    wire commit_enable;

    // The course supports these operations, including its custom NOR encoding.
    assign supported_encoding =
        ((opcode == 7'b0110011) &&
            (((funct3 == 3'b000) && ((funct7 == 7'b0000000) || (funct7 == 7'b0100000))) ||
             ((funct3 == 3'b010 || funct3 == 3'b100 || funct3 == 3'b110 || funct3 == 3'b111) &&
              (funct7 == 7'b0000000)))) ||
        ((opcode == 7'b0010011) &&
            (funct3 == 3'b000 || funct3 == 3'b010 || funct3 == 3'b100 ||
             funct3 == 3'b110 || funct3 == 3'b111)) ||
        ((opcode == 7'b0000011 || opcode == 7'b0100011) && (funct3 == 3'b010));

    // Check the full address before truncating it for the 512-byte RAM.
    assign memory_access_valid = (datapath_result[31:9] == 23'b0) &&
                                 (datapath_result[1:0] == 2'b00);
    assign instruction_valid = supported_encoding &&
        (((opcode != 7'b0000011) && (opcode != 7'b0100011)) || memory_access_valid);
    assign commit_enable = enable && !fault && instruction_valid;

    Controller controller (
        .Opcode   (opcode),
        .ALUSrc   (ALUSrc),
        .MemtoReg (MemtoReg),
        .RegWrite (RegWrite),
        .MemRead  (MemRead),
        .MemWrite (MemWrite),
        .ALUOp    (ALUOp)
    );

    ALUController alu_controller (
        .ALUOp     (ALUOp),
        .Funct7    (funct7),
        .Funct3    (funct3),
        .Operation (ALU_CC)
    );

    data_path data_path (
        .clk       (clk),
        .reset     (reset),
        .enable    (commit_enable),
        .reg_write (RegWrite),
        .mem2reg   (MemtoReg),
        .alu_src   (ALUSrc),
        .mem_write (MemWrite),
        .mem_read  (MemRead),
        .alu_cc    (ALU_CC),
        .opcode    (opcode),
        .funct7    (funct7),
        .funct3    (funct3),
        .alu_result(datapath_result),
        .pc_debug  (debug_pc),
        .rd_debug  (rd),
        .writeback_debug(current_writeback)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            result_reg <= 32'b0;
            debug_writeback <= 32'b0;
            fault <= 1'b0;
        end else if (enable && !fault) begin
            if (!instruction_valid) begin
                fault <= 1'b1;
            end else begin
                result_reg <= datapath_result;
                if (RegWrite && rd != 0)
                    debug_writeback <= current_writeback;
            end
        end
    end

endmodule
