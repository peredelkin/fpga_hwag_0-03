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
    output wire gap_point,
    output wire test_coil
);

wire rstb;
wire capb;
wire camb;

d_flip_flop #(3) input_buffer (.clk(clk),.ena(1'b1),.d({rst,cap,cam}),.arst(1'b0),.q({rstb,capb,camb}));
    
input_filter #(12) cap_filter (.clk(clk),.rst(rstb),.data(12'd1024),.in(capb),.out(capf));

input_filter #(12) cam_filter (.clk(clk),.rst(rstb),.data(12'd1024),.in(camb),.out(camf));

cap_edge cap_edge_gen (.clk(clk),.ena(1'b1),.cap(capf),.srst(1'b0),.arst(rstb),.rise(cap_rise),.fall(cap_fall));
    
cap_edge cam_edge_gen (.clk(clk),.ena(1'b1),.cap(camf),.srst(1'b0),.arst(rstb),.rise(cam_rise),.fall(cam_fall));

wire main_edge = cap_fall;
    
d_flip_flop #(1) pcnt_enable (.clk(clk),.ena(main_edge & ~pcnt_start),.d(1'b1),.srst(pcnt_ovf & pcnt_start),.arst(rstb),.q(pcnt_start));
    
wire [23:0] pcnt_data;
counter #(24) pcnt (.clk(clk),.ena(pcnt_start),.sel(1'b0),.srst(main_edge),.arst(rstb),.q(pcnt_data),.carry_out(pcnt_ovf));

wire pcnt123_ena = main_edge & ~gap_point;

wire [23:0] pcnt1_data;
d_flip_flop #(24) pcnt1 (.clk(clk),.ena(pcnt123_ena),.d(pcnt_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt1_data));
    
wire [23:0] pcnt2_data;
d_flip_flop #(24) pcnt2 (.clk(clk),.ena(pcnt123_ena),.d(pcnt1_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt2_data));
    
wire [23:0] pcnt3_data;
d_flip_flop #(24) pcnt3 (.clk(clk),.ena(pcnt123_ena),.d(pcnt2_data),.srst(~pcnt_start),.arst(rstb),.q(pcnt3_data));

comparator #(24) pcnt1_less_half_pcnt_comp (.a(pcnt1_data),.b({1'b0,pcnt_data[23:1]}),.alb(pcnt1_less_half_pcnt));

comparator #(24) pcnt1_less_half_pcnt2_comp (.a(pcnt1_data),.b({1'b0,pcnt2_data[23:1]}),.alb(pcnt1_less_half_pcnt2));

comparator #(24) pcnt3_less_half_pcnt2_comp (.a(pcnt3_data),.b({1'b0,pcnt2_data[23:1]}),.alb(pcnt3_less_half_pcnt2));

d_flip_flop #(3) comparator_buffer (.clk(clk),.ena(1'b1),   .d({pcnt1_less_half_pcnt,  pcnt1_less_half_pcnt2,  pcnt3_less_half_pcnt2  }),.srst(1'b0),.arst(rstb),
                                                            .q({pcnt1_less_half_pcnt_b,pcnt1_less_half_pcnt2_b,pcnt3_less_half_pcnt2_b}));
                                                            
//~~~~~~~~~~~~~~~~~~~~~~~~~~~

wire gap_found = pcnt1_less_half_pcnt2_b & pcnt3_less_half_pcnt2_b;

wire gap_drn_normal_tooth = hwag_start & main_edge & ~gap_point & pcnt1_less_half_pcnt_b;

wire hwag_ena = ~hwag_start & pcnt_start & gap_found & main_edge;

wire hwag_srst = hwag_start & (~pcnt_start | gap_drn_normal_tooth); //(!)

d_flip_flop #(1) hwag_enable (.clk(clk),.ena(hwag_ena),.d(1'b1),.srst(hwag_srst),.arst(rstb),.q(hwag_start));

wire [5:0] tcnt_load_data;
mult2to1 #(6) tcnt_load_sel (.sel(~hwag_start),.a(6'd57),.b(6'd54),.out(tcnt_load_data));

wire tcnt_count = main_edge & hwag_start;

wire tcnt_ena = tcnt_count & ~tcnt_ovf;

wire tcnt_sload = (tcnt_count & tcnt_ovf) | ~hwag_start;

wire [5:0] tcnt_data;
counter #(6) tcnt (.clk(clk),.ena(tcnt_ena),.sel(1'b1),.sload(tcnt_sload),.d_load(tcnt_load_data),.srst(1'b0),.arst(rstb),.q(tcnt_data),.carry_out(tcnt_ovf));

d_flip_flop #(1) tcnt_ovf_buffer (.clk(clk),.ena(1'b1),.d(tcnt_ovf),.srst(~hwag_start),.arst(rstb),.q(pregap_point));

d_flip_flop #(1) gap_point_gen (.clk(clk),.ena(main_edge),.d(pregap_point),.srst(~hwag_start),.arst(rstb),.q(gap_point));

wire [17:0] scnt_data_load = pcnt1_data[23:6];

wire [17:0] scnt_out;
counter #(18) scnt (.clk(clk),.ena(~tckc_ovf),.sel(1'b1),.sload(hwag_start & (main_edge | scnt_ovf)),.d_load(scnt_data_load),.srst(1'b0),.arst(rstb),.q(scnt_out),.carry_out(scnt_ovf));

wire [7:0] tckc_data_load;
mult2to1 #(8) tckc_data_sel (.sel(pregap_point),.a(8'd64),.b(8'd192),.out(tckc_data_load));

wire tckc_count = ~tckc_ovf & scnt_ovf;
wire [7:0] tckc_out;
counter #(8) tckc (.clk(clk),.ena(tckc_count),.sel(1'b1),.sload(hwag_start & main_edge),.d_load(tckc_data_load),.srst(1'b0),.arst(rstb),.q(tckc_out),.carry_out(tckc_ovf));

wire [11:0] acnt_data_load;
mult2to1 #(12) acnt_data_sel (.sel(acnt_ovf),.a({tcnt_data,6'd0}),.b(12'd3839),.out(acnt_data_load));

wire [11:0] acnt_out;

wire acnt_ena = hwag_start & ~acnt_ovf & tckc_count;

wire acnt_sload = (hwag_start & acnt_ovf & tckc_count) | main_edge;

counter #(12) acnt (.clk(clk),.ena(acnt_ena),.sel(1'b1),.sload(acnt_sload),.d_load(acnt_data_load),.srst(1'b0),.arst(rstb),.q(acnt_out),.carry_out(acnt_ovf));

set_reset_comparator #(12) test_ignition (.set_data(12'd2122),.reset_data(12'd1920),.data_compare(acnt_out),.clk(clk),.ena(1'b1),.input_rst(~hwag_start),.output_rst(~hwag_start),.out(test_coil));
    
endmodule

`endif
