module rr_arbiter #(
    parameter N = 4
) (
    input                        clk,
    input                        rst_n,
    input      [($clog2(N))-1:0] ptr,
    input      [N-1:0]           req,
    output reg [N-1:0]           grant
);
	integer i;
	integer idx;
	reg     found;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n || ~|req) begin
			grant <= {N{1'b0}};
		end
		else if (req[ptr]) begin
			grant <= {{(N-1){1'b0}}, 1'b1} << ptr;
		end
		else begin
			found = 1'b0;
			for (i = 1; i < N; i=i+1) begin
				idx = ptr + i;

				if (idx >= N) begin
					idx = idx - N;
				end

				if (!found && req[idx]) begin
					grant <= {{(N-1){1'b0}}, 1'b1} << idx;
					found = 1'b1;
				end
			end
		end
	end
endmodule
