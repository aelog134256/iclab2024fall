`ifndef RANDMGR
`define RANDMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
import usertype::*;

class randMgr;
    function new(int seed);
        this.srandom(seed);
        this._logger = new("randMgr");

        enumRandList();
    endfunction

    function void enumRandList();
        Action a;
        Formula_Type ft;
        Mode m;
        a = a.first();
        ft = ft.first();
        m = m.first();
        for(int i=0 ; i<a.num() ; ++i)begin
            actions.push_back(a);
            a = a.next();
        end

        for(int i=0 ; i<ft.num() ; ++i)begin
            formulaTypes.push_back(ft);
            ft = ft.next();
        end

        for(int i=0 ; i<m.num() ; ++i)begin
            modes.push_back(m);
            m = m.next();
        end
    endfunction

    // Getter
    function reportTable getTable();
        reportTable dataTable;
        dataTable = new("Random Data");
        dataTable.defineCol("Data");
        dataTable.defineCol("Value");
        dataTable.newRow();
        dataTable.addCell("Action");
        dataTable.addCell($sformatf("%s", action.name()));
        dataTable.newRow();
        dataTable.addCell("Formula type");
        dataTable.addCell($sformatf("%s", formulaType.name()));
        dataTable.newRow();
        dataTable.addCell("Mode");
        dataTable.addCell($sformatf("%s", mode.name()));
        dataTable.newRow();
        dataTable.addCell("Index A");
        dataTable.addCell($sformatf("%4d / %5d / %3h", indexA, $signed(indexA), indexA));
        dataTable.newRow();
        dataTable.addCell("Index B");
        dataTable.addCell($sformatf("%4d / %5d / %3h", indexB, $signed(indexB), indexB));
        dataTable.newRow();
        dataTable.addCell("Index C");
        dataTable.addCell($sformatf("%4d / %5d / %3h", indexC, $signed(indexC), indexC));
        dataTable.newRow();
        dataTable.addCell("Index D");
        dataTable.addCell($sformatf("%4d / %5d / %3h", indexD, $signed(indexD), indexD));
        dataTable.newRow();
        dataTable.addCell("Date\(M/D\)");
        dataTable.addCell($sformatf("%2d / %2d", month, day));
        dataTable.newRow();
        dataTable.addCell("Data No.");
        dataTable.addCell($sformatf("%3d", dataNo));
        return dataTable;
    endfunction

    // Dumper
    function void display();
        reportTable dataTable = getTable();
        dataTable.show();
    endfunction

    constraint range{
        this.action inside{actions};
        this.formulaType inside{formulaTypes};
        this.mode inside{modes};
        this.indexA inside{[0:(2**$bits(Index)-1)]};
        this.indexB inside{[0:(2**$bits(Index)-1)]};
        this.indexC inside{[0:(2**$bits(Index)-1)]};
        this.indexD inside{[0:(2**$bits(Index)-1)]};
        this.month inside{[1:12]};
        // this.date.D inside{[1:paramMgr::getNbOfDays(this.date.M)]};
        1 <= this.day;
        this.day <= paramMgr::getNbOfDays(this.month);
        this.dataNo inside{[0:(2**$bits(Data_No)-1)]};
    }

    rand Action action;
    rand Formula_Type formulaType;
    rand Mode mode;
    rand Index indexA;
    rand Index indexB;
    rand Index indexC;
    rand Index indexD;
    rand Month month;
    rand Day day;
    rand Data_No dataNo;

    local logger _logger;

    Action actions[$];
    Formula_Type formulaTypes[$];
    Mode modes[$];
endclass

`endif