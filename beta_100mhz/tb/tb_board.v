`timescale 1ns / 1ps

// BOARD_SIM selects the ideal clock model; use small counters for this test.
module tb_board;
    reg clk = 0;
    reg [3:0] btn = 0, sw = 0;
    wire [3:0] led;
    wire red, green, blue;
    integer checks = 0;
    integer i;
    reg [7:0] saved_pc;
    time first_edge;
    reg [31:0] expected_word;

    arty_a7_top #(.DEBOUNCE_CYCLES(3), .RUN_CYCLES(40)) dut (
        .CLK100MHZ(clk), .btn(btn), .sw(sw), .led(led),
        .led0_r(red), .led0_g(green), .led0_b(blue)
    );
    always #5 clk = ~clk; // board input is still 100 MHz

    task check;
        input condition;
        input [8*100-1:0] message;
        begin
            if (condition !== 1'b1)
                $fatal(1, "FAIL: %0s", message);
            checks = checks + 1;
        end
    endtask

    task cycles;
        input integer n;
        begin
            repeat (n) @(negedge dut.cpu_clk);
        end
    endtask

    task press;
        input integer button;
        begin
            btn[button] = 1;
            cycles(12);
            btn[button] = 0;
            cycles(12);
        end
    endtask

    task restart;
        begin
            // BTN0 resets the clock manager, so wait on the input clock here.
            btn[0] = 1;
            repeat (8) @(negedge clk);
            btn[0] = 0;
            repeat (40) @(negedge clk);
            cycles(4);
        end
    endtask

    initial begin
        #1;
        check(dut.startup_reset && !blue && !green,
              "processor stays in reset before clock lock");
        repeat (40) @(negedge clk);
        cycles(4);
        check(dut.clock_locked && dut.pc == 0 && blue && !red && !green,
              "startup locks and pauses at PC zero");
        @(posedge dut.cpu_clk);
        first_edge = $time;
        @(posedge dut.cpu_clk);
        check($time - first_edge == 10, "internal clock period is 10 ns");
        cycles(1);

        btn[1] = 1;
        cycles(1);
        btn[1] = 0;
        cycles(12);
        check(dut.pc == 0, "short button bounce is rejected");
        btn[1] = 1;
        cycles(30);
        check(dut.pc == 4, "held step button advances exactly once");
        btn[1] = 0;
        cycles(12);
        press(1);
        check(dut.pc == 8 && led == 1, "second step displays ADDI result");

        press(2);
        cycles(100);
        check(green && dut.pc > 8, "run commits automatic instructions");
        press(2);
        saved_pc = dut.pc;
        cycles(100);
        check(blue && !green && dut.pc == saved_pc, "pause stops automatic execution");
        restart;
        check(dut.pc == 0 && blue && !green && !red, "BTN0 resets and pauses");

        repeat (18) press(1);
        expected_word = 32'hfffffb2c;
        for (i = 0; i < 8; i = i + 1) begin
            sw = i;
            cycles(4);
            check(led == ((expected_word >> (i*4)) & 32'hf),
                  "switches select each of the eight result nibbles");
        end
        press(1);
        press(1);
        sw = 0;
        cycles(4);
        check(dut.pc == 80 && led == 0, "ALU address low nibble after load");
        sw = 1;
        cycles(4);
        check(led == 3, "ALU address high nibble");
        sw = 8;
        cycles(4);
        check(led == 5, "writeback display shows the loaded word");
        btn[3] = 1;
        cycles(12);
        check(led == 0 && dut.show_pc, "BTN3 selects PC low nibble");
        cycles(20);
        check(dut.show_pc, "held BTN3 toggles the view only once");
        sw = 9;
        cycles(4);
        check(led == 5, "PC high nibble is five at PC 0x50");
        btn[3] = 0;
        cycles(12);
        check(dut.show_pc && led == 5, "PC view remains selected after release");
        sw = 8;
        cycles(4);
        press(3);
        check(!dut.show_pc && led == 5, "second BTN3 tap returns to loaded data");
        press(1);
        press(2);
        cycles(100);
        check(dut.pc == 80 && blue && !green && led == 5,
              "completed manual demo stays at final load despite more button presses");

        restart;
        check(!dut.show_pc, "reset returns the display to result view");
        press(2);
        cycles(900);
        check(dut.pc == 80 && blue && !green && dut.writeback == 5,
              "automatic demo stops after all twenty instructions");
        cycles(200);
        check(dut.pc == 80, "completed automatic demo cannot wrap through NOP padding");

        restart;
        press(2);
        cycles(50);
        press(1);
        saved_pc = dut.pc;
        cycles(100);
        check(blue && !green && dut.pc == saved_pc,
              "BTN1 while running pauses without repeated commits");
        press(1);
        check(dut.pc == saved_pc + 4, "BTN1 after pausing commits one instruction");

        // Align a debounced pause event to the exact automatic tick edge.
        restart;
        press(2);
        btn[2] = 1;
        wait (dut.pressed[2]);
        @(negedge dut.cpu_clk);
        saved_pc = dut.pc;
        force dut.run_count = 39;
        @(negedge dut.cpu_clk);
        check(dut.pc == saved_pc && blue && !green,
              "pause request suppresses a coincident automatic tick");
        release dut.run_count;
        btn[2] = 0;
        cycles(12);

        // An asynchronous loss of LOCKED must assert reset immediately.
        force dut.sim_locked = 0;
        #1;
        check(dut.startup_reset && !blue && !green, "loss of lock asserts reset");
        cycles(4);
        check(dut.pc == 0, "processor resets while clock is unlocked");
        release dut.sim_locked;
        cycles(8);
        check(dut.pc == 0 && blue, "reset releases after stable clock edges");

        restart;
        dut.core.data_path.im_inst.memory[0] = 32'hffffffff;
        press(1);
        check(red && !green && !blue && dut.pc == 0,
              "fault is visible and blocks instruction commit");
        press(2);
        cycles(50);
        check(red && !green && dut.pc == 0, "run cannot bypass a fault");
        restart;
        check(!red && blue && dut.pc == 0, "reset clears the fault indicator");
        $display("PASS tb_board: %0d checks", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Board test timed out");
    end
endmodule
