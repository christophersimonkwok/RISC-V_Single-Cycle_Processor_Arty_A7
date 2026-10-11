`timescale 1ns / 1ps

// Small programs check pause, reset, RAM writes, and fault handling.
module tb_regression;
    reg clk = 0, reset = 1, enable = 0;
    wire [31:0] result, writeback;
    wire [7:0] pc;
    wire fault;
    integer checks = 0;

    processor dut (
        .clk(clk), .reset(reset), .enable(enable), .Result(result),
        .fault(fault), .debug_pc(pc), .debug_writeback(writeback)
    );
    always #5 clk = ~clk;

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if (condition !== 1'b1)
                $fatal(1, "FAIL: %0s", message);
            checks = checks + 1;
        end
    endtask

    task step;
        begin
            enable = 1;
            @(negedge clk);
            enable = 0;
        end
    endtask

    task restart;
        integer i;
        begin
            @(negedge clk);
            reset = 1;
            enable = 0;
            for (i = 0; i < 64; i = i + 1)
                dut.data_path.im_inst.memory[i] = 32'h00000013;
            @(negedge clk);
            reset = 0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        repeat (18) step;
        check(pc == 72 && dut.data_path.dm_inst.mem[12] == 0,
              "program has reached the store but has not committed it");
        repeat (4) @(negedge clk);
        check(pc == 72 && dut.data_path.dm_inst.mem[12] == 0,
              "paused store has no side effect");
        step;
        check(pc == 76 && dut.data_path.dm_inst.mem[12] == 5,
              "enabled store commits once");
        step;
        check(!fault && pc == 80 && writeback == 5,
              "course program load completes in one cycle");
        repeat (5) @(negedge clk);
        check(pc == 80 && result == 48 && writeback == 5,
              "pause retains PC and displayed results");
        repeat (44) step;
        check(pc == 0 && !fault, "NOP tail and original 8-bit PC wrap");

        restart;
        check(dut.data_path.dm_inst.mem[12] == 5, "CPU reset retains RAM");
        check(pc == 0 && result == 0 && writeback == 0 && !fault,
              "reset clears processor and debug state");
        dut.data_path.im_inst.memory[0] = 32'h00700013; // ADDI x0,x0,7
        dut.data_path.im_inst.memory[1] = 32'hfff00093; // ADDI x1,x0,-1
        dut.data_path.im_inst.memory[2] = 32'h0000a113; // SLTI x2,x1,0
        dut.data_path.im_inst.memory[3] = 32'h001021b3; // SLT x3,x0,x1
        dut.data_path.im_inst.memory[4] = 32'h1e102e23; // SW x1,508(x0)
        dut.data_path.im_inst.memory[5] = 32'h1fc02203; // LW x4,508(x0)
        step;
        check(dut.data_path.rf_inst.register_file[0] == 0,
              "x0 ignores writes");
        step;
        check(dut.data_path.rf_inst.register_file[1] == 32'hffffffff,
              "negative immediate sign extension");
        step;
        check(dut.data_path.rf_inst.register_file[2] == 1, "signed SLTI");
        step;
        check(dut.data_path.rf_inst.register_file[3] == 0, "signed SLT reverse order");
        enable = 1;
        #1;
        check(dut.data_path.dm_inst.mem[127] == 0,
              "store does not write before the clock edge");
        @(negedge clk);
        enable = 0;
        check(dut.data_path.dm_inst.mem[127] == 32'hffffffff,
              "store to last aligned word");
        step;
        check(dut.data_path.rf_inst.register_file[4] == 32'hffffffff,
              "load from last aligned word");

        restart;
        dut.data_path.im_inst.memory[0] = 32'h00202083; // misaligned LW
        step;
        check(fault && pc == 0 && dut.data_path.rf_inst.register_file[1] == 0,
              "misaligned load faults without commit");
        dut.data_path.im_inst.memory[0] = 32'h00100093;
        step;
        check(fault && pc == 0 && dut.data_path.rf_inst.register_file[1] == 0,
              "fault remains sticky until reset");

        restart;
        dut.data_path.im_inst.memory[0] = 32'h20002023; // SW x0,512(x0)
        dut.data_path.dm_inst.mem[0] = 32'h12345678;
        step;
        check(fault && pc == 0 && dut.data_path.dm_inst.mem[0] == 32'h12345678,
              "out-of-range store cannot alias address zero");

        restart;
        dut.data_path.im_inst.memory[0] = 32'hffc02083; // LW x1,-4(x0)
        step;
        check(fault && pc == 0, "negative address faults");

        restart;
        dut.data_path.im_inst.memory[0] = 32'h020000b3; // unsupported MUL
        step;
        check(fault && pc == 0, "unsupported R-type encoding faults");
        restart;
        dut.data_path.im_inst.memory[0] = 32'h00000063; // unsupported branch
        step;
        check(fault && pc == 0, "unsupported opcode faults");
        restart;
        dut.data_path.im_inst.memory[0] = 32'h00101083; // unsupported halfword load
        step;
        check(fault && pc == 0, "unsupported memory width faults");

        restart;
        dut.data_path.im_inst.memory[0] = 32'h05500093; // ADDI x1,x0,0x55
        dut.data_path.im_inst.memory[1] = 32'h00f0c113; // NORI x2,x1,0x0f
        dut.data_path.im_inst.memory[2] = 32'h0020c1b3; // NOR x3,x1,x2
        step;
        step;
        check(result == 32'hffffffa0, "custom course NORI");
        step;
        check(result == 10, "custom course NOR");

        restart;
        dut.data_path.im_inst.memory[0] = 32'h000020a3; // misaligned store
        dut.data_path.dm_inst.mem[0] = 32'habcdef01;
        step;
        check(fault && pc == 0 && dut.data_path.dm_inst.mem[0] == 32'habcdef01,
              "misaligned store has no side effect");
        restart;
        dut.data_path.im_inst.memory[0] = 32'h00002023;
        dut.data_path.dm_inst.mem[0] = 32'habcdef01;
        reset = 1;
        enable = 1;
        @(negedge clk);
        enable = 0;
        reset = 0;
        check(dut.data_path.dm_inst.mem[0] == 32'habcdef01 && pc == 0,
              "reset takes priority over enabled store");

        $display("PASS tb_regression: %0d checks", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "Regression test timed out");
    end
endmodule
