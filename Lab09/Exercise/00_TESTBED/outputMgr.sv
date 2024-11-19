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
        this._originalDataDir.Index_A = 'dx;
        this._originalDataDir.Index_B = 'dx;
        this._originalDataDir.Index_C = 'dx;
        this._originalDataDir.Index_D = 'dx;
        this._originalDataDir.M = 'dx;
        this._originalDataDir.D = 'dx;
    endfunction

    // Main
    function bit isCorrect();
        return (_curWarnMsg===_goldWarnMsg) && (_curComplete===_goldComplete);
    endfunction

    // Setter
    function void clear();
        this._goldWarnMsg = No_Warn;
        this._goldComplete = 0;
        this._curWarnMsg = No_Warn;
        this._curComplete = 0;
        this._originalDataDir.Index_A = 'dx;
        this._originalDataDir.Index_B = 'dx;
        this._originalDataDir.Index_C = 'dx;
        this._originalDataDir.Index_D = 'dx;
        this._originalDataDir.M = 'dx;
        this._originalDataDir.D = 'dx;
    endfunction

    function void setOriginalDataDir(Data_Dir in);
        _originalDataDir = in;
    endfunction

    function void setGoldOutput(Warn_Msg warnMsg, logic complete);
        _goldWarnMsg = warnMsg;
        _goldComplete = complete;
    endfunction

    function void setCurdOutput(Warn_Msg warnMsg, logic complete);
        _curWarnMsg = warnMsg;
        _curComplete = complete;
    endfunction

    // Getter
    function Data_Dir getOriginalDataDir();
        return _originalDataDir;
    endfunction

    function reportTable getOutputTable();
        reportTable dataTable;
        dataTable = new("Output table");
        dataTable.defineCol("");
        dataTable.defineCol("Complete");
        dataTable.defineCol("Warning Message");
        dataTable.newRow();
        dataTable.addCell("Gold");
        dataTable.addCell($sformatf("%1d", _goldComplete));
        dataTable.addCell($sformatf("%s", _goldWarnMsg.name()));
        dataTable.newRow();
        dataTable.addCell("Your");
        dataTable.addCell($sformatf("%1d", _curComplete));
        dataTable.addCell($sformatf("%s", _curWarnMsg.name()));
        return dataTable;
    endfunction

    // Dumper
    function void display();
        reportTable dataTable = getOutputTable();
        dataTable.show();
    endfunction

    Data_Dir _originalDataDir;

    local Warn_Msg _goldWarnMsg;
    local logic _goldComplete;
    local Warn_Msg _curWarnMsg;
    local logic _curComplete;

    local logger _logger;
endclass

`endif