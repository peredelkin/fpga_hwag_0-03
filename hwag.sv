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
    output wire coil_0,
	 output wire coil_1
);

wire rstb;
wire capb;
wire camb;

assign ngap_point = ~gap_point;

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
d_flip_flop #(24) pcnt1 (.clk(clk),.ena(cap_edge & ~gap_point),.d(pcnt_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt1_data));
    
wire [23:0] pcnt2_data;
d_flip_flop #(24) pcnt2 (.clk(clk),.ena(cap_edge & ~gap_point),.d(pcnt1_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt2_data));
    
wire [23:0] pcnt3_data;
d_flip_flop #(24) pcnt3 (.clk(clk),.ena(cap_edge & ~gap_point),.d(pcnt2_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt3_data));

wire [23:0] half_pcnt_data = {1'b0,pcnt_data[23:1]};
wire [23:0] half_pcnt2_data = {1'b0,pcnt2_data[23:1]};

wire [23:0] pcnt_min = 24'd256;
wire [23:0] pcnt_max = 24'h555555;

synchronous_comparator #(24) pcnt1_less_half_pcnt_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt1_data),.b(half_pcnt_data),.sync(1'b0),.alb(pcnt1_less_half_pcnt));

synchronous_comparator #(24) pcnt1_less_half_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt1_data),.b(half_pcnt2_data),.sync(1'b0),.alb(pcnt1_less_half_pcnt2));
synchronous_comparator #(24) pcnt3_less_half_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt3_data),.b(half_pcnt2_data),.sync(1'b0),.alb(pcnt3_less_half_pcnt2));

synchronous_comparator #(24) pcnt_min_less_pcnt1_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt1_data),.sync(1'b0),.alb(pcnt_min_less_pcnt1));
synchronous_comparator #(24) pcnt_min_less_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt2_data),.sync(1'b0),.alb(pcnt_min_less_pcnt2));
synchronous_comparator #(24) pcnt_min_less_pcnt3_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_min),.b(pcnt3_data),.sync(1'b0),.alb(pcnt_min_less_pcnt3));

synchronous_comparator #(24) pcnt_max_less_pcnt1_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_max),.b(pcnt1_data),.sync(1'b0),.alb(pcnt_max_less_pcnt1));
synchronous_comparator #(24) pcnt_max_less_pcnt2_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt_max),.b(pcnt2_data),.sync(1'b0),.alb(pcnt_max_less_pcnt2));
synchronous_comparator #(24) pcnt3_less_pcnt_max_comp (.clk(clk),.ena(pcnt_start),.srst(~pcnt_start),.arst(rstb),.a(pcnt3_data),.b(pcnt_max),.sync(1'b0),.alb(pcnt3_less_pcnt_max));

d_flip_flop #(1) pcnt_greater_min_trigger (.clk(clk),.ena(1'b1),.d(pcnt_min_less_pcnt1 &   pcnt_min_less_pcnt2 &  pcnt_min_less_pcnt3),.arst(rstb),.q(pcnt_greater_min));
d_flip_flop #(1) pcnt_less_min_trigger (.clk(clk),.ena(1'b1),.d(~pcnt_min_less_pcnt1 |  ~pcnt_min_less_pcnt2 | ~pcnt_min_less_pcnt3),.arst(rstb),.q(pcnt_less_min));

d_flip_flop #(1) pcnt_nom_trigger (.clk(clk),.ena(1'b1),.d(pcnt_greater_min & pcnt3_less_pcnt_max),.arst(rstb),.q(pcnt_nom));
d_flip_flop #(1) pcnt_not_nom_trigger (.clk(clk),.ena(1'b1),.d(pcnt_less_min | (pcnt_max_less_pcnt1 & pcnt_max_less_pcnt2)),.arst(rstb),.q(pcnt_not_nom));

wire gap_run = pcnt1_less_half_pcnt;
d_flip_flop #(1) gap_found_trigger (.clk(clk),.ena(1'b1),.d(pcnt1_less_half_pcnt2 & pcnt3_less_half_pcnt2),.arst(rstb),.q(gap_found));

//========================================================================

wire hwag_start_ena_d = (pcnt_nom & gap_found & pcnt_start) & ~hwag_start;
wire hwag_start_srst_d = (gap_drn_normal_tooth | gap_lost | pcnt_not_nom | ~pcnt_start) & hwag_start;

//========================================================================

d_flip_flop #(2) hwag_start_ena_srst (.clk(clk),.ena(1'b1),.d({hwag_start_ena_d,hwag_start_srst_d}),.arst(rstb),.q({hwag_start_ena,hwag_start_srst}));

d_flip_flop #(1) hwag_start_trigger (.clk(clk),.ena(hwag_start_ena),.d(1'b1),.srst(hwag_start_srst),.arst(rstb),.q(hwag_start));


wire tooth_counter_ena = cap_edge & ~tooth_counter_ovf;

wire tooth_counter_sload = (cap_edge & tooth_counter_ovf) | ~hwag_start;

wire [7:0] tooth_counter_d_load;

mult2to1 #(8) tooth_counter_d_load_sel (.sel(~hwag_start),.a(8'd57),.b(8'd55),.out(tooth_counter_d_load));

wire [7:0] tooth_counter_load_data;

d_flip_flop #(8) tooth_counter_d_load_buffer (.clk(clk),.ena(1'b1),.d(tooth_counter_d_load),.arst(rstb),.q(tooth_counter_load_data));

wire [7:0] tooth_counter_data;

counter #(8) tooth_counter (.clk(clk),.ena(tooth_counter_ena),.sel(1'b1),.sload(tooth_counter_sload),.d_load(tooth_counter_load_data),.srst(1'b0),.arst(rstb),.q(tooth_counter_data),.carry_out(tooth_counter_ovf));

d_flip_flop #(1) gap_point_trigger (.clk(clk),.ena(cap_edge),.d(tooth_counter_ovf),.srst(~hwag_start),.arst(rstb),.q(gap_point));

d_flip_flop #(1) gap_lost_trigger (.clk(clk),.ena(cap_edge),.d(gap_point & ~gap_run),.srst(~hwag_start),.arst(rstb),.q(gap_lost));

d_flip_flop #(1) gap_drn_normal_tooth_trigger (.clk(clk),.ena(cap_edge),.d(~gap_point & gap_run),.srst(~hwag_start),.arst(rstb),.q(gap_drn_normal_tooth));


wire step_counter_ena = ~tick_counter_ovf & ~step_counter_ovf;

wire step_counter_sload = cap_edge | (~tick_counter_ovf & step_counter_ovf);

wire [17:0] step_counter_d_load = pcnt1_data[23:6];

wire [17:0] step_counter_load_data;

d_flip_flop #(18) step_counter_load_data_buffer (.clk(clk),.ena(1'b1),.d(step_counter_d_load),.arst(rstb),.q(step_counter_load_data));

wire step_counter_srst = ~hwag_start;

wire [17:0] step_counter_data;

counter #(18) step_counter (.clk(clk),.ena(step_counter_ena),.sel(1'b1),.sload(step_counter_sload),.d_load(step_counter_load_data),.srst(step_counter_srst),.arst(rstb),.q(step_counter_data),.carry_out(step_counter_ovf));


wire tick_counter_ena = ~tick_counter_ovf & step_counter_ovf;

wire tick_counter_sload = cap_edge;

wire [15:0] tick_counter_d_load;

mult2to1 #(16) tick_counter_d_load_sel (.sel(tooth_counter_ovf),.a(16'd64),.b(16'd192),.out(tick_counter_d_load));

wire [15:0] tick_counter_load_data;

d_flip_flop #(16) tick_counter_load_data_buffer (.clk(clk),.ena(1'b1),.d(tick_counter_d_load),.arst(rstb),.q(tick_counter_load_data));

wire tick_counter_srst = ~hwag_start;

wire [15:0] tick_counter_data;

counter #(16) tick_counter (.clk(clk),.ena(tick_counter_ena),.sel(1'b1),.sload(tick_counter_sload),.d_load(tick_counter_load_data),.srst(tick_counter_srst),.arst(rstb),.q(tick_counter_data),.carry_out(tick_counter_ovf));


wire main_angle_counter_ena = tick_counter_ena & ~main_angle_counter_ovf;

wire main_angle_counter_sload = cap_edge | (tick_counter_ena & main_angle_counter_ovf);

wire [15:0] main_angle_counter_d_load_from_tooth_counter = {tooth_counter_data,6'd0};

wire [15:0] main_angle_counter_d_load;

mult2to1 #(16) main_angle_counter_d_load_sel (.sel(main_angle_counter_ovf),.a(main_angle_counter_d_load_from_tooth_counter),.b(16'd3839),.out(main_angle_counter_d_load));

wire [15:0] main_angle_counter_load_data;

d_flip_flop #(16) main_angle_counter_load_data_buffer (.clk(clk),.ena(1'b1),.d(main_angle_counter_d_load),.arst(rstb),.q(main_angle_counter_load_data));

wire main_angle_counter_srst = 1'b0;

wire [15:0] main_angle_counter_data;

counter #(16) main_angle_counter (.clk(clk),.ena(main_angle_counter_ena),.sel(1'b1),.sload(main_angle_counter_sload),.d_load(main_angle_counter_load_data),.srst(main_angle_counter_srst),.arst(rstb),.q(main_angle_counter_data),.carry_out(main_angle_counter_ovf));


wire second_angle_counter_ena = main_angle_counter_not_equal_second & ~second_angle_counter_ovf;

wire second_angle_counter_sload = main_angle_counter_not_equal_second & second_angle_counter_ovf;

wire [15:0] second_angle_counter_d_load = 16'd3839;

wire second_angle_counter_srtst = 1'b0;

wire [15:0] second_angle_counter_data;

counter #(16) second_angle_counter (.clk(clk),.ena(second_angle_counter_ena),.sel(1'b1),.sload(second_angle_counter_sload),.d_load(second_angle_counter_d_load),.srst(second_angle_counter_srtst),.arst(rstb),.q(second_angle_counter_data),.carry_out(second_angle_counter_ovf));


synchronous_comparator #(16) main_second_angle_counter_comp (.clk(clk),.ena(1'b1),.srst(1'b0),.arst(rstb),.a(main_angle_counter_data),.b(second_angle_counter_data),.sync(1'b0),.aneb(main_angle_counter_not_equal_second));


d_flip_flop #(1) main_second_angle_counter_comp_trigger (.clk(clk),.ena(1'b1),.d(main_angle_counter_not_equal_second),.srst(1'b0),.arst(rstb),.q(slave_counter_ena));


wire slave_angle_counter_0_ena = slave_counter_ena & ~slave_angle_counter_0_ovf;

wire slave_angle_counter_0_sload = ~hwag_start | (slave_counter_ena & slave_angle_counter_0_ovf);

wire [15:0] slave_angle_counter_0_d_load;

mult2to1 #(16) slave_angle_counter_0_d_load_sel (.sel(~hwag_start),.a(16'd3839),.b(16'd3839-16'd2624),.out(slave_angle_counter_0_d_load));

wire slave_angle_counter_0_srts = 1'b0;

wire [15:0] slave_angle_counter_0_load_data;

d_flip_flop #(16) slave_angle_counter_0_load_data_buffer (.clk(clk),.ena(1'b1),.d(slave_angle_counter_0_d_load),.arst(rstb),.q(slave_angle_counter_0_load_data));

wire [15:0] slave_angle_counter_0_data;

counter #(16) slave_angle_counter_0 (.clk(clk),.ena(slave_angle_counter_0_ena),.sel(1'b1),.sload(slave_angle_counter_0_sload),.d_load(slave_angle_counter_0_load_data),.srst(slave_angle_counter_0_srts),.arst(rstb),.q(slave_angle_counter_0_data),.carry_out(slave_angle_counter_0_ovf));


wire slave_angle_counter_1_ena = slave_counter_ena & ~slave_angle_counter_1_ovf;

wire slave_angle_counter_1_sload = ~hwag_start | (slave_counter_ena & slave_angle_counter_1_ovf);

wire [15:0] slave_angle_counter_1_d_load;

mult2to1 #(16) slave_angle_counter_1_d_load_sel (.sel(~hwag_start),.a(16'd3839),.b(16'd3839-16'd704),.out(slave_angle_counter_1_d_load));

wire slave_angle_counter_1_srts = 1'b0;

wire [15:0] slave_angle_counter_1_load_data;

d_flip_flop #(16) slave_angle_counter_1_load_data_buffer (.clk(clk),.ena(1'b1),.d(slave_angle_counter_1_d_load),.arst(rstb),.q(slave_angle_counter_1_load_data));

wire [15:0] slave_angle_counter_1_data;

counter #(16) slave_angle_counter_1 (.clk(clk),.ena(slave_angle_counter_1_ena),.sel(1'b1),.sload(slave_angle_counter_1_sload),.d_load(slave_angle_counter_1_load_data),.srst(slave_angle_counter_1_srts),.arst(rstb),.q(slave_angle_counter_1_data),.carry_out(slave_angle_counter_1_ovf));


synchronous_comparator #(16) coil_set_0_comp (.clk(clk),.ena(1'b1),.srst(1'b0),.arst(rstb),.a(slave_angle_counter_0_data),.b(16'd256),.sync(1'b1),.aeb(coil_set_0));
synchronous_comparator #(16) coil_reset_0_comp (.clk(clk),.ena(1'b1),.srst(1'b0),.arst(rstb),.a(slave_angle_counter_0_data),.b(16'd128),.sync(1'b1),.aeb(coil_reset_0));

synchronous_comparator #(16) coil_set_1_comp (.clk(clk),.ena(1'b1),.srst(1'b0),.arst(rstb),.a(slave_angle_counter_1_data),.b(16'd256),.sync(1'b1),.aeb(coil_set_1));
synchronous_comparator #(16) coil_reset_1_comp (.clk(clk),.ena(1'b1),.srst(1'b0),.arst(rstb),.a(slave_angle_counter_1_data),.b(16'd128),.sync(1'b1),.aeb(coil_reset_1));


d_flip_flop #(1) coil_0_trigger (.clk(clk),.ena(coil_set_0),.d(1'b1),.srst(coil_reset_0 | ~hwag_start),.arst(rstb),.q(coil_0));
d_flip_flop #(1) coil_1_trigger (.clk(clk),.ena(coil_set_1),.d(1'b1),.srst(coil_reset_1 | ~hwag_start),.arst(rstb),.q(coil_1));


endmodule

`endif
