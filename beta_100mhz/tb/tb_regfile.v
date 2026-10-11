`timescale 1ns / 1ps

module tb_regfile;
    reg clk = 0, reset = 0, enable = 1, write_enable = 0;
    reg [4:0] write_address = 0, address1 = 0, address2 = 0;
    reg [31:0] write_data = 0;
    wire [31:0] data1, data2;
    reg [31:0] expected [0:31];
    integer i, j, checks = 0;

    RegFile dut(clk, reset, enable, write_enable, write_address,
                address1, address2, write_data, data1, data2);
    always #5 clk = ~clk;

    task check;
        input condition;
        begin
            if (condition !== 1'b1)
                $fatal(1, "Register read mismatch: addresses %0d, %0d", address1, address2);
            checks = checks + 1;
        end
    endtask

    initial begin
        #1; reset = 1;
        @(negedge clk); reset = 0;
        write_enable = 1;
        for (i = 0; i < 32; i = i + 1) begin
            write_address = i;
            write_data = 32'h12345678 ^ (32'h01010101 * i);
            expected[i] = (i == 0) ? 0 : write_data;
            @(negedge clk);
        end
        write_enable = 0;
        for (i = 0; i < 32; i = i + 1)
            for (j = 0; j < 32; j = j + 1) begin
                address1 = i; address2 = j; #1;
                check(data1 == expected[i] && data2 == expected[j]);
            end

        @(negedge clk);
        enable = 0; write_enable = 1;
        write_address = 1; write_data = 32'hffffffff;
        @(negedge clk);
        address1 = 1; address2 = 0; #1;
        check(data1 == expected[1] && data2 == 0);
        enable = 1; write_enable = 0;
        @(negedge clk); #1;
        check(data1 == expected[1]);

        reset = 1; #1;
        for (i = 0; i < 32; i = i + 1) begin
            address1 = i; address2 = 31-i; #1;
            check(data1 == 0 && data2 == 0);
        end
        $display("PASS tb_regfile: %0d checks", checks);
        $finish;
    end
endmodule
