`ifndef HWAG_SV
`define HWAG_SV

`include "flipflop.sv"
`include "count.sv"
`include "math.sv"
`include "capture.sv"
`include "comparsion.sv"


module hwag
(   input wire clk,
    input wire rst,
    input wire cap,
    input wire cam,
    output wire hwag_start,
    output wire ngap_point,
    output wire test_coil
);

wire rstb;
wire capb;
wire camb;

//assign ngap_point = ~gap_point;

d_flip_flop #(3) input_buffer (.clk(clk),.ena(1'b1),.d({rst,cap,cam}),.arst(1'b0),.q({rstb,capb,camb}));
    
input_filter #(12) cap_filter (.clk(clk),.rst(rstb),.data(12'd128),.in(capb),.out(capf));

input_filter #(12) cam_filter (.clk(clk),.rst(rstb),.data(12'd128),.in(camb),.out(camf));

input_edge cap_edge_gen (.clk(clk),.ena(1'b1),.cap(capf),.srst(1'b0),.arst(rstb),.rise(cap_rise),.fall(cap_fall));
    
input_edge cam_edge_gen (.clk(clk),.ena(1'b1),.cap(camf),.srst(1'b0),.arst(rstb),.rise(cam_rise),.fall(cam_fall));

wire cap_edge = cap_fall;
    
d_flip_flop #(1) pcnt_enable (.clk(clk),.ena(cap_edge & ~pcnt_start),.d(1'b1),.srst(pcnt_ovf & pcnt_start),.arst(rstb),.q(pcnt_start));
    
wire [23:0] pcnt_data;
counter #(24) pcnt (.clk(clk),.ena(pcnt_start),.sel(1'b0),.srst(cap_edge),.arst(rstb),.q(pcnt_data),.carry_out(pcnt_ovf));

wire [23:0] pcnt1_data;
d_flip_flop #(24) pcnt1 (.clk(clk),.ena(cap_edge),.d(pcnt_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt1_data));
    
wire [23:0] pcnt2_data;
d_flip_flop #(24) pcnt2 (.clk(clk),.ena(cap_edge),.d(pcnt1_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt2_data));
    
wire [23:0] pcnt3_data;
d_flip_flop #(24) pcnt3 (.clk(clk),.ena(cap_edge),.d(pcnt2_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt3_data));

wire [23:0] half_pcnt_data = {1'b0,pcnt_data[23:1]};
wire [23:0] half_pcnt2_data = {1'b0,pcnt2_data[23:1]};

wire [23:0] pcnt_min = 24'd256;
wire [23:0] pcnt_max = 24'h555555;

synchronous_comparator #(24) pcnt1_less_half_pcnt_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt1_data),.b(half_pcnt_data),.alb(pcnt1_less_half_pcnt));

synchronous_comparator #(24) pcnt1_less_half_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt1_data),.b(half_pcnt2_data),.alb(pcnt1_less_half_pcnt2));
synchronous_comparator #(24) pcnt3_less_half_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt3_data),.b(half_pcnt2_data),.alb(pcnt3_less_half_pcnt2));

synchronous_comparator #(24) pcnt_min_less_pcnt1_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt1_data),.alb(pcnt_min_less_pcnt1));
synchronous_comparator #(24) pcnt_min_less_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt2_data),.alb(pcnt_min_less_pcnt2));
synchronous_comparator #(24) pcnt_min_less_pcnt3_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt3_data),.alb(pcnt_min_less_pcnt3));

synchronous_comparator #(24) pcnt_max_less_pcnt1_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_max),.b(pcnt1_data),.alb(pcnt_max_less_pcnt1));
synchronous_comparator #(24) pcnt_max_less_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_max),.b(pcnt2_data),.alb(pcnt_max_less_pcnt2));
synchronous_comparator #(24) pcnt3_less_pcnt_max_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt3_data),.b(pcnt_max),.alb(pcnt3_less_pcnt_max));

wire pcnt_greater_min = pcnt_min_less_pcnt1 &   pcnt_min_less_pcnt2 &  pcnt_min_less_pcnt3;
wire pcnt_less_min =   ~pcnt_min_less_pcnt1 |  ~pcnt_min_less_pcnt2 | ~pcnt_min_less_pcnt3;

wire pcnt_nom = pcnt_greater_min & pcnt3_less_pcnt_max;
wire pcnt_not_nom = pcnt_less_min | (pcnt_max_less_pcnt1 & pcnt_max_less_pcnt2);

wire gap_found = pcnt1_less_half_pcnt2 & pcnt3_less_half_pcnt2;

//========================================================================

wire hwag_start_ena_d = (pcnt_nom & gap_found & pcnt_start) & ~hwag_start;
wire hwag_start_srst_d = (pcnt_not_nom | ~pcnt_start) & hwag_start;

//========================================================================

d_flip_flop #(2) hwag_start_ena_srst (.clk(clk),.ena(1'b1),.d({hwag_start_ena_d,hwag_start_srst_d}),.arst(rstb),.q({hwag_start_ena,hwag_start_srst}));

d_flip_flop #(1) hwag_start_trigger (.clk(clk),.ena(hwag_start_ena),.d(1'b1),.srst(hwag_start_srst),.arst(rstb),.q(hwag_start));
 
endmodule

`endif
