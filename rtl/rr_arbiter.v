module rr_arbiter #(
    parameter N = 4
) (
    input                        clk,
    input                        rst_n,
    input      [($clog2(N))-1:0] ptr,
    input      [N-1:0]           req,
    output reg [N-1:0]           grant
);
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n || ~|req) begin
			grant <= '0;
		end
		else if (req[ptr]) begin
			grant <= 1 << ptr;
		end
		else begin
			for (int i = 1; i < N; i=i+1) begin
				int idx = ptr + i;

				if (idx >= N) begin
					idx = idx - N;
				end

				if (req[idx]) begin
					grant <= 1 << idx;
					break;
				end
			end
		end
	end
endmodule
