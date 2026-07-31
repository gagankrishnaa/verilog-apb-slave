`timescale 1ns/1ps
module apb_slave (
  input PCLK,
  input PRESETn,
  input PSEL,
  input PENABLE,
  input [1:0] PADDR,
  input PWRITE,
  input [7:0] PWDATA,
  output reg PREADY,
  output reg [7:0] PRDATA
);
  parameter IDLE = 2'b00, SETUP = 2'b01, ACCESS = 2'b10;
  reg [1:0] state;
  reg [7:0] mem [0:3];
  
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      state <= IDLE;
      PREADY <= 0;
      PRDATA <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (PSEL)
            state <= SETUP;
          else 
            state <= IDLE;
        end
        
        SETUP: begin
          state <= ACCESS;
        end
        
        ACCESS: begin
          if (PENABLE) begin
            if (PWRITE)
              mem[PADDR] <= PWDATA;
            else begin
              PRDATA <= mem[PADDR];
            end
            if (PSEL) begin
              state <= SETUP;
              PREADY <= 1;
            end else begin
              state <= IDLE;
              PREADY <= 1;
            end
          end else begin
            state <= IDLE;
            PREADY <= 0;
          end
        end
        
        default: state <= IDLE;
        
      endcase
    end
  end

`ifndef SYNTHESIS
  property p_penable_needs_psel;
    @(posedge PCLK) disable iff (!PRESETn) PENABLE |-> PSEL;
  endproperty
  a_penable_needs_psel: assert property (p_penable_needs_psel)
    else $error ("PENABLE asserted without PSEL");
`endif
  
`ifndef SYNTHESIS
  property p_setup_one_cycle;
    @(posedge PCLK) disable iff (!PRESETn) state == SETUP |=> state == ACCESS;
  endproperty
  a_setup_one_cycle: assert property (p_setup_one_cycle)
    else $error ("SETUP did not transition to ACCESS after one cycle");
`endif
    
`ifndef SYNTHESIS
  property p_paddr_pwdata_stable;
    @(posedge PCLK) disable iff (!PRESETn) (state == ACCESS && PREADY == 0) |-> $stable(PADDR) && $stable(PWDATA);
  endproperty
  a_paddr_pwdata_stable: assert property (p_paddr_pwdata_stable)
    else $error ("PADDR and PWDATA is not stable");
`endif

endmodule
