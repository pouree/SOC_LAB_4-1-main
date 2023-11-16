// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`define MPRJ_IO_PADS_1 19	/* number of user GPIO pads on user1 side */
`define MPRJ_IO_PADS_2 19	/* number of user GPIO pads on user2 side */
`define MPRJ_IO_PADS (`MPRJ_IO_PADS_1 + `MPRJ_IO_PADS_2)

`default_nettype wire
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;
    assign clk = wb_clk_i;
    assign rst = wb_rst_i;


    //wire [`MPRJ_IO_PADS-1:0] io_in;
    //wire [`MPRJ_IO_PADS-1:0] io_out;
    //wire [`MPRJ_IO_PADS-1:0] io_oeb;

    // input to ram
    wire ram_en;
    wire [3:0]  ram_we;
    wire [31:0] ram_adr;
    wire [31:0] ram_data;

    bram user_bram (
        .CLK(clk),
        .WE0(ram_we),
        .EN0(ram_en),
        .Di0(wbs_dat_i),
        .Do0(wbs_dat_o),
        .A0(wbs_adr_i)
    );

    // write data to on_chip ram only when request_sig assert
    wire request_sig;
    assign request_sig = wbs_cyc_i & wbs_stb_i;
    assign ram_adr = (request_sig==1'b1)? wbs_adr_i : 32'b0;
    assign ram_data = (request_sig==1'b1)? wbs_dat_i : 32'b0;
    assign ram_we = (request_sig==1'b1)?  ({4{wbs_we_i}} & wbs_sel_i) : 4'b0;
    assign ram_en = (request_sig==1'b1)? (wbs_cyc_i & wbs_sel_i): 1'b0;

    reg wbs_ack_o;
    reg [3:0] delay_cnt;   // delay = 10 (DELAYS) < 2^4
    always @ (posedge clk) begin 
        if (rst) begin
            wbs_ack_o <= 0;
            delay_cnt <= 0;
        end
        else if (request_sig == 1'b1) begin 
            if (delay_cnt == DELAYS) begin
                wbs_ack_o <= 1'b1;
                delay_cnt <= 0;            
            end
            else begin  
                wbs_ack_o <= 1'b0;
                delay_cnt <= delay_cnt + 1 ;
            end
        end
        else 
             wbs_ack_o <= 1'b0;    
    end

endmodule



`default_nettype wire
