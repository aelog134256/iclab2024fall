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
        Action curAction = _inputMgr.getAction();
        case(curAction)
            Index_Check: indexCheck();
            Update: update();
            Check_Valid_Date: checkValidDate();
            default: _logger.error($sformatf("Invalid action : %s", curAction.name()));
        endcase
    endfunction

    function void indexCheck();
        Data_Dir dramDataDir = _dramMgr.getDataDir(_inputMgr.getDataNo());
        Date today, dramDate;
        Index res;
        Index threshold = paramMgr::getThreshold(_inputMgr.getFormulaType(), _inputMgr.getMode());
        Warn_Msg goldWarnMsg = No_Warn;
        logic goldComplete = 1;
        today.M = _inputMgr.getMonth();
        today.D = _inputMgr.getDay();
        dramDate.M = dramDataDir.M;
        dramDate.D = dramDataDir.D;
        res = paramMgr::calcResult(
            _inputMgr.getFormulaType(),
            dramDataDir.Index_A, dramDataDir.Index_B, dramDataDir.Index_C, dramDataDir.Index_D,
            _inputMgr.getIndexA(), _inputMgr.getIndexB(), _inputMgr.getIndexC(), _inputMgr.getIndexD()
        );

        // Warng Msg
        if(paramMgr::dateIsEarlier(today, dramDate)) goldWarnMsg = Date_Warn;
        else if(res >= threshold) goldWarnMsg = Risk_Warn;

        // Complete
        goldComplete = goldWarnMsg!=No_Warn ? 0 : 1;

        // Store
        _outputMgr.setGoldOutput(goldWarnMsg, goldComplete);
        _outputMgr.setResult(res, threshold);
    endfunction

    function void update();
        Data_No id = _inputMgr.getDataNo();
        Data_Dir dramDataDir = _dramMgr.getDataDir(id);
        Warn_Msg goldWarnMsg = No_Warn;
        logic goldComplete = 1;
        _outputMgr.setOriginalDataDir(dramDataDir);
        
        // Warn Msg
        goldWarnMsg = determineUpdateWarnMsg(dramDataDir.Index_A, $signed(_inputMgr.getIndexA()), goldWarnMsg);
        goldWarnMsg = determineUpdateWarnMsg(dramDataDir.Index_B, $signed(_inputMgr.getIndexB()), goldWarnMsg);
        goldWarnMsg = determineUpdateWarnMsg(dramDataDir.Index_C, $signed(_inputMgr.getIndexC()), goldWarnMsg);
        goldWarnMsg = determineUpdateWarnMsg(dramDataDir.Index_D, $signed(_inputMgr.getIndexD()), goldWarnMsg);

        // Complete
        goldComplete = goldWarnMsg!=No_Warn ? 0 : 1;

        // DataDir
        dramDataDir.Index_A = calcIndex(dramDataDir.Index_A, $signed(_inputMgr.getIndexA()));
        dramDataDir.Index_B = calcIndex(dramDataDir.Index_B, $signed(_inputMgr.getIndexB()));
        dramDataDir.Index_C = calcIndex(dramDataDir.Index_C, $signed(_inputMgr.getIndexC()));
        dramDataDir.Index_D = calcIndex(dramDataDir.Index_D, $signed(_inputMgr.getIndexD()));
        dramDataDir.M = _inputMgr.getMonth();
        dramDataDir.D = _inputMgr.getDay();

        // Store
        _outputMgr.setGoldOutput(goldWarnMsg, goldComplete);
        _dramMgr.setDataDir(id, dramDataDir);
    endfunction

    function void checkValidDate();
        Data_Dir dramDataDir = _dramMgr.getDataDir(_inputMgr.getDataNo());
        Date today, dramDate;
        Warn_Msg goldWarnMsg = No_Warn;
        logic goldComplete = 1;
        today.M = _inputMgr.getMonth();
        today.D = _inputMgr.getDay();
        dramDate.M = dramDataDir.M;
        dramDate.D = dramDataDir.D;

        // Warn Msg
        if(paramMgr::dateIsEarlier(today, dramDate)) goldWarnMsg = Date_Warn;

        // Complete
        goldComplete = goldWarnMsg!=No_Warn ? 0 : 1;

        // Store
        _outputMgr.setGoldOutput(goldWarnMsg, goldComplete);
    endfunction

    // Sub-function

    // Update
    function Index calcIndex(logic signed[$bits(Index):0] original, logic signed[$bits(Index):0] variation);
        logic signed[$bits(Index)+1:0] res = original + variation;
        if(res<0) res = 0;
        else if(res>(2**$bits(Index)-1)) res = (2**$bits(Index)-1);
        return res;
    endfunction

    function Warn_Msg determineUpdateWarnMsg(logic signed[$bits(Index):0] original, logic signed[$bits(Index)-1:0] variation, Warn_Msg msg);
        // Only return warn msg
        logic signed[$bits(Index)+1:0] res = original + variation;
        if(res<0) msg = Data_Warn;
        else if(res>(2**$bits(Index)-1)) msg = Data_Warn;
        return msg;
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
        reportTable indexCheckTable = _outputMgr.getIndexCheckTable();
        reportTable originalDataDirTable = _dramMgr.DataDirToTable(_outputMgr.getOriginalDataDir());
        reportTable currentDataDirTable = _dramMgr.DataDirToTable(_dramMgr.getDataDir(_inputMgr.getDataNo()));
        
        string content = "Output info...\n\n";
        string outputString = {"[Output table] :\n", outputTable.toString()};
        if(curAction==Index_Check) begin
            outputString = {outputString, "\n\n", "[Index Check] :\n", indexCheckTable.toString()};
        end

        content = {
            content,
            outputTable.combineStringHorizontal(
                {"[Input table ] :\n", inputTable.toString()},
                outputString,
                "    "
            ),
            (curAction==Check_Valid_Date ? "\n" :"\n\n")
        };
        if(curAction==Index_Check) begin
            content = {content, "[Dram Data Dir] :\n", currentDataDirTable.toString(), "\n"};
        end
        else if(curAction==Update) begin
            content = {
                content,
                outputTable.combineStringHorizontal(
                    {"[Original Dram Data Dir] :\n", originalDataDirTable.toString()},
                    {"[Current Dram Data Dir] :\n", currentDataDirTable.toString()},
                    "    "
                ),
                "\n"
            };
        end
        _logger.info(content);
    endfunction

    local logger _logger;
    local dramMgr _dramMgr;
    local inputMgr _inputMgr;
    local outputMgr _outputMgr;
endclass

`endif