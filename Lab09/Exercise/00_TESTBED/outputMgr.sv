`ifndef OUTPUTMGR
`define OUTPUTMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
import usertype::*;

class outputMgr;
    function new();
        this._logger = new("outputMgr");
        this._goldWarnMsg = No_Warn;
        this._goldComplete = 0;
        this._curWarnMsg = No_Warn;
        this._curComplete = 0;
    endfunction

    // Main
    function bit isCorrect();
        return (_curWarnMsg===_goldWarnMsg) && (_curComplete===_goldComplete);
    endfunction

    // Setter
    function void setGoldOutput(Warn_Msg warnMsg, logic complete);
        this._goldWarnMsg = warnMsg;
        this._goldComplete = complete;
    endfunction

    function void setCurdOutput(Warn_Msg warnMsg, logic complete);
        this._curWarnMsg = warnMsg;
        this._curComplete = complete;
    endfunction

    // Dumper
    function void display();

    endfunction


    local Warn_Msg _goldWarnMsg;
    local logic _goldComplete;
    local Warn_Msg _curWarnMsg;
    local logic _curComplete;

    local logger _logger;
endclass

`endif