/// Copyright by Syntacore LLC © 2016, 2017. See LICENSE for details
/// @file       <max1000.sv>
/// @brief      Top-level entity with SCR1 for MAX1000 board
///

`include "scr1_arch_types.svh"
`include "scr1_arch_description.svh"
`include "scr1_memif.svh"
`include "scr1_ipic.svh"

parameter bit [31:0] FPGA_MAX1000_BUILD_ID = `SCR1_ARCH_BUILD_ID;

module max1000 (

    input                           CLK12M,

    output               [11:0]     DRAM_ADDR,
    output                [1:0]     DRAM_BA,
    output                          DRAM_CAS_N,
    output                          DRAM_CKE,
    output                          DRAM_CLK,
    output                          DRAM_CS_N,
    inout                [15:0]     DRAM_DQ,
    output                          DRAM_LDQM,  // DQM0
    output                          DRAM_RAS_N,
    output                          DRAM_UDQM,  // DQM1
    output                          DRAM_WE_N,

    output                          UART_TXD,   // -> UART
    input                           UART_RXD,   // <- UART

    output                [7:0]     LED,
    input                 [0:0]     RESET
);




//=======================================================
//  Signals / Variables declarations
//=======================================================
logic                               pll_locked;
logic                               clk_riscv;
logic                               clk_sdram;
logic                               rst_in;
logic [2:1]                         rst_in_d;
logic                               rst_n;
logic                               pwrup_rst_n;


// --- SCR1 ---------------------------------------------
logic [3:0]                         ahb_imem_hprot;
logic [2:0]                         ahb_imem_hburst;
logic [2:0]                         ahb_imem_hsize;
logic [1:0]                         ahb_imem_htrans;
logic [SCR1_AHB_WIDTH-1:0]          ahb_imem_haddr;
logic                               ahb_imem_hready;
logic [SCR1_AHB_WIDTH-1:0]          ahb_imem_hrdata;
logic                               ahb_imem_hresp;
//
logic [3:0]                         ahb_dmem_hprot;
logic [2:0]                         ahb_dmem_hburst;
logic [2:0]                         ahb_dmem_hsize;
logic [1:0]                         ahb_dmem_htrans;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_haddr;
logic                               ahb_dmem_hwrite;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_hwdata;
logic                               ahb_dmem_hready;
logic [SCR1_AHB_WIDTH-1:0]          ahb_dmem_hrdata;
logic                               ahb_dmem_hresp;
//
logic                               riscv0_irq;
`ifdef SCR1_DBGC_EN
logic                               riscv_jtag_tdo;
logic                               riscv_jtag_tdo_en;
`endif//SCR1_DBGC_EN

// --- AHB-Avalon Bus -----------------------------------
logic                               avl_imem_write;
logic                               avl_imem_read;
logic                               avl_imem_waitrequest;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_address;
logic [3:0]                         avl_imem_byteenable;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_writedata;
logic                               avl_imem_readdatavalid;
logic [SCR1_AHB_WIDTH-1:0]          avl_imem_readdata;
logic [1:0]                         avl_imem_response;
//
logic                               avl_dmem_write;
logic                               avl_dmem_read;
logic                               avl_dmem_waitrequest;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_address;
logic [3:0]                         avl_dmem_byteenable;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_writedata;
logic                               avl_dmem_readdatavalid;
logic [SCR1_AHB_WIDTH-1:0]          avl_dmem_readdata;
logic [1:0]                         avl_dmem_response;


assign pwrup_rst_n = pll_locked;
assign rst_in = RESET[0] & pwrup_rst_n;


pll i_pll (
    .inclk0         (CLK12M         ),
    .c0             (clk_riscv      ),
    .c1             (clk_sdram      ),
    .c2             (DRAM_CLK       ),
    .locked         (pll_locked     )
);

always_ff @(posedge clk_riscv, negedge rst_in)
begin
    if (~rst_in)    rst_in_d <= '0;
    else            rst_in_d <= {rst_in_d[1], rst_in};

end

assign rst_n = rst_in_d[2];


scr1_top_ahb i_scr1 (
        // Common
        .pwrup_rst_n                (pwrup_rst_n            ),
        .rst_n                      (rst_n                  ),
        .cpu_rst_n                  (1'b1                   ),
        .test_mode                  (1'b0                   ),
        .test_rst_n                 (1'b1                   ),
        .clk                        (clk_riscv              ),
        .rtc_clk                    (1'b0                   ),
`ifdef SCR1_DBGC_EN
        .ndm_rst_n_out              (                       ),
`endif // SCR1_DBGC_EN

        // Fuses
        .fuse_mhartid               ('0                     ),

        // IRQ
        `ifdef SCR1_IPIC_EN
        .irq_lines                  ({'0,riscv0_irq}        ),
        `else
        .ext_irq                    (riscv0_irq             ),
        `endif//SCR1_IPIC_EN
        .soft_irq                   ('0                     ),

        // Instruction Memory Interface
        .imem_hprot                 (ahb_imem_hprot         ),
        .imem_hburst                (ahb_imem_hburst        ),
        .imem_hsize                 (ahb_imem_hsize         ),
        .imem_htrans                (ahb_imem_htrans        ),
        .imem_hmastlock             (                       ),
        .imem_haddr                 (ahb_imem_haddr         ),
        .imem_hready                (ahb_imem_hready        ),
        .imem_hrdata                (ahb_imem_hrdata        ),
        .imem_hresp                 (ahb_imem_hresp         ),
        // Data Memory Interface
        .dmem_hprot                 (ahb_dmem_hprot         ),
        .dmem_hburst                (ahb_dmem_hburst        ),
        .dmem_hsize                 (ahb_dmem_hsize         ),
        .dmem_htrans                (ahb_dmem_htrans        ),
        .dmem_hmastlock             (                       ),
        .dmem_haddr                 (ahb_dmem_haddr         ),
        .dmem_hwrite                (ahb_dmem_hwrite        ),
        .dmem_hwdata                (ahb_dmem_hwdata        ),
        .dmem_hready                (ahb_dmem_hready        ),
        .dmem_hrdata                (ahb_dmem_hrdata        ),
        .dmem_hresp                 (ahb_dmem_hresp         )
);

//
// AHB IMEM Bridge
//

ahb_avalon_bridge i_ahb_imem (
        // avalon master side
        .clk                        (clk_riscv              ),
        .reset_n                    (rst_n                  ),
        .write                      (avl_imem_write         ),
        .read                       (avl_imem_read          ),
        .waitrequest                (avl_imem_waitrequest   ),
        .address                    (avl_imem_address       ),
        .byteenable                 (avl_imem_byteenable    ),
        .writedata                  (avl_imem_writedata     ),
        .readdatavalid              (avl_imem_readdatavalid ),
        .readdata                   (avl_imem_readdata      ),
        .response                   (avl_imem_response      ),
        // ahb slave side
        .HRDATA                     (ahb_imem_hrdata        ),
        .HRESP                      (ahb_imem_hresp         ),
        .HSIZE                      (ahb_imem_hsize         ),
        .HTRANS                     (ahb_imem_htrans        ),
        .HPROT                      (ahb_imem_hprot         ),
        .HADDR                      (ahb_imem_haddr         ),
        .HWDATA                     ('0                     ),
        .HWRITE                     ('0                     ),
        .HREADY                     (ahb_imem_hready        )
);

//
// AHB DMEM Bridge
//

ahb_avalon_bridge i_ahb_dmem (
        // avalon master side
        .clk                        (clk_riscv              ),
        .reset_n                    (rst_n                  ),
        .write                      (avl_dmem_write         ),
        .read                       (avl_dmem_read          ),
        .waitrequest                (avl_dmem_waitrequest   ),
        .address                    (avl_dmem_address       ),
        .byteenable                 (avl_dmem_byteenable    ),
        .writedata                  (avl_dmem_writedata     ),
        .readdatavalid              (avl_dmem_readdatavalid ),
        .readdata                   (avl_dmem_readdata      ),
        .response                   (avl_dmem_response      ),
        // ahb slave side
        .HRDATA                     (ahb_dmem_hrdata        ),
        .HRESP                      (ahb_dmem_hresp         ),
        .HSIZE                      (ahb_dmem_hsize         ),
        .HTRANS                     (ahb_dmem_htrans        ),
        .HPROT                      (ahb_dmem_hprot         ),
        .HADDR                      (ahb_dmem_haddr         ),
        .HWDATA                     (ahb_dmem_hwdata        ),
        .HWRITE                     (ahb_dmem_hwrite        ),
        .HREADY                     (ahb_dmem_hready        )
);

max1000_qsys i_max1000_qsys (
        .clk_clk                    (clk_riscv              ),
        .clk_sdram_in_clk_clk       (clk_sdram              ),
        .reset_reset_n              (rst_n                  ),


        .pio_led_export             (LED                    ),
        .pio_sw_export              (                       ),
        .bld_id_export              (FPGA_MAX1000_BUILD_ID  ),

        .sdram_addr                 (DRAM_ADDR              ),
        .sdram_ba                   (DRAM_BA                ),
        .sdram_cas_n                (DRAM_CAS_N             ),
        .sdram_cke                  (DRAM_CKE               ),
        .sdram_cs_n                 (DRAM_CS_N              ),
        .sdram_dq                   (DRAM_DQ                ),
        .sdram_dqm                  ({DRAM_UDQM,DRAM_LDQM}  ),
        .sdram_ras_n                (DRAM_RAS_N             ),
        .sdram_we_n                 (DRAM_WE_N              ),

        .avl_imem_write             (avl_imem_write         ),
        .avl_imem_read              (avl_imem_read          ),
        .avl_imem_waitrequest       (avl_imem_waitrequest   ),
        .avl_imem_debugaccess       (1'd0                   ),
        .avl_imem_address           (avl_imem_address       ),
        .avl_imem_burstcount        (1'd1                   ),
        .avl_imem_byteenable        (avl_imem_byteenable    ),
        .avl_imem_writedata         (avl_imem_writedata     ),
        .avl_imem_readdatavalid     (avl_imem_readdatavalid ),
        .avl_imem_readdata          (avl_imem_readdata      ),
        .avl_imem_response          (avl_imem_response      ),

        .avl_dmem_write             (avl_dmem_write         ),
        .avl_dmem_read              (avl_dmem_read          ),
        .avl_dmem_waitrequest       (avl_dmem_waitrequest   ),
        .avl_dmem_debugaccess       (1'd0                   ),
        .avl_dmem_address           (avl_dmem_address       ),
        .avl_dmem_burstcount        (1'd1                   ),
        .avl_dmem_byteenable        (avl_dmem_byteenable    ),
        .avl_dmem_writedata         (avl_dmem_writedata     ),
        .avl_dmem_readdatavalid     (avl_dmem_readdatavalid ),
        .avl_dmem_readdata          (avl_dmem_readdata      ),
        .avl_dmem_response          (avl_dmem_response      ),

        .uart_0_rxd                 (UART_RXD               ),
        .uart_0_txd                 (UART_TXD               ),
        .uart_0_irq_irq             (riscv0_irq             )
);

endmodule: max1000
