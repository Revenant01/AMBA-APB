class transaction;

  randc bit [31:0] PADDR;
  randc bit [7:0]  PWDATA;
  randc bit PSEL;
  randc bit PENABLE;
  rand bit PWRITE;
  bit [7:0] PRDATA;
  bit PREADY;
  bit PSLVERR;

  
  constraint write_c {
    PWRITE dist {0:=10 , 1:=90};
  }

  constraint addr_c {
    PADDR >= 0; PADDR <= 15;
  }

  constraint data_c {
    PWDATA >= 0; PWDATA <= 255;
  }

  function void display(input string tag);
    if (PWRITE) begin 
      $display("[%0s] :  PWRITE:%0b PADDR:%0d  PWDATA:%0d PSLVERR:%0b @ %0t",tag, PWRITE,PADDR,PWDATA, PSLVERR,$time);
    end else begin 
      $display("[%0s] :  PWRITE:%0b PADDR:%0d  PRDATA:%0d PSLVERR:%0b @ %0t",tag, PWRITE,PADDR,PRDATA, PSLVERR,$time);
    end
  endfunction

endclass


interface apb_if;
  logic PCLK;
  logic PPRESETn;
  logic PREADY;
  logic PSLVERR;
  logic [31:0] PADDR;
  logic [7:0]  PWDATA;
  logic PWRITE;
  logic PSEL;
  logic PENABLE;
  logic [7:0] PRDATA;

  modport DRV (
  input PRDATA,PREADY,PSLVERR,
  output PCLK, PWRITE, PSEL, PENABLE, PADDR, PWDATA, PPRESETn
  );

  modport MON (
    input PCLK, PWRITE, PSEL, PENABLE, PADDR, PWDATA, PPRESETn,
    output PRDATA,PREADY,PSLVERR
  ); 
endinterface //interfacename


class generator;

  transaction tr;
  mailbox #(transaction) mbx; 
  int count = 0;

  event nextdrv;
  event nextsco;
  event done;
  
 
  
  function new (mailbox # (transaction) mbx);
    this.mbx = mbx;
    tr = new ();
  endfunction


  task main ();

    repeat (count) begin 
      assert(tr.randomize()) else $error("RANDOMIZATION FAILED");
      mbx.put(tr);
      tr.display ("GEN");
      @(nextdrv);
      @(nextsco);
    end
    ->done;

  endtask

endclass


class driver; 

  virtual apb_if vif;
  mailbox # (transaction) mbx;
  transaction drv_data;

  event nextdrv;

  function new (mailbox # (transaction) mbx,virtual apb_if vif);
    this.mbx = mbx;
    this.vif= vif;
  endfunction


  task reset();
    vif.PPRESETn <= 1'b0;
    vif.PSEL    <= 1'b0;
    vif.PENABLE <= 1'b0;
    vif.PWDATA  <= 0;
    vif.PADDR   <= 0;
    vif.PWRITE  <= 1'b0;
    repeat(5) @(posedge vif.PCLK);
      vif.PPRESETn <= 1'b1;
      $display("[DRV] : RESET DONE");
      $display("----------------------------------------------------------------------------");
  endtask

  task main ();
    
    forever begin
      mbx.get(drv_data);
      @(posedge vif.PCLK);
        vif.PSEL    <= 1'b1;
        vif.PENABLE <= 1'b0;
        vif.PADDR <= drv_data.PADDR;
        if (drv_data.PWRITE) begin // write 
          vif.PWDATA  <= drv_data.PWDATA;
          vif.PWRITE  <= 1'b1;
          @(posedge vif.PCLK);
            vif.PENABLE <= 1'b1;
          	@(posedge  vif.PCLK);
              vif.PENABLE <= 1'b0;
              vif.PSEL    <= 1'b0;
              vif.PWRITE  <= 1'b0;
              drv_data.display("DRV");
              ->nextdrv;
        end else begin 
          vif.PRDATA  <= drv_data.PRDATA;
          vif.PWRITE  <= 1'b0;
          @(posedge vif.PCLK);
            vif.PENABLE <= 1'b1; 
            @(posedge vif.PCLK); 
              vif.PSEL <= 1'b0;
              vif.PENABLE <= 1'b0;
              vif.PWRITE <= 1'b0;
              drv_data.display("DRV"); 
              ->nextdrv;      
        end
    end
  endtask
endclass


class monitor;

  virtual apb_if vif;
  mailbox # (transaction) mbx;
  transaction tr;

  function new (mailbox # (transaction) mbx,virtual apb_if vif);
    this.mbx = mbx;
    this.vif = vif;
  endfunction

  task main ();
    tr = new ();
    forever begin
      @(posedge vif.PCLK);
        if (vif.PREADY) begin 
          tr.PWDATA  = vif.PWDATA;
          tr.PADDR   = vif.PADDR;
          tr.PWRITE  = vif.PWRITE;
          tr.PRDATA  = vif.PRDATA; 
          tr.PSEL    = vif.PSEL;
          tr.PSLVERR = vif.PSLVERR;
          @(posedge vif.PCLK) 
            tr.display("MON");
            mbx.put(tr);
        end
    end
  endtask


endclass


class scoreboard;
  
  mailbox #(transaction) mbx;
  transaction tr;
  event nextsco;
  
  bit [7:0] pwdata [16] = '{default:0};
  bit [7:0] rdata;
  int err = 0;
  int match = 0;
  
   function new(mailbox #(transaction) mbx);
      this.mbx = mbx;     
    endfunction;
  
  task main();
  forever 
      begin   
      mbx.get(tr);
      tr.display("SCO");
      if( tr.PWRITE  && !tr.PSLVERR )  begin ///write access  
        pwdata[tr.PADDR] = tr.PWDATA;
        $display("[SCO] : DATA STORED DATA : %0d ADDR: %0d",tr.PWDATA, tr.PADDR);
        end
      else if( !tr.PWRITE && !tr.PSLVERR)  begin ///read access 
         rdata = pwdata[tr.PADDR];    
        if( tr.PRDATA == rdata) begin 
          match++; 
          $display("[SCO] : Data Matched");           
        end else begin
          err++;
          $display("[SCO] : Data Mismatched");
          end 
        end 
      else if(tr.PSLVERR)
        begin
          $display("[SCO] : SLV ERROR DETECTED");
        end  
      $display("---------------------------------------------------------------------------------------------------");
      ->nextsco;
 
  end
    
  endtask

endclass

class environment;

  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;

  event nextgen2drv;
  event nextgen2sco;

  mailbox #(transaction) gen2drv_mbx;
  mailbox #(transaction) mon2sco_mbx;

  virtual apb_if vif;

  function new (virtual apb_if vif);
    gen2drv_mbx = new ();
    mon2sco_mbx = new ();

    gen = new(gen2drv_mbx);
    drv = new(gen2drv_mbx,vif);
    mon = new(mon2sco_mbx,vif);
    sco = new(mon2sco_mbx);

    gen.nextdrv = this.nextgen2drv;
    drv.nextdrv = this.nextgen2drv;

    gen.nextsco = this.nextgen2sco;
    sco.nextsco = this.nextgen2sco;
  endfunction

  task pre_test ();
    drv.reset();
  endtask

  task test();
    fork
      gen.main();
      drv.main();
      mon.main();
      sco.main();
    join_any
  endtask

  task post_test();
    wait(gen.done.triggered);
      $display("#######  Total number of Mismatch : %0d  #######",sco.err);
    $display("#########  Total number of Match : %0d   #########",sco.match);
      $finish();
  endtask

  task run ();
    pre_test();
    test();
    post_test();
  endtask

endclass
 
  

module tb;
    
  apb_if vif();

  apb_slave dut (
    .PCLK(vif.PCLK),
    .PPRESETn(vif.PPRESETn),
    .PADDR_i(vif.PADDR),
    .PSEL_i(vif.PSEL),
    .PENABLE_i(vif.PENABLE),
    .PWDATA_i(vif.PWDATA),
    .PWRITE_i(vif.PWRITE),
    .PRDATA_o(vif.PRDATA),
    .PREADY_o(vif.PREADY),
    .PSLVERR_o(vif.PSLVERR)
  );

  initial begin
    vif.PCLK <= 0;
  end
  
  always #10 vif.PCLK <= ~vif.PCLK;
  
  environment env;

  initial begin
    env = new(vif);
    env.gen.count = 64;
    env.run();
  end
     
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

 
endmodule
