
# Entity: apb_slave 
- **File**: apb_slave.sv

## Diagram
![Diagram](apb_slave.svg "Diagram")
## Generics

| Generic name | Type | Value | Description             |
| ------------ | ---- | ----- | ----------------------- |
| ADDR_WIDTH   |      | 32    | Address width parameter |
| DATA_WIDTH   |      | 8     | Data width parameter    |

## Ports

| Port name | Direction | Type               | Description                                                     |
| --------- | --------- | ------------------ | --------------------------------------------------------------- |
| PCLK      | input     |                    | General input clock                                             |
| PPRESETn  | input     |                    | General Reset singal                                            |
| PREADY_o  | output    |                    | Ready signal from slave (1 = ready, 0 = not ready)              |
| PWRITE_i  | input     |                    | Write control signal (1 = write, 0 = read)                      |
| PSEL_i    | input     |                    | Peripheral select signal (asserted when this slave is selected) |
| PENABLE_i | input     |                    | Enable signal (asserted during the active transfer phase)       |
| PADDR_i   | input     | [ADDR_WIDTH -1 :0] | Address sent to slave from master                               |
| PWDATA_i  | input     | [DATA_WIDTH -1 :0] | Data received from master during a write operation              |
| PRDATA_o  | output    | [DATA_WIDTH -1 :0] | Data sent to master during a read operation                     |
| PSLVERR_o | output    |                    |                                                                 |

## Signals

| Name                                | Type                    | Description |
| ----------------------------------- | ----------------------- | ----------- |
| mem [0:mem_depth-1]                 | logic [DATA_WIDTH-1 :0] |             |
| add_err                             | bit                     |             |
| addv_err                            | bit                     |             |
| data_err                            | bit                     |             |
| av_t = (PADDR_i >= 0)? 1'b0 : 1'b1  | logic                   |             |
| dv_t = (PWDATA_i >= 0)? 1'b0 : 1'b1 | logic                   |             |

## Constants

| Name      | Type | Value | Description |
| --------- | ---- | ----- | ----------- |
| mem_depth |      | 16    |             |

## Types

| Name        | Type                                                                                                                                                                                                                              | Description    |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| apb_state_t | enum logic [1:0] {<br><span style="padding-left:20px">              IDLE   = 2'b01,<br><span style="padding-left:20px">              WRTE   = 2'b10,<br><span style="padding-left:20px">              READ   = 2'b11            } | State Encoding |

## Processes
- state_transition: ( @ (posedge PCLK or negedge PPRESETn) )
  - **Type:** always_ff
  - **Description**
  This `always_ff` block handles the state transition logic for the FSM.  - On reset (`PPRESETn` deasserted), the FSM enters the `IDLE` state.  - On each rising edge of `PCLK`, the current state updates to the next state. 
- apb_slave_comb_logic: (  )
  - **Type:** always_comb
  - **Description**
  This `always_comb` block implements the combinational logic for an APB slave state machine.  It determines the next state (`next_state`) and generates outputs (`PREADY_o`, `PRDATA_o`)  based on the current state (`current_state`) and inputs (`PSEL_i`, `PWRITE_i`, `PENABLE_i`, etc.).<br>  States:    - `IDLE`: Waits for a transaction. Transitions to `WRTE` (write) or `READ` (read) if `PSEL_i` is asserted.    - `WRTE`: Completes a write operation if `PSEL_i` and `PENABLE_i` are asserted.    - `READ`: Completes a read operation if `PSEL_i` and `PENABLE_i` are asserted, outputting data from `mem`.<br>  Outputs:    - `PREADY_o`: Asserted to indicate the slave is ready.    - `PRDATA_o`: Outputs read data during a read operation.<br>  Notes:    - Memory write logic should be moved to an `always_ff` block.    - Errors (`add_err`, `addv_err`, `data_err`) prevent invalid memory access. 
