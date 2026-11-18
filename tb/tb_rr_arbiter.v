`timescale 1ns/1ps

module tb_rr_arbiter;

    parameter N          = 4;
    parameter CLK_PERIOD = 10;
    parameter RESET_TIME = 50;
    parameter WATCHDOG   = 100000000;
    parameter VERBOSE    = 0;

    reg                    clk;
    reg                    rst_n;
    reg  [($clog2(N))-1:0] ptr;
    reg  [N-1:0]           req;

    wire [N-1:0]           grant;

    integer errors;
    integer checks;

    always #(CLK_PERIOD / 2.0) clk = ~clk;

    rr_arbiter #(
        .N (N)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .ptr   (ptr),
        .req   (req),
        .grant (grant)
    );

    // Reference model: scan ptr, ptr+1, ... (wrapping) and take the first
    // requester. Written with % so it shares no logic with the DUT.
    function [N-1:0] ref_grant(input integer p, input [N-1:0] r);
        integer k;
        integer idx;
        reg     found;
        begin
            ref_grant = {N{1'b0}};
            found     = 1'b0;
            for (k = 0; k < N; k = k + 1) begin
                idx = (p + k) % N;
                if (!found && r[idx]) begin
                    ref_grant[idx] = 1'b1;
                    found = 1'b1;
                end
            end
        end
    endfunction

    task fail(input [8*48-1:0] what);
        begin
            errors = errors + 1;
            $display("FAIL @%0t: %0s | ptr=%0d req=%b grant=%b",
                     $time, what, ptr, req, grant);
        end
    endtask

    // Drive on the falling edge, sample just after the next rising edge.
    // The DUT registers its grant, so the grant for the inputs driven here
    // appears one clock later.
    task apply_and_check(input integer p, input [N-1:0] r);
        reg [N-1:0] expected;
        begin
            @(negedge clk);
            ptr = p;
            req = r;
            @(posedge clk);
            #1;
            expected = ref_grant(p, r);
            checks = checks + 1;

            if (grant !== expected) begin
                errors = errors + 1;
                $display("FAIL @%0t: ptr=%0d req=%b expected=%b got=%b",
                         $time, p, r, expected, grant);
            end

            // Properties that must hold regardless of the reference model
            if (^grant === 1'bx)
                fail("grant has X");
            else begin
                if ((grant & (grant - 1'b1)) !== {N{1'b0}})
                    fail("grant is not one-hot or zero");
                if ((grant & ~r) !== {N{1'b0}})
                    fail("granted an input that did not request");
                if ((r !== {N{1'b0}}) && (grant === {N{1'b0}}))
                    fail("requests present but no grant");
                if ((r === {N{1'b0}}) && (grant !== {N{1'b0}}))
                    fail("grant without any request");
            end
        end
    endtask

    // Every (ptr, req) combination for small N. For N > 10 the full space is
    // too large, so use a fixed number of random combinations instead.
    task test_exhaustive;
        integer p;
        integer r;
        integer n;
        reg [N-1:0] rr;
        begin
            if (N <= 10) begin
                $display("[exhaustive] all %0d ptr x %0d req combinations", N, 1 << N);
                for (p = 0; p < N; p = p + 1)
                    for (r = 0; r < (1 << N); r = r + 1)
                        apply_and_check(p, r);
            end
            else begin
                $display("[random] N=%0d is too large for exhaustive, using 20000 random cases", N);
                for (n = 0; n < 20000; n = n + 1) begin
                    rr = {$random, $random, $random};
                    apply_and_check({$random} % N, rr);
                end
                // single requesters at every position for every pointer
                for (p = 0; p < N; p = p + 1)
                    for (r = 0; r < N; r = r + 1) begin
                        rr = {N{1'b0}};
                        rr[r] = 1'b1;
                        apply_and_check(p, rr);
                    end
            end
        end
    endtask

    // Pointer follows the usual rule (grant index + 1), requests held constant.
    // Grants must rotate through the requesters, so counts differ by <= 1.
    task test_fairness(input [N-1:0] r, input integer cycles);
        integer c, i, idx, p;
        integer lo, hi, nreq;
        integer counts [0:N-1];
        begin
            $display("[fairness] req=%b over %0d cycles", r, cycles);
            for (i = 0; i < N; i = i + 1) counts[i] = 0;
            p = 0;
            for (c = 0; c < cycles; c = c + 1) begin
                apply_and_check(p, r);
                idx = -1;
                for (i = 0; i < N; i = i + 1)
                    if (grant[i]) idx = i;
                if (idx >= 0) begin
                    counts[idx] = counts[idx] + 1;
                    p = (idx + 1) % N;
                end
            end

            lo = cycles; hi = 0; nreq = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (r[i]) begin
                    nreq = nreq + 1;
                    if (counts[i] < lo) lo = counts[i];
                    if (counts[i] > hi) hi = counts[i];
                end else if (counts[i] != 0) begin
                    fail("non-requester was granted");
                end
                $display("    input %0d: %0d grants", i, counts[i]);
            end
            if (nreq > 0 && (hi - lo) > 1)
                fail("unfair: grant counts differ by more than 1");
        end
    endtask

    // Reset must clear the grant immediately (async), even with requests held
    task test_async_reset;
        begin
            $display("[reset] async reset in the middle of operation");
            apply_and_check(1, {N{1'b1}});
            if (grant === {N{1'b0}}) fail("expected a grant before reset");
            rst_n = 1'b0;
            #1;
            checks = checks + 1;
            if (grant !== {N{1'b0}}) fail("grant not cleared asynchronously");
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (grant !== {N{1'b0}}) fail("grant not held at 0 during reset");
            @(negedge clk);
            rst_n = 1'b1;
            apply_and_check(0, {N{1'b1}});
        end
    endtask

    initial begin
        $dumpfile("tb_rr_arbiter.vcd");
        $dumpvars(0, tb_rr_arbiter);
    end

    initial begin
        #(WATCHDOG);
        $display("FAIL: watchdog timeout");
        $finish;
    end

    initial begin
        clk    = 1'b0;
        rst_n  = 1'b0;
        ptr    = 0;
        req    = {N{1'b1}};
        errors = 0;
        checks = 0;

        $timeformat(-9, 1, " ns", 0);
        if (VERBOSE)
            $monitor("time=%0t | rst_n=%0h ptr=%0h req=%b grant=%b",
                     $time, rst_n, ptr, req, grant);

        #(RESET_TIME);
        checks = checks + 1;
        if (grant !== {N{1'b0}}) fail("grant not 0 during reset");

        @(negedge clk);
        rst_n = 1'b1;

        test_exhaustive;

        // Request patterns are constants truncated to N bits:
        // 5 = 0101 (inputs 0 and 2), 11 = 1011 (inputs 0, 1 and 3)
        test_fairness({N{1'b1}}, 10 * N);
        if (N >= 3) test_fairness(5, 10 * N);
        if (N >= 4) test_fairness(11, 10 * N);

        test_async_reset;

        $display("----------------------------------------");
        if (errors == 0)
            $display("PASS: %0d checks, 0 errors", checks);
        else
            $display("FAIL: %0d errors in %0d checks", errors, checks);
        $finish;
    end

endmodule
