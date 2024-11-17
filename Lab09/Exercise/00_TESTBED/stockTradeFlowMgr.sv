`ifndef STOCKTRADEFLOWMGR
`define STOCKTRADEFLOWMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
`include "../00_TESTBED/inputMgr.sv"
import usertype::*;

class stockTradeFlowMgr;
    function new(int seed);
        this._logger = new("stockTradeFlowMgr");
        this._inputMgr = new(seed);
    endfunction

    // Executor
    function void randomizeInput();
        this._inputMgr.randomizeInput();
    endfunction

    function void run();

    endfunction

    // Setter

    // Getter

    // Dumper

    local logger _logger;
    local randMgr _inputMgr;
endclass

`endif