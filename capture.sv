`ifndef CAPTURE_SV
`define CAPTURE_SV

module input_filter #(parameter WIDTH=1)
(   input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] data,
    input wire in,
    output wire out
);

wire [WIDTH-1:0] filter_counter_out;
counter #(WIDTH) filter_counter
(   .clk(clk),
    .ena(~filter_counter_carry & (~filter_counter2_carry | in)),
    .sel(in),
    .srst(1'b0),
    .arst(rst),
    .q(filter_counter_out),
    .carry_out(filter_counter_carry));
    
wire [WIDTH-1:0] filter_counter_out2;
isub #(WIDTH) filter_counter2
(   .a(data),
    .b(filter_counter_out),
    .out({filter_counter2_carry,filter_counter_out2}));
    
d_flip_flop #(1) filter_ff
(   .clk(clk),
    .ena(~out & filter_counter_carry),
    .d(1'b1),
    .srst(out & filter_counter2_carry),
    .arst(rst),
    .q(out));

endmodule

module cap_edge(
input wire clk,
input wire ena,
input wire cap,
input wire srst,
input wire arst,
output wire rise,
output wire fall);

wire [1:0] dff_cap_out;
wire rise_d = dff_cap_out[0] & ~dff_cap_out[1];
wire fall_d = dff_cap_out[1] & ~dff_cap_out[0];

d_flip_flop #(4) dff_cap (.clk(clk),.ena(ena),.d({rise_d,fall_d,dff_cap_out[0],cap}),.srst(srst),.arst(arst),.q({rise,fall,dff_cap_out}));

endmodule

`endif
