`ifndef INPUTMGR
`define INPUTMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
`include "../00_TESTBED/randMgr.sv"
import usertype::*;

class inputMgr;
    function new(int seed);
        this._logger = new("inputMgr");
        this._randMgr = new(seed);
    endfunction

    // Executor
    function void randomizeInput();
        _randMgr.randomize();
    endfunction

    // Setter

    // Getter

    // Dumper

    local logger _logger;
    local randMgr _randMgr;
endclass

`endif