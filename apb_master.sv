`timescale 1ns/1ps

module apb_master #(
    parameter ADDR_WIDTH = 8,    //! Address bus width
    parameter DATA_WIDTH = 8     //! Data bus width
  ) (
    // Clock and Reset
    input  logic                   PCLK,       //! APB clock
    input  logic                   PRESETn,    //! Active-low reset

    // Control Signals
    input  logic                   transfer_i, //! Initiate transfer
    input  logic                   rw_i,       //! 1 = Write, 0 = Read

    // Write Data Interface
    input  logic [ADDR_WIDTH-1  :0]   PADDR_i,  //! wirte address
    input  logic [DATA_WIDTH-1  :0]  PWDATA_i,  //! Write data
    input  logic [DATA_WIDTH/8-1:0]   PSTRB_i, 

    // Read Data Interface
    input  logic [ADDR_WIDTH-1:0]  rd_addr_i,  //! Read address
    output logic [DATA_WIDTH-1:0]  rd_data_o,  //! Read data (captured from slave)

    // APB Slave Interface
    input  logic                    PREADY,     //! Slave ready signal
    input  logic [DATA_WIDTH-1:0]   PRDATA,     //! Read data from slave
    output logic                    PSELx,       //! Peripheral select
    output logic                    PENABLE,    //! Transfer enable
    output logic                    PWRITE,     //! Write/Read control
    output logic [ADDR_WIDTH-1:0]   PADDR,      //! Address bus
    output logic [DATA_WIDTH-1:0]   PWDATA      //! Write data bus
  );

  //----------------------------------------------
  //! State Encoding (One-Hot for Robustness)
  //----------------------------------------------
  typedef enum logic [1:0] {
            IDLE   = 2'b01,
            SETUP  = 2'b10,
            ACCESS = 2'b11
          } apb_state_t;

  apb_state_t current_state, next_state;

  //----------------------------------------------
  //! Sequential State Transition Logic
  //----------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn)
  begin
    if (!PRESETn)
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  //----------------------------------------------
  //! Combinatorial Next-State Logic
  //----------------------------------------------
  always_comb
  begin
    next_state = current_state;
    case (current_state)
      IDLE:
      begin
        if (transfer_i)
          next_state = SETUP;
      end

      SETUP:
      begin
        next_state = ACCESS; // Always transition to ACCESS after SETUP
      end

      ACCESS:
      begin
        if (PREADY)
          next_state = IDLE; // Return to IDLE when slave is ready
      end 

      default:
        next_state = IDLE; // Handle undefined states
    endcase
  end

  //----------------------------------------------
  //! APB Control Signal Generation
  //----------------------------------------------
  always_ff @(posedge PCLK or negedge PRESETn)
  begin
    if (!PRESETn)
    begin
      PSEL     <= 1'b0;
      PENABLE  <= 1'b0;
      PWRITE   <= 1'b0;
      PADDR    <= {ADDR_WIDTH{1'b0}};
      PWDATA   <= {DATA_WIDTH{1'b0}};
    end
    else
    begin
      case (next_state)
        IDLE:
        begin
          PSEL     <= 1'b0;
          PENABLE  <= 1'b0;
          PWRITE   <= rw_i; // Pre-assert PWRITE for SETUP phase
          PADDR    <= (rw_i) ? wr_addr_i : rd_addr_i; // Latch address
          PWDATA   <= (rw_i) ? wr_data_i : PWDATA;    // Latch write data
        end

        SETUP:
        begin
          PSEL     <= 1'b1;  // Assert PSEL in SETUP phase
          PENABLE  <= 1'b0;
        end

        ACCESS:
        begin
          PENABLE  <= 1'b1;  // Assert PENABLE in ACCESS phase
        end

        default:
          ; // No change
      endcase
    end
  end

  //----------------------------------------------
  // Read Data Capture Logic
  //----------------------------------------------
  reg [DATA_WIDTH-1:0] rd_data_captured;

  always_ff @(posedge PCLK or negedge PRESETn)
  begin
    if (!PRESETn)
    begin
      rd_data_captured <= {DATA_WIDTH{1'b0}};
    end
    else if (PREADY && !PWRITE)
    begin
      rd_data_captured <= PRDATA; // Capture read data on successful read
    end
  end

  assign rd_data_o = rd_data_captured;



  //----------------------------------------------
  // Assertions (For Simulation Debugging)
  //----------------------------------------------
  // synthesis translate_off
  always @(posedge PCLK)
  begin
    if (current_state == ACCESS && !PENABLE)
    begin
      $error("APB Protocol Violation: PENABLE not asserted in ACCESS state!");
    end
  end

endmodule
