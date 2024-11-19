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
    function void display();
        Action curAction = _inputMgr.getAction();
        reportTable inputTable = _inputMgr.getInputTable(curAction);
        reportTable outputTable = _outputMgr.getOutputTable();
        reportTable originalDataDirTable = _dramMgr.DataDirToTable(_outputMgr.getOriginalDataDir());
        reportTable currentDataDirTable = _dramMgr.DataDirToTable(_dramMgr.getDataDir(_inputMgr.getDataNo()));
        
        string content = "Output is not correct...\n\n";
        content = {
            content,
            outputTable.combineStringHorizontal(
                {"[Input table ] :\n", inputTable.toString()},
                {"[Output table] :\n", outputTable.toString()},
                "    "
            ),
            "\n\n"
        };
        // content = {content, "[Input table ] :\n", inputTable.toString(), "\n\n"};
        // content = {content, "[Output table] :\n", outputTable.toString(), "\n"};
        if(curAction==Index_Check) begin
            content = {content, "[Dram Data Dir] :\n", currentDataDirTable.toString(), "\n\n"};
        end
        else if(curAction==Update) begin
            content = {
                content,
                outputTable.combineStringHorizontal(
                    {"[Original Dram Data Dir] :\n", originalDataDirTable.toString()},
                    {"[Current Dram Data Dir] :\n", currentDataDirTable.toString()},
                    "    "
                ),
                "\n\n"
            };
            // content = {content, "[Original Dram Data Dir] :\n", originalDataDirTable.toString(), "\n\n"};
            // content = {content, "[Current Dram Data Dir] :\n", currentDataDirTable.toString(), "\n\n"};
        end
        _logger.error(content);
    endfunction

    local logger _logger;
    local dramMgr _dramMgr;
    local inputMgr _inputMgr;
    local outputMgr _outputMgr;
endclass

`endif