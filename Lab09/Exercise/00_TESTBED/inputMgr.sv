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

    //
    function Action getAction();
        return _randMgr.action;
    endfunction

    function Formula_Type getFormulaType();
        return _randMgr.formulaType;
    endfunction

    function Mode getMode();
        return _randMgr.mode;
    endfunction

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

    function Month getMonth();
        return _randMgr.month;
    endfunction

    function Day getDay();
        return _randMgr.day;
    endfunction

    function Data_No getDataNo();
        return _randMgr.dataNo;
    endfunction

    // Dumper
    function void display();
        _randMgr.display();
    endfunction

    local logger _logger;
    local randMgr _randMgr;
endclass

`endif