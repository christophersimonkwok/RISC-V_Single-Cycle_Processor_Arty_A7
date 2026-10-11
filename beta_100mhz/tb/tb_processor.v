`timescale 1ns / 1ps

// Run the original 20-instruction program, one instruction per clock edge.
module tb_processor;
    reg clk = 0;
    reg reset = 1;
    reg enable = 0;
    wire [31:0] result, writeback;
    wire [7:0] pc;
    wire fault;
    integer checks = 0;

    processor dut (
        .clk(clk), .reset(reset), .enable(enable), .Result(result),
        .fault(fault), .debug_pc(pc), .debug_writeback(writeback)
    );

    always #5 clk = ~clk; // 50 MHz

    task check;
        input condition;
        input [8*80-1:0] message;
        begin
            if (condition !== 1'b1)
                $fatal(1, "FAIL: %0s", message);
            checks = checks + 1;
        end
    endtask

    task step_result;
        input [31:0] expected;
        begin
            enable = 1;
            @(negedge clk);
            enable = 0;
            check(result === expected, "original program ALU result");
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        step_result(32'h00000000); // AND x0,x0,x0
        step_result(32'h00000001); // ADDI x1,x0,1
        step_result(32'h00000002); // ADDI x2,x0,2
        step_result(32'h00000004);
        step_result(32'h00000005);
        step_result(32'h00000007);
        step_result(32'h00000008);
        step_result(32'h0000000b);
        step_result(32'h00000003); // ADD
        step_result(32'hfffffffe); // SUB
        step_result(32'h00000000); // AND
        step_result(32'h00000005); // OR
        step_result(32'h00000001); // signed SLT
        step_result(32'hfffffff4); // course NOR
        step_result(32'h000004d2); // ANDI
        step_result(32'hfffff8d7); // ORI with negative immediate
        step_result(32'h00000001); // signed SLTI
        step_result(32'hfffffb2c); // course NORI
        step_result(32'h00000030); // SW address = 48
        step_result(32'h00000030); // LW address = 48

        check(pc === 8'd80 && !fault, "all 20 instructions committed");
        check(dut.data_path.dm_inst.mem[12] === 32'd5, "store wrote 5");
        check(dut.data_path.rf_inst.register_file[12] === 32'd5 &&
              writeback === 32'd5, "load wrote the data, not its address");
        check(dut.data_path.rf_inst.register_file[0] === 32'd0, "x0 stays zero");
        $display("PASS tb_processor: %0d checks", checks);
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "Processor test timed out");
    end
endmodule
