module apb_slave # (
  parameter ADDR_WIDTH = 32,  //! Address width parameter
  parameter DATA_WIDTH = 8  //! Data width parameter
)  (

  // Global Signals
  input                            PCLK,
  input                         PPRESETn,
  
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
  //! State Encoding (
  //----------------------------------------------
  typedef enum logic [1:0] {
            IDLE   = 2'b01,
            WRTE   = 2'b10,
            READ   = 2'b11
          } apb_state_t;

  apb_state_t current_state, next_state;

  always @ (posedge PCLK or negedge PPRESETn) begin 
    if (!PPRESETn) 
      current_state <= IDLE;  
    else
      current_state <= next_state;
  end


  always_comb begin 
    // Default values


    case (current_state)
      IDLE: begin 
        PREADY_o = 1'b0;
        PRDATA_o =  'b0;

        if (PSEL_i)
          next_state = (PWRITE_i)? WRTE : READ;
        else  
          next_state = IDLE;
      end

      WRTE: begin
        if (PSEL_i && PENABLE_i) begin 
          if (!add_err && !addv_err && !data_err) begin
            PREADY_o = 1'b1;
            mem[PADDR_i] = PWDATA_i;
            next_state = IDLE;
          end else begin
            next_state = IDLE;
            PREADY_o = 1'b1;
          end

        end else begin 
          // error handling goes here
        end

      end

      READ: begin
        if (PSEL_i && PENABLE_i) begin
          if (!add_err && !addv_err && !data_err) begin 
            PREADY_o = 1'b1;
            PRDATA_o = mem[PADDR_i];
            next_state = IDLE;
          end else begin 
            next_state = IDLE;
            PREADY_o = 1'b1;
          end
        end else begin 
          // error handling goes here 
        end
      end

      default: begin
        next_state = IDLE;
        PRDATA_o  =  'b0;
      end
    endcase
  end

  // Chekcing valid values of address
  logic av_t = (PADDR_i >= 0)? 1'b0 : 1'b1;

  // Chekcing valid values of data
  logic dv_t = (PWDATA_i >= 0)? 1'b0 : 1'b1;

  assign add_err  = ((next_state[1]) && (PADDR_i >= mem_depth))? 1'b1 : 1'b0;
  assign addv_err = ( next_state[1])? av_t : 1'b0;
  assign data_err = ( next_state[1])? dv_t : 1'b0;

  assign PSLVERR = (PSEL_i && PENABLE_i)? (add_err || addv_err || data_err) : 1'b0;
endmodule