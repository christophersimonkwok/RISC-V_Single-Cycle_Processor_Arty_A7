module data_path #(
    parameter PC_W = 8,
    parameter INS_W = 32,
    parameter RF_ADDRESS = 5,
    parameter DATA_W = 32,
    parameter DM_ADDRESS = 9,
    parameter ALU_CC_W = 4
 )(
    input                  clk,
    input                  reset,
    input                  enable,
    input                  reg_write,
    input                  mem2reg,
    input                  alu_src,
    input                  mem_write,
    input                  mem_read,
    input  [ALU_CC_W-1:0]  alu_cc,
    output          [6:0]  opcode,
    output          [6:0]  funct7,
    output          [2:0]  funct3,
    output   [DATA_W-1:0]  alu_result,
    output   [PC_W-1:0]    pc_debug,
    output   [RF_ADDRESS-1:0] rd_debug,
    output                memory_access_valid,
    output   [DATA_W-1:0]  writeback_debug
 );

    wire [PC_W-1:0] pc_out;
    wire [PC_W-1:0] pc_plus4;

    wire [INS_W-1:0] instruction;

    wire [DATA_W-1:0] rg_rd_data1;
    wire [DATA_W-1:0] rg_rd_data2;
    wire [DATA_W-1:0] imm_out;
    wire [DATA_W-1:0] alu_b;
    wire [DATA_W-1:0] alu_out;
    wire [DATA_W-1:0] dm_read_data;
    wire [DATA_W-1:0] wb_data;

    // Loads/stores always add the base and immediate. Bypass ALU selection.
    wire [DATA_W-1:0] memory_address = rg_rd_data1 + imm_out;
    // LW/SW have signed 12-bit offsets. Check the upper address in parallel
    // with a 12-bit addition, instead of checking the full 32-bit sum.
    wire [12:0] address_low_sum = {1'b0, rg_rd_data1[11:0]} +
                                 {1'b0, imm_out[11:0]};
    wire base_upper_zero = (rg_rd_data1[31:12] == 20'h00000);
    wire base_upper_one  = (rg_rd_data1[31:12] == 20'h00001);
    wire base_upper_max  = (rg_rd_data1[31:12] == 20'hfffff);
    // Negative offsets subtract one from the upper portion; carry adds it back.
    // Keep 32-bit wraparound behavior, including fffffffc + 4 = 0.
    wire address_upper_zero = imm_out[11] ?
        (address_low_sum[12] ? base_upper_zero : base_upper_one) :
        (address_low_sum[12] ? base_upper_max : base_upper_zero);
    assign memory_access_valid = address_upper_zero &&
                                 (address_low_sum[11:9] == 3'b000) &&
                                 (address_low_sum[1:0] == 2'b00);

    wire zero;
    wire overflow;
    wire carry_out;

    wire [RF_ADDRESS-1:0] rg_wrt_addr_wire;
    wire [RF_ADDRESS-1:0] rg_rd_addr1_wire;
    wire [RF_ADDRESS-1:0] rg_rd_addr2_wire;

    assign pc_plus4 = pc_out + 8'd4;

    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    assign rg_wrt_addr_wire  = instruction[11:7];
    assign rg_rd_addr1_wire  = instruction[19:15];
    assign rg_rd_addr2_wire  = instruction[24:20];

    assign alu_result = alu_out;
    assign pc_debug = pc_out;
    assign rd_debug = rg_wrt_addr_wire;
    assign writeback_debug = wb_data;

    FlipFlop pc_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .d(pc_plus4),
        .q(pc_out)
    );

    InstMem im_inst (
        .addr(pc_out),
        .instruction(instruction)
    );

    RegFile rf_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .rg_wrt_en(reg_write),
        .rg_wrt_addr(rg_wrt_addr_wire),
        .rg_rd_addr1(rg_rd_addr1_wire),
        .rg_rd_addr2(rg_rd_addr2_wire),
        .rg_wrt_data(wb_data),
        .rg_rd_data1(rg_rd_data1),
        .rg_rd_data2(rg_rd_data2)
    );

    ImmGen ig_inst (
        .InstCode(instruction),
        .ImmOut(imm_out)
    );

    mux_32 alu_mux (
        .s(alu_src),
        .d0(rg_rd_data2),
        .d1(imm_out),
        .y(alu_b)
    );

    alu32 alu_inst (
        .A(rg_rd_data1),
        .B(alu_b),
        .Op(alu_cc),
        .Result(alu_out),
        .CarryOut(carry_out),
        .Overflow(overflow),
        .Zero(zero)
    );

    DataMem dm_inst (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .MemRead(mem_read),
        .MemWrite(mem_write),
        .addr(memory_address[DM_ADDRESS-1:0]),
        .write_data(rg_rd_data2),
        .read_data(dm_read_data)
    );

    mux_32 wb_mux (
        .s(mem2reg),
        .d0(alu_out),
        .d1(dm_read_data),
        .y(wb_data)
    );

endmodule

module FlipFlop(input clk, input reset, input enable, input [7:0] d, output reg [7:0] q);

    always @(posedge clk) begin
        if (reset)
            q <= 8'b00000000;
        else if (enable)
            q <= d;
    end
    
endmodule

module InstMem(input [7:0] addr, output wire [31:0] instruction);

    reg [31:0] memory [63:0];
    integer i;
    
    initial begin
        // Unused instruction words are NOPs, not undefined data.
        for (i = 0; i < 64; i = i + 1)
            memory[i] = 32'h00000013;
        memory[0]  = 32'h00007033;
        memory[1]  = 32'h00100093;
        memory[2]  = 32'h00200113;
        memory[3]  = 32'h00308193;
        memory[4]  = 32'h00408213;
        memory[5]  = 32'h00510293;
        memory[6]  = 32'h00610313;
        memory[7]  = 32'h00718393;
        memory[8]  = 32'h00208433;
        memory[9]  = 32'h404404b3;
        memory[10] = 32'h00317533;
        memory[11] = 32'h0041e5b3;
        memory[12] = 32'h0041a633;
        memory[13] = 32'h007346b3;
        memory[14] = 32'h4d34f713;
        memory[15] = 32'h8d35e793;
        memory[16] = 32'h4d26a813;
        memory[17] = 32'h4d244893;
        memory[18] = 32'h02b02823; // sw r11, 48(r0) alu result = 32'h00000030
        memory[19] = 32'h03002603; // lw r12, 48(r0) alu result = 32'h00000030 , r12 = 32'h00000005
    end
    assign instruction = memory[addr[7:2]];
    
endmodule

module RegFile(input clk, input reset, input enable, input rg_wrt_en, input [4:0] rg_wrt_addr, input [4:0] rg_rd_addr1, input [4:0] rg_rd_addr2, input [31:0] rg_wrt_data, output wire [31:0] rg_rd_data1, output wire [31:0] rg_rd_data2);

    reg [31:0] register_file [31:0];
    integer i;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                register_file[i] <= 32'h00000000;
        end
        else if (enable && rg_wrt_en && rg_wrt_addr != 0) begin
            register_file[rg_wrt_addr] <= rg_wrt_data;
        end
    end
    
    // Decode the address once. Reduce each bit with a balanced OR tree.
    // The original register array, reset, and write logic are unchanged.
    wire [31:0] select1, select2;
    genvar word_index, bit_index;
    generate
        for (word_index = 0; word_index < 32; word_index = word_index + 1) begin: decode_read
            assign select1[word_index] = (rg_rd_addr1 == word_index);
            assign select2[word_index] = (rg_rd_addr2 == word_index);
        end
        for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin: read_bit
            wire [31:0] selected1, selected2;
            for (word_index = 0; word_index < 32; word_index = word_index + 1) begin: read_word
                assign selected1[word_index] = register_file[word_index][bit_index] & select1[word_index];
                assign selected2[word_index] = register_file[word_index][bit_index] & select2[word_index];
            end
            assign rg_rd_data1[bit_index] = |selected1;
            assign rg_rd_data2[bit_index] = |selected2;
        end
    endgenerate

    
endmodule

module ImmGen(
    input [31:0] InstCode,
    output reg [31:0] ImmOut
);
    
    always @(*) begin
        case (InstCode[6:0])
            // I-type (Load)
            7'b0000011:
                ImmOut = {InstCode[31] ? {20{1'b1}} : 20'b0, InstCode[31:20]};
    
            // I-type (ALU immediate)
            7'b0010011:
                ImmOut = {InstCode[31] ? {20{1'b1}} : 20'b0, InstCode[31:20]};
    
            // S-type (Store)
            7'b0100011:
                ImmOut = {InstCode[31] ? {20{1'b1}} : 20'b0, InstCode[31:25], InstCode[11:7]};
    
            // U-type
            7'b0010111:
                ImmOut = {InstCode[31:12], 12'b0};
    
            default:
                ImmOut = 32'b0;
        endcase
    end
    
endmodule

module alu32 (input [31:0] A, input [31:0] B, input [3:0] Op, output reg [31:0] Result, output reg CarryOut, output reg Overflow, output reg Zero);

    reg [32:0] temp;

    always @(*) begin
        // default outputs
        Result    = 32'b0;
        CarryOut = 1'b0;
        Overflow  = 1'b0;
        Zero      = 1'b0;
        temp      = 33'b0;


        case (Op)

            4'b0000: begin
                // AND
                Result = A & B;
                Zero = (Result == 1'b0);
            end

            4'b0001: begin
                // OR
                Result = A | B;
                Zero = (Result == 1'b0);
            end

            4'b0010: begin
                // ADD
                temp = {1'b0, A} + {1'b0, B};
                Result = $signed(A) + $signed(B);
                CarryOut = temp[32];

                // signed overflow for addition
                Overflow  = (A[31] == B[31]) && (Result[31] != A[31]);
                Zero = (Result == 1'b0);
             end

            4'b0110: begin
                // SUB
                temp = {1'b0, A} - {1'b0, B};
                Result = $signed(A) - $signed(B);
                CarryOut = 1'b0;

                // signed overflow for subtraction
                Overflow  = (A[31] != B[31]) && (Result[31] != A[31]);
                Zero = (Result == 1'b0);
             end

            4'b0111: begin
                // SLT (signed)
                Result = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
                CarryOut = 1'b0;
                Overflow = 1'b0;
                Zero = (Result == 1'b0);
            end

            4'b1100: begin
                // NOR
                Result = ~(A | B);
                Zero = (Result == 1'b0);
            end

            4'b1111: begin
                // EQ
                Result = (A == B) ? 32'b1 : 32'b0;
                Zero = (Result == 1'b0);
            end

            default: begin
                // ADD
                temp = {1'b0, A} + {1'b0, B};
                Result = $signed(A) + $signed(B);
                CarryOut = temp[32];

                // signed overflow for addition
                Overflow  = (A[31] == B[31]) && (Result[31] != A[31]);
                Zero = (Result == 1'b0);
            end
        endcase
    end

endmodule

module DataMem(
    input clk,
    input reset,
    input enable,
    input MemRead,
    input MemWrite,
    input [8:0] addr,
    input [31:0] write_data,
    output [31:0] read_data
);
    
        // 128 words. FPGA configuration initializes RAM; CPU reset retains it.
        reg [31:0] mem [0:127];
        integer i;
        initial begin
            for (i = 0; i < 128; i = i + 1)
                mem[i] = 32'b0;
        end
    
        // Stores happen only at the edge that commits the instruction.
        always @(posedge clk) begin
            if (!reset && enable && MemWrite)
                mem[addr[8:2]] <= write_data;
        end
    
        assign read_data = MemRead ? mem[addr[8:2]] : 32'b0;
    
endmodule

module mux_32(
        input s,
        input [31:0] d0,
        input [31:0] d1,
        output [31:0] y
        );
    
        assign y = s ? d1 : d0;
    
endmodule