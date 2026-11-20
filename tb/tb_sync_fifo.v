`timescale 1ns/1ps

module tb_sync_fifo;

    parameter WIDTH           = 8;
    parameter DEPTH           = 8;
    // 0: rd_data is the front entry whenever !empty (front-of-queue read)
    // 1: rd_data is a register that holds the popped entry the cycle after rd_en
    parameter REGISTERED_READ = 0;
    parameter CYCLES          = 200000;
    parameter SEED            = 1;
    parameter DUMP            = 0;
    parameter MAX_PRINTS      = 20;

    localparam AW = $clog2(DEPTH);

    reg              clk;
    reg              rst_n;
    reg              wr_en;
    reg  [WIDTH-1:0] wr_data;
    reg              rd_en;

    wire [WIDTH-1:0] rd_data;
    wire             full;
    wire             empty;
    wire [AW:0]      count;
    wire             overflow;

    sync_fifo #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .rd_en    (rd_en),
        .full     (full),
        .empty    (empty),
        .rd_data  (rd_data),
        .count    (count),
        .overflow (overflow)
    );

    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Reference model: circular buffer with a head index and a count.
    // ------------------------------------------------------------------
    reg [WIDTH-1:0] ref_mem [0:DEPTH-1];
    integer         ref_head;
    integer         ref_count;
    reg [WIDTH-1:0] last_popped;
    reg             pop_prev;

    integer errors;
    integer cycle;
    integer seed;

    // Coverage counters: they show the corner cases were really exercised.
    integer cov_full;
    integer cov_empty;
    integer cov_rw_one;
    integer cov_rw_empty;
    integer cov_wr_full;
    integer cov_rd_empty;
    integer cov_wrap;
    integer cov_overflow;
    integer cov_reset;

    integer p_wr;
    integer p_rd;

    task report_error(input [8*40-1:0] what);
        begin
            errors = errors + 1;
            if (errors <= MAX_PRINTS)
                $display("FAIL cycle %0d: %0s | wr_en=%b rd_en=%b wr_data=%0h | model count=%0d | dut full=%b empty=%b count=%0d overflow=%b rd_data=%0h",
                         cycle, what, wr_en, rd_en, wr_data, ref_count,
                         full, empty, count, overflow, rd_data);
        end
    endtask

    // Compare every output with the reference model (before the clock edge).
    task check_outputs;
        reg exp_full;
        reg exp_empty;
        reg exp_overflow;
        begin
            exp_full     = (ref_count == DEPTH);
            exp_empty    = (ref_count == 0);
            exp_overflow = wr_en && (ref_count == DEPTH);

            if (full !== exp_full)         report_error("full mismatch");
            if (empty !== exp_empty)       report_error("empty mismatch");
            if (count !== ref_count)       report_error("count mismatch");
            if (overflow !== exp_overflow) report_error("overflow mismatch");

            if (REGISTERED_READ == 0) begin
                if (ref_count > 0 && rd_data !== ref_mem[ref_head])
                    report_error("rd_data is not the front entry");
            end
            else begin
                if (pop_prev && rd_data !== last_popped)
                    report_error("rd_data is not the popped entry");
            end
        end
    endtask

    // Apply this cycle's inputs to the reference model.
    task update_model;
        reg do_wr;
        reg do_rd;
        integer tail;
        begin
            do_wr = wr_en && (ref_count < DEPTH);
            do_rd = rd_en && (ref_count > 0);
            tail  = (ref_head + ref_count) % DEPTH;

            if (ref_count == DEPTH) cov_full = cov_full + 1;
            if (ref_count == 0)     cov_empty = cov_empty + 1;
            if (wr_en && rd_en && ref_count == 1)     cov_rw_one   = cov_rw_one + 1;
            if (wr_en && rd_en && ref_count == 0)     cov_rw_empty = cov_rw_empty + 1;
            if (wr_en && ref_count == DEPTH)          cov_wr_full  = cov_wr_full + 1;
            if (rd_en && ref_count == 0)              cov_rd_empty = cov_rd_empty + 1;
            if (wr_en && ref_count == DEPTH)          cov_overflow = cov_overflow + 1;

            if (do_wr) ref_mem[tail] = wr_data;
            if (do_rd) begin
                last_popped = ref_mem[ref_head];
                ref_head    = (ref_head + 1) % DEPTH;
                if (ref_head == 0) cov_wrap = cov_wrap + 1;
            end
            ref_count = ref_count + (do_wr ? 1 : 0) - (do_rd ? 1 : 0);
            pop_prev  = do_rd;
        end
    endtask

    task drive_random;
        begin
            wr_en   = (($random(seed) & 32'h7fffffff) % 100) < p_wr;
            rd_en   = (($random(seed) & 32'h7fffffff) % 100) < p_rd;
            wr_data = $random(seed);
        end
    endtask

    // One clock cycle: drive inputs, let outputs settle, check, update model.
    task run_cycle;
        begin
            @(negedge clk);
            drive_random;
            #1;
            check_outputs;
            update_model;
            cycle = cycle + 1;
        end
    endtask

    task run_phase(input integer n, input integer pw, input integer pr);
        integer k;
        begin
            p_wr = pw;
            p_rd = pr;
            for (k = 0; k < n; k = k + 1) run_cycle;
        end
    endtask

    // Asynchronous reset in the middle of a cycle, with entries present.
    task async_reset_test;
        begin
            @(negedge clk);
            wr_en = 1'b0;
            rd_en = 1'b0;
            #2;
            rst_n = 1'b0;
            #1;
            ref_count   = 0;
            ref_head    = 0;
            pop_prev    = 1'b0;
            cov_reset   = cov_reset + 1;
            check_outputs;
            #6;
            check_outputs;
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    initial begin
        if (DUMP) begin
            $dumpfile("tb_sync_fifo.vcd");
            $dumpvars(0, tb_sync_fifo);
        end
    end

    integer i;
    initial begin
        clk          = 1'b0;
        rst_n        = 1'b0;
        wr_en        = 1'b0;
        rd_en        = 1'b0;
        wr_data      = {WIDTH{1'b0}};
        errors       = 0;
        cycle        = 0;
        seed         = SEED;
        ref_head     = 0;
        ref_count    = 0;
        last_popped  = {WIDTH{1'b0}};
        pop_prev     = 1'b0;
        cov_full     = 0;
        cov_empty    = 0;
        cov_rw_one   = 0;
        cov_rw_empty = 0;
        cov_wr_full  = 0;
        cov_rd_empty = 0;
        cov_wrap     = 0;
        cov_overflow = 0;
        cov_reset    = 0;
        p_wr         = 50;
        p_rd         = 50;

        #23;
        check_outputs;
        @(negedge clk);
        rst_n = 1'b1;

        // Phases chosen to reach every corner repeatedly
        for (i = 0; i < CYCLES / 1000; i = i + 1) begin
            run_phase(100, 90, 10);    // mostly writing: reach full, overflow
            run_phase(100, 10, 90);    // mostly reading: reach empty
            run_phase(200, 50, 50);    // balanced: hover around the middle
            run_phase(100, 100, 100);  // always both: read+write together
            run_phase(100, 100, 0);    // writes only: fill and overflow
            run_phase(100, 0, 100);    // reads only: drain, read when empty
            run_phase(100, 60, 40);
            run_phase(100, 40, 60);
            if (i % 20 == 10) async_reset_test;
        end

        $display("coverage: full=%0d empty=%0d rw_with_1_entry=%0d rw_when_empty=%0d wr_when_full=%0d rd_when_empty=%0d ptr_wraps=%0d overflows=%0d resets=%0d",
                 cov_full, cov_empty, cov_rw_one, cov_rw_empty, cov_wr_full,
                 cov_rd_empty, cov_wrap, cov_overflow, cov_reset);

        if (cov_full == 0 || cov_empty == 0 || cov_rw_one == 0 ||
            cov_rw_empty == 0 || cov_wr_full == 0 || cov_rd_empty == 0 ||
            cov_wrap == 0 || cov_reset == 0) begin
            errors = errors + 1;
            $display("FAIL: a corner case was never exercised");
        end

        $display("----------------------------------------");
        if (errors == 0)
            $display("PASS: %0d cycles, 0 errors (WIDTH=%0d DEPTH=%0d REGISTERED_READ=%0d)",
                     cycle, WIDTH, DEPTH, REGISTERED_READ);
        else
            $display("FAIL: %0d errors in %0d cycles (WIDTH=%0d DEPTH=%0d REGISTERED_READ=%0d)",
                     errors, cycle, WIDTH, DEPTH, REGISTERED_READ);
        $finish;
    end

endmodule
