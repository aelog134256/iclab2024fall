`ifndef RANDMGR
`define RANDMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
import usertype::*;

class randMgr;
    function new(int seed);
        this.srandom(seed);
        this._logger = new("randMgr");
        this._paramMgr = new();

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

    // Dumper
    function void display();
        reportTable dataTable;
        dataTable = new("Random Data");
        dataTable.defineCol("Data");
        dataTable.defineCol("Value");
        dataTable.newRow();
        dataTable.addCell("Action");
        dataTable.addCell($sformatf("%s", this.action.name()));
        dataTable.newRow();
        dataTable.addCell("Formula type");
        dataTable.addCell($sformatf("%s", this.formulaType.name()));
        dataTable.newRow();
        dataTable.addCell("Mode");
        dataTable.addCell($sformatf("%s", this.mode.name()));
        dataTable.newRow();
        dataTable.addCell("Index A");
        dataTable.addCell($sformatf("%4d / %5d / %3h", this.indexA, $signed(this.indexA), this.indexA));
        dataTable.newRow();
        dataTable.addCell("Index B");
        dataTable.addCell($sformatf("%4d / %5d / %3h", this.indexB, $signed(this.indexB), this.indexB));
        dataTable.newRow();
        dataTable.addCell("Index C");
        dataTable.addCell($sformatf("%4d / %5d / %3h", this.indexC, $signed(this.indexC), this.indexC));
        dataTable.newRow();
        dataTable.addCell("Index D");
        dataTable.addCell($sformatf("%4d / %5d / %3h", this.indexD, $signed(this.indexD), this.indexD));
        dataTable.newRow();
        dataTable.addCell("Date\(M/D\)");
        dataTable.addCell($sformatf("%2d / %2d", this.month, this.day));
        dataTable.newRow();
        dataTable.addCell("Data No.");
        dataTable.addCell($sformatf("%3d", this.dataNo));
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
        // this.date.D inside{[1:_paramMgr.getNbOfDays(this.date.M)]};
        1 <= this.day;
        this.day <= _paramMgr.getNbOfDays(this.month);
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
    local paramMgr _paramMgr;

    Action actions[$];
    Formula_Type formulaTypes[$];
    Mode modes[$];
endclass

`endif