module apb_slave # (
  parameter ADDR_WIDTH = 32,  //! Address width parameter
  parameter DATA_WIDTH = 8  //! Data width parameter
)  (

  // Global Signals
  input                            PCLK, //! General input clock
  input                         PPRESETn, //! General Reset singal
  
  // Slave response signals
  output logic                   PREADY_o, //! Ready signal from slave (1 = ready, 0 = not ready)

  // Control signals from Master
  input                          PWRITE_i, //! Write control signal (1 = write, 0 = read)
  input                            PSEL_i, //! Peripheral select signal (asserted when this slave is selected)
  input                         PENABLE_i, //! Enable signal (asserted during the active transfer phase)

  // Address and data buses
  input        [ADDR_WIDTH -1 :0]  PADDR_i, //! Address sent to slave from master
  input        [DATA_WIDTH -1 :0] PWDATA_i, //! Data received from master during a write operation
  output logic [DATA_WIDTH -1 :0] PRDATA_o, //! Data sent to master during a read operation

  output                      PSLVERR_o
);


  localparam mem_depth = 16;
  logic [DATA_WIDTH-1 :0] mem [0:mem_depth-1];

  bit add_err, addv_err,data_err;

  //----------------------------------------------
  //! State Encoding 
  //----------------------------------------------
  typedef enum logic [1:0] {
            IDLE   = 2'b01,
            WRTE   = 2'b10,
            READ   = 2'b11
          } apb_state_t;

  apb_state_t current_state, next_state;


  //! This `always_ff` block handles the state transition logic for the FSM.
  //! - On reset (`PPRESETn` deasserted), the FSM enters the `IDLE` state.
  //! - On each rising edge of `PCLK`, the current state updates to the next state.
  always_ff @ (posedge PCLK or negedge PPRESETn) begin : state_transition
    if (!PPRESETn) 
        current_state <= IDLE;  
    else
        current_state <= next_state;
  end


//! This `always_comb` block implements the combinational logic for an APB slave state machine.
//! It determines the next state (`next_state`) and generates outputs (`PREADY_o`, `PRDATA_o`)
//! based on the current state (`current_state`) and inputs (`PSEL_i`, `PWRITE_i`, `PENABLE_i`, etc.).
//!
//! States:
//!   - `IDLE`: Waits for a transaction. Transitions to `WRTE` (write) or `READ` (read) if `PSEL_i` is asserted.
//!   - `WRTE`: Completes a write operation if `PSEL_i` and `PENABLE_i` are asserted.
//!   - `READ`: Completes a read operation if `PSEL_i` and `PENABLE_i` are asserted, outputting data from `mem`.
//!
//! Outputs:
//!   - `PREADY_o`: Asserted to indicate the slave is ready.
//!   - `PRDATA_o`: Outputs read data during a read operation.
//!
//! Notes:
//!   - Memory write logic should be moved to an `always_ff` block.
//!   - Errors (`add_err`, `addv_err`, `data_err`) prevent invalid memory access.
  always_comb begin : apb_slave_comb_logic
    // Default assignments
    PREADY_o = 1'b0;
    PRDATA_o = 'b0;
    next_state = current_state; // Default to current state
  
    case (current_state)
      IDLE: begin 
        if (PSEL_i) begin
          next_state = (PWRITE_i) ? WRTE : READ;
        end else begin
          next_state = IDLE;
        end
      end
  
      WRTE: begin
        if (PSEL_i && PENABLE_i) begin 
          next_state = IDLE;
          PREADY_o = 1'b1;
          // Memory write logic should be moved to an always_ff block
        end
      end
  
      READ: begin
        if (PSEL_i && PENABLE_i) begin
          next_state = IDLE;
          PREADY_o = 1'b1;
          if (!add_err && !addv_err && !data_err) 
            PRDATA_o = mem[PADDR_i]; // Ensure PADDR_i is within valid range
        end
      end
  
      default: begin
        next_state = IDLE;
      end
    endcase
  end : apb_slave_comb_logic

  // Chekcing valid values of address
  logic av_t = (PADDR_i >= 0)? 1'b0 : 1'b1;

  // Chekcing valid values of data
  logic dv_t = (PWDATA_i >= 0)? 1'b0 : 1'b1;

  assign add_err  = ((next_state[1]) && (PADDR_i >= mem_depth))? 1'b1 : 1'b0;
  assign addv_err = ( next_state[1])? av_t : 1'b0;
  assign data_err = ( next_state[1])? dv_t : 1'b0;

  assign PSLVERR = (PSEL_i && PENABLE_i)? (add_err || addv_err || data_err) : 1'b0;


endmodule