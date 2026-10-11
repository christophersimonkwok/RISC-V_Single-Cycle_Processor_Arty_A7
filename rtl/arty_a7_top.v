`timescale 1ns / 1ps

// Arty A7-100T controls around the original single-cycle processor.
module arty_a7_top #(
    parameter integer DEBOUNCE_CYCLES = 500000, // 10 ms at 50 MHz
    parameter integer RUN_CYCLES = 25000000,    // one instruction every 0.5 seconds
    parameter integer DEMO_INSTRUCTIONS = 20   // 0 disables the demo end stop
)(
    input CLK100MHZ,
    input [3:0] btn,
    input [3:0] sw,
    output [3:0] led,
    output led0_r,
    output led0_g,
    output led0_b
);
    wire clk50;
    wire clock_locked;

`ifdef BOARD_SIM
    // Simulation only: ideal 50 MHz clock and a short lock delay.
    // The hardware branch below always uses the FPGA clock manager.
    reg sim_clk50 = 0;
    reg sim_locked = 0;
    reg [3:0] lock_count = 0;
    always @(posedge CLK100MHZ or posedge btn[0]) begin
        if (btn[0]) begin
            sim_clk50 <= 0;
            sim_locked <= 0;
            lock_count <= 0;
        end else begin
            sim_clk50 <= ~sim_clk50;
            if (lock_count == 4'd7)
                sim_locked <= 1;
            else
                lock_count <= lock_count + 1'b1;
        end
    end
    assign clk50 = sim_clk50;
    assign clock_locked = sim_locked;
`else
    wire clk100_buffered;
    wire feedback;
    wire feedback_buffered;
    wire clk50_unbuffered;

    IBUF clock_input (.I(CLK100MHZ), .O(clk100_buffered));
    // 100 MHz * 8 / 1 = 800 MHz VCO; 800 / 16 = 50 MHz.
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .CLKFBOUT_MULT_F(8.0),
        .DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(16.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .STARTUP_WAIT("FALSE")
    ) clock_mmcm (
        .CLKIN1(clk100_buffered),
        .CLKFBIN(feedback_buffered),
        .CLKFBOUT(feedback),
        .CLKOUT0(clk50_unbuffered),
        .LOCKED(clock_locked),
        .PWRDWN(1'b0),
        .RST(btn[0])
    );
    BUFG feedback_buffer (.I(feedback), .O(feedback_buffered));
    BUFG processor_clock (.I(clk50_unbuffered), .O(clk50));
`endif

    // Hold reset while the clock is unlocked; release it on 50 MHz edges.
    (* ASYNC_REG = "TRUE" *) reg [2:0] reset_release = 3'b111;
    always @(posedge clk50 or negedge clock_locked) begin
        if (!clock_locked)
            reset_release <= 3'b111;
        else
            reset_release <= {reset_release[1:0], 1'b0};
    end
    wire startup_reset = |reset_release;

    // First synchronize the physical buttons and switches.
    (* ASYNC_REG = "TRUE" *) reg [3:0] btn_meta = 0, btn_sync = 0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] sw_meta = 0, sw_sync = 0;
    always @(posedge clk50) begin
        btn_meta <= btn;
        btn_sync <= btn_meta;
        sw_meta <= sw;
        sw_sync <= sw_meta;
    end

    reg [3:0] level = 0;
    reg [3:0] previous = 0;
    wire [3:0] pressed = level & ~previous;
    localparam integer DW = (DEBOUNCE_CYCLES < 2) ? 1 : $clog2(DEBOUNCE_CYCLES);
    genvar k;
    generate
        for (k = 0; k < 4; k = k + 1) begin: debounce
            reg [DW-1:0] count = 0;
            always @(posedge clk50) begin
                if (startup_reset) begin
                    count <= 0;
                    level[k] <= 0;
                end else if (btn_sync[k] == level[k]) begin
                    count <= 0;
                end else if (count == DEBOUNCE_CYCLES-1) begin
                    level[k] <= btn_sync[k];
                    count <= 0;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    endgenerate
    always @(posedge clk50) begin
        if (startup_reset)
            previous <= 0;
        else
            previous <= level;
    end

    wire reset = startup_reset | level[0];
    wire fault;
    wire [31:0] result;
    wire [31:0] writeback;
    wire [7:0] pc;
    reg running = 0;
    reg show_pc = 0;
    localparam integer RW = (RUN_CYCLES < 2) ? 1 : $clog2(RUN_CYCLES);
    reg [RW-1:0] run_count = 0;
    wire tick = running && (run_count == RUN_CYCLES-1);

    // The supplied sequential demo finishes at PC 80. Freeze its last result
    // instead of continuing through padding NOPs and eventually wrapping.
    // For a different program, adjust DEMO_INSTRUCTIONS (1..63), or use 0
    // to retain unrestricted stepping/run through all 64 ROM words.
    wire demo_done = (DEMO_INSTRUCTIONS != 0) && (pc == DEMO_INSTRUCTIONS*4);
    wire final_step = (DEMO_INSTRUCTIONS != 0) && (pc == (DEMO_INSTRUCTIONS-1)*4);
    // Pause requests win over an automatic tick. BTN1 pauses playback; the
    // next separate BTN1 press commits one instruction. BTN2 has priority
    // over a simultaneous step request.
    wire core_enable = !reset && !fault && !demo_done && !pressed[2] &&
                       ((!running && pressed[1]) || (tick && !pressed[1]));
    always @(posedge clk50) begin
        if (reset || fault || demo_done || (core_enable && final_step)) begin
            running <= 0;
            run_count <= 0;
        end else if (pressed[1]) begin
            running <= 0;
            run_count <= 0;
        end else if (pressed[2]) begin
            running <= ~running;
            run_count <= 0;
        end else if (!running || tick) begin
            run_count <= 0;
        end else begin
            run_count <= run_count + 1'b1;
        end
    end

    // A tap selects a persistent view; inspection never requires holding BTN3.
    always @(posedge clk50) begin
        if (reset)
            show_pc <= 0;
        else if (pressed[3])
            show_pc <= ~show_pc;
    end

    // Clock enable controls instruction commits; it does not create a new clock.
    processor core (
        .clk(clk50), .reset(reset), .enable(core_enable),
        .Result(result), .fault(fault),
        .debug_pc(pc), .debug_writeback(writeback)
    );

    wire [31:0] display_word = show_pc ? {24'b0, pc} :
                              (sw_sync[3] ? writeback : result);
    assign led = display_word >> (sw_sync[2:0] * 4);
    assign led0_r = fault;
    assign led0_g = running && !fault && !reset;
    assign led0_b = !running && !fault && !reset;
endmodule
