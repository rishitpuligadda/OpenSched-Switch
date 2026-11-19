module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
) (
    input                             clk,
    input wire                        rst_n,
    input wire                        wr_en,
    input wire  [WIDTH-1:0]           wr_data,
    input wire                        rd_en,
    output wire                       full,
    output wire                       empty,
    output wire [WIDTH-1:0]           rd_data,
    output wire [($clog2(DEPTH))-1:0] count,
    output wire                       overflow
);


endmodule
