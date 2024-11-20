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
    function logic getValid(string targetTypeName, string selectedTypeName);
        return targetTypeName==selectedTypeName ? 1 : 0;
    endfunction

    function Data getInputData(string dataTypeName, string indexName="A");
        Data out;
        Date date;
        date.M = _randMgr.month;
        date.D = _randMgr.day;
        case(dataTypeName)
            $typename(out.d_act[0]): out.d_act[0] = _randMgr.action;
            $typename(out.d_formula[0]): out.d_formula[0] = _randMgr.formulaType;
            $typename(out.d_mode[0]): out.d_mode[0] = _randMgr.mode;
            $typename(out.d_date[0]): out.d_date[0] = date;
            $typename(out.d_data_no[0]): out.d_data_no[0] = _randMgr.dataNo;
            $typename(out.d_index[0]): begin
                case(indexName)
                    "A": out.d_index[0] = _randMgr.indexA;
                    "B": out.d_index[0] = _randMgr.indexB;
                    "C": out.d_index[0] = _randMgr.indexC;
                    "D": out.d_index[0] = _randMgr.indexD;
                    default: begin
                        _logger.error($sformatf("Invalid index name: %s", indexName));
                    end
                endcase
            end
            default: begin
                _logger.error($sformatf("Invalid data type name: %s", dataTypeName));
            end
        endcase
        return out;
    endfunction

    function Action getAction();
        return _randMgr.action;
    endfunction

    // Formula & Mode
    function Formula_Type getFormulaType();
        return _randMgr.formulaType;
    endfunction

    function Mode getMode();
        return _randMgr.mode;
    endfunction

    // Index
    function Index getIndexA();
        return _randMgr.indexA;
    endfunction

    function Index getIndexB();
        return _randMgr.indexB;
    endfunction

    function Index getIndexC();
        return _randMgr.indexC;
    endfunction

    function Index getIndexD();
        return _randMgr.indexD;
    endfunction

    // Date
    function Month getMonth();
        return _randMgr.month;
    endfunction

    function Day getDay();
        return _randMgr.day;
    endfunction

    // Data_Dir
    function Data_No getDataNo();
        return _randMgr.dataNo;
    endfunction

    function randMgr getRandMgr();
        return _randMgr;
    endfunction

    function reportTable getInputTable(Action actionSel);
        reportTable dataTable;
        dataTable = new("Input table");
        dataTable.defineCol("Data");
        dataTable.defineCol("Value");
        dataTable.newRow();
        dataTable.addCell("Action");
        dataTable.addCell($sformatf("%s", _randMgr.action.name()));
        if(actionSel == Index_Check) begin
            dataTable.newRow();
            dataTable.addCell("Formula type");
            dataTable.addCell($sformatf("%s", _randMgr.formulaType.name()));
            
            dataTable.newRow();
            dataTable.addCell("Mode");
            dataTable.addCell($sformatf("%s", _randMgr.mode.name()));
        end

        dataTable.newRow();
        dataTable.addCell("Date\(M/D\)");
        dataTable.addCell($sformatf("%2d / %2d", _randMgr.month, _randMgr.day));

        if(actionSel == Index_Check || actionSel == Update) begin
            dataTable.newRow();
            dataTable.addCell("Data No.");
            dataTable.addCell($sformatf("%3d", _randMgr.dataNo));
            dataTable.newRow();
            dataTable.addCell(actionSel == Index_Check ? "Index A" : "Variation of Index A");
            dataTable.addCell(
                actionSel == Index_Check
                ? $sformatf("%4d / %3h", _randMgr.indexA, _randMgr.indexA)
                : $sformatf("%5d / %3h", $signed(_randMgr.indexA), _randMgr.indexA)
            );
            dataTable.newRow();
            dataTable.addCell(actionSel == Index_Check ? "Index B" : "Variation of Index B");
            dataTable.addCell(
                actionSel == Index_Check
                ? $sformatf("%4d / %3h", _randMgr.indexB, _randMgr.indexB)
                : $sformatf("%5d / %3h", $signed(_randMgr.indexB), _randMgr.indexB)
            );
            dataTable.newRow();
            dataTable.addCell(actionSel == Index_Check ? "Index C" : "Variation of Index C");
            dataTable.addCell(
                actionSel == Index_Check
                ? $sformatf("%4d / %3h", _randMgr.indexC, _randMgr.indexC)
                : $sformatf("%5d / %3h", $signed(_randMgr.indexC), _randMgr.indexC)
            );
            dataTable.newRow();
            dataTable.addCell(actionSel == Index_Check ? "Index D" : "Variation of Index D");
            dataTable.addCell(
                actionSel == Index_Check
                ? $sformatf("%4d / %3h", _randMgr.indexD, _randMgr.indexD)
                : $sformatf("%5d / %3h", $signed(_randMgr.indexD), _randMgr.indexD)
            );
        end
        return dataTable;
    endfunction

    // Dumper
    function void display();
        reportTable dataTable = getInputTable(getAction());
        dataTable.show();
    endfunction

    local logger _logger;
    local randMgr _randMgr;
endclass

`endif