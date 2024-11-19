`ifndef STOCKTRADEFLOWMGR
`define STOCKTRADEFLOWMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
`include "../00_TESTBED/dramMgr.sv"
`include "../00_TESTBED/inputMgr.sv"
`include "../00_TESTBED/outputMgr.sv"
import usertype::*;

class stockTradeFlowMgr;
    function new(int seed);
        this._logger = new("stockTradeFlowMgr");
        this._dramMgr = new(seed);
        this._inputMgr = new(seed);
        this._outputMgr = new();
    endfunction

    // Executor
    function void run();

    endfunction

    // Setter

    // Getter
    function dramMgr getDramMgr();
        return _dramMgr;
    endfunction

    function inputMgr getInputMgr();
        return _inputMgr;
    endfunction

    function outputMgr getOutputMgr();
        return _outputMgr;
    endfunction

    // Dumper

    local logger _logger;
    local dramMgr _dramMgr;
    local inputMgr _inputMgr;
    local outputMgr _outputMgr;
endclass

`endif