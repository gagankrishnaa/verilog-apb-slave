`timescale 1ns/1ps
class apb_transaction;
  rand bit [1:0] PADDR;
  rand bit [7:0] PWDATA;
  rand bit PWRITE;
  bit [7:0] PRDATA;
  bit pass;
endclass

class apb_sequencer;
  mailbox #(apb_transaction) mbx;
  task run();
    repeat (10) begin
      apb_transaction txn;
      txn = new();
      txn.randomize();
      mbx.put(txn);
    end
  endtask
endclass

class apb_driver;
  mailbox #(apb_transaction) mbx;
  task run();
    apb_transaction txn;
    forever begin
      mbx.get(txn);
      @(posedge PCLK);
      PSEL = 1;
      PWRITE = txn.PWRITE;
      PADDR = txn.PADDR;
      
      if (PWRITE) begin
        PWDATA = txn.PWDATA;
        @(posedge PCLK);
        PENABLE = 1;
        @(posedge PCLK);
        @(posedge PCLK);
      end else begin
        @(posedge PCLK);
        PENABLE = 1;
        @(posedge PCLK);
        @(posedge PCLK);
        #1;
      end
      PSEL = 0;
      PENABLE = 0;
      @(posedge PCLK);
    end
  endtask
endclass


class apb_monitor;
  mailbox #(apb_transaction) mbx;
  task run();
    apb_transaction txn;
    forever begin
      @(posedge PCLK);
      #1;
      if (PREADY && PENABLE) begin
        if (PWRITE) begin
          txn = new();
          txn.PWRITE = PWRITE;
          txn.PWDATA = PWDATA;
          txn.PADDR = PADDR;
          mbx.put(txn);
        end else begin
          txn = new();
          txn.PWRITE = PWRITE;
          txn.PRDATA = PRDATA;
          txn.PADDR = PADDR;
          mbx.put(txn);
        end
      end
    end
  endtask
endclass

class apb_scoreboard;
  mailbox #(apb_transaction) mbx;
  bit [7:0] ref_mem [0:3];
  task run();
    apb_transaction txn;
    forever begin
      mbx.get(txn);
      if (txn.PWRITE) begin
        ref_mem[txn.PADDR] = txn.PWDATA;
        $display ("WROTE %h to addr %0d",txn.PWDATA, txn.PADDR);
      end else begin
        if ( txn.PRDATA == ref_mem[txn.PADDR] )
          $display ("PASS: expected %h, recieved %h",ref_mem[txn.PADDR], txn.PRDATA);
        else
          $display ("FAIL: expected %h, recieved %h",ref_mem[txn.PADDR], txn.PRDATA);
      end
    end
  endtask
endclass
      
      

  reg PCLK;
  reg PRESETn;
  reg PENABLE;
  reg PSEL;
  reg [1:0] PADDR;
  reg PWRITE;
  reg [7:0] PWDATA;
  wire PREADY;
  wire [7:0] PRDATA;

module apb_test;  
  apb_slave dut (.PCLK(PCLK), .PRESETn(PRESETn), .PENABLE(PENABLE), .PSEL(PSEL), .PADDR(PADDR), .PWRITE(PWRITE), .PWDATA(PWDATA), .PREADY(PREADY), .PRDATA(PRDATA));
  
  apb_transaction test_item;
  apb_sequencer seq;
  apb_driver drv;
  apb_monitor mon;
  apb_scoreboard sb;
  
  mailbox #(apb_transaction) seq_drv_mbx;
  mailbox #(apb_transaction) mon_sb_mbx;
  
  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
  end
  
  initial begin
    PRESETn = 1;
    #2 PRESETn = 0;
    #6 PRESETn = 1;
  end
  
  initial begin
    test_item = new(); seq = new(); drv = new(); mon = new(); sb = new(); seq_drv_mbx = new(); mon_sb_mbx = new();
    
    seq.mbx = seq_drv_mbx;
    drv.mbx = seq_drv_mbx;
    mon.mbx = mon_sb_mbx;
    sb.mbx = mon_sb_mbx;
    
    fork
      seq.run();
      drv.run();
      mon.run();
      sb.run();
    join_none
  end
  
  initial begin
    #5000 $finish;
  end
endmodule
