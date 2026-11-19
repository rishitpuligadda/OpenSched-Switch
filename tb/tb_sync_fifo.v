module tb_sync_fifo;

    // Parameters
    parameter WIDTH      = 8;
    parameter DEPTH      = 8;
    parameter CLK_PERIOD = 10;
    parameter RESET_TIME = 50;
    parameter SIM_TIME   = 1000;

    // DUT inputs (driven by the TB)
    reg                        clk;
    reg                        rst_n;
    reg                        wr_en;
    reg  [WIDTH-1:0]           wr_data;
    reg                        rd_en;

    // DUT outputs (observed by the TB)
    wire                       full;
    wire                       empty;
    wire [WIDTH-1:0]           rd_data;
    wire [($clog2(DEPTH))-1:0] count;
    wire                       overflow;

    // Clock generators
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    // DUT instantiation
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

    // Stimulus and monitoring
    initial begin
        clk     = 1'b0;
        rst_n   = 1'b0;   // reset asserted
        wr_en   = 0;
        wr_data = 0;
        rd_en   = 0;

        $timeformat(-9, 1, " ns", 0);
        $monitor("time=%0t | rst_n=%0h wr_en=%0h wr_data=%0h rd_en=%0h full=%0h empty=%0h rd_data=%0h count=%0h overflow=%0h", $time, rst_n, wr_en, wr_data, rd_en, full, empty, rd_data, count, overflow);

        // Release reset(s)
        #(RESET_TIME);
        rst_n   = 1'b1;

        // TODO: add test stimulus here

        #(SIM_TIME) $finish;
    end

endmodule
