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
    output reg  [WIDTH-1:0]           rd_data,
    output wire [$clog2(DEPTH):0] count,
    output wire                       overflow
);
	reg [WIDTH-1:0] memory [DEPTH-1:0];
	reg [$clog2(DEPTH):0] rd_ptr, wr_ptr;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			rd_ptr  <= {($clog2(DEPTH)+1){1'b0}};
		end
		else if (!empty && rd_en) begin
			rd_ptr  <= rd_ptr + {{$clog2(DEPTH){1'b0}}, 1'b1};
		end
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			wr_ptr <= {($clog2(DEPTH)+1){1'b0}};
		end
		else if (!full && wr_en) begin
			memory[wr_ptr[($clog2(DEPTH))-1:0]] <= wr_data;
			wr_ptr                              <= wr_ptr + {{$clog2(DEPTH){1'b0}}, 1'b1};
		end
	end

	assign rd_data  = memory[rd_ptr[($clog2(DEPTH))-1:0]];
	assign full     = (wr_ptr[$clog2(DEPTH)] != rd_ptr[$clog2(DEPTH)]) && (wr_ptr[$clog2(DEPTH)-1:0] == rd_ptr[$clog2(DEPTH)-1:0]);
	assign empty    = (wr_ptr == rd_ptr);
	assign count    = wr_ptr - rd_ptr;
	assign overflow = full & wr_en;
endmodule
