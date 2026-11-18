module rr_arbiter #(
    parameter N = 4
) (
    input                        clk,
    input                        rst_n,
    input      [($clog2(N))-1:0] ptr,
    input      [N-1:0]           req,
    output reg [N-1:0]           grant
);
	reg [N-1:0] next_grant;
	integer     idx;
	integer     i;
	reg         found;

	always @(*) begin
		next_grant = {N{1'b0}};
		found      = 1'b0;

		if (~|req) begin
			next_grant = {N{1'b0}};
		end
		else if (req[ptr]) begin
			next_grant = 1 << ptr;
		end
		else begin
			for (i = 1; i < N; i = i + 1) begin
				idx = ptr + i;
				if (idx >= N) begin
					idx = idx - N;
				end

				if (!found && req[idx]) begin
					next_grant = {{(N-1){1'b0}}, 1'b1} << idx;
					found      = 1'b1;
				end
			end
		end
	end

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			grant <= {N{1'b0}};
		end
		else begin
			grant <= next_grant;
		end
	end
endmodule
