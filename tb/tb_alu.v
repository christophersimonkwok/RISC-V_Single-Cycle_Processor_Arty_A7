`timescale 1ns / 1ps

module tb_alu;
    reg [31:0] a, b;
    reg [3:0] op;
    wire [31:0] result;
    wire carry, overflow, zero;
    integer checks = 0;
    alu32 dut (.A(a), .B(b), .Op(op), .Result(result),
               .CarryOut(carry), .Overflow(overflow), .Zero(zero));

    task check;
        input [31:0] va, vb;
        input [3:0] operation;
        input [31:0] expected;
        input expected_carry, expected_overflow, expected_zero;
        begin
            a = va;
            b = vb;
            op = operation;
            #1;
            if (result !== expected || carry !== expected_carry ||
                overflow !== expected_overflow || zero !== expected_zero)
                $fatal(1, "ALU op %h: got %h C=%b V=%b Z=%b",
                       op, result, carry, overflow, zero);
            checks = checks + 1;
        end
    endtask

    initial begin
        check(32'hf0f0aa55, 32'h0ff00ff0, 4'd0, 32'h00f00a50, 0, 0, 0);
        check(32'hf0f0aa55, 32'h0ff00ff0, 4'd1, 32'hfff0aff5, 0, 0, 0);
        check(32'h7fffffff, 1, 4'd2, 32'h80000000, 0, 1, 0);
        check(32'hffffffff, 1, 4'd2, 0, 1, 0, 1);
        check(5, 9, 4'd6, 32'hfffffffc, 0, 0, 0);
        check(32'h80000000, 1, 4'd6, 32'h7fffffff, 0, 1, 0);
        check(32'hffffffff, 1, 4'd7, 1, 0, 0, 0);
        check(1, 32'hffffffff, 4'd7, 0, 0, 0, 1);
        check(32'h12345678, 32'h0f0f0f0f, 4'd12, 32'he0c0a080, 0, 0, 0);
        check(17, 17, 4'd15, 1, 0, 0, 0);
        check(17, 18, 4'd15, 0, 0, 0, 1);
        check(0, 1, 4'd0, 0, 0, 0, 1);
        $display("PASS tb_alu: %0d checks", checks);
        $finish;
    end
endmodule
