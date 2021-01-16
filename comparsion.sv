`ifndef COMPARSION_SV
`define COMPARSION_SV

`include "flipflop.sv"

module comparator #(parameter WIDTH=1) (
input wire [WIDTH-1:0] a,
input wire [WIDTH-1:0] b,
output reg agb,
output wire ageb,
output reg aeb,
output wire aleb,
output reg alb);

assign aleb = ~agb;
assign ageb = ~alb;

always @(*) begin
	if(a > b) agb <= 1'b1;
	else agb <= 1'b0;

	if(a == b) aeb <= 1'b1;
	else aeb <= 1'b0;
	
	if(a < b) alb <= 1'b1;
	else alb <= 1'b0;
end

endmodule

module synchronous_comparator #(parameter WIDTH=1) (
input wire clk,
input wire ena,
input wire srst,
input wire arst,
input wire [WIDTH-1:0] a,
input wire [WIDTH-1:0] b,
output wire agb,
output wire ageb,
output wire aeb,
output wire aleb,
output wire alb);

comparator #(WIDTH) comp (.a(a),.b(b),.agb(agb_d),.ageb(ageb_d),.aeb(aeb_d),.aleb(aleb_d),.alb(alb_d));

d_flip_flop #(5) buffer (.clk(clk),.ena(ena),.d({agb_d,ageb_d,aeb_d,aleb_d,alb_d}),.srst(srst),.arst(arst),.q({agb,ageb,aeb,aleb,alb}));

endmodule

`endif
