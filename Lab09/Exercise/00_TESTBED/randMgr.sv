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
        string info = "[Random Info]\n";
        info = {info, $sformatf("    * Action : %s\n", this.action)};
        info = {info, $sformatf("    * Formula type : %s\n", this.formulaType)};
        info = {info, $sformatf("    * Mode : %s\n", this.mode)};
        info = {info, $sformatf("    * Index A : %d / %d\n", this.indexA, $signed(this.indexA))};
        info = {info, $sformatf("    * Index B : %d / %d\n", this.indexB, $signed(this.indexB))};
        info = {info, $sformatf("    * Index C : %d / %d\n", this.indexC, $signed(this.indexC))};
        info = {info, $sformatf("    * Index D : %d / %d\n", this.indexD, $signed(this.indexD))};
        info = {info, $sformatf("    * Date\(M/D\) : %2d/%2d\n", this.month, this.day)};
        info = {info, $sformatf("    * Data No. : %d\n", this.dataNo)};
        _logger.info(info);
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