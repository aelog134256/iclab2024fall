`ifndef DRAMMGR
`define DRAMMGR

`include "Usertype.sv"
`include "../00_TESTBED/utility.sv"
`include "../00_TESTBED/randMgr.sv"
import usertype::*;

class dramMgr;
    function new(int seed);
        this._logger = new("dramMgr");
        this._randMgr = new(seed);
    endfunction

    // Executor
    function void randomizeDramDat(string path);
        int file = $fopen(path, "w");
        for(int id=0 ; id<NUM_OF_STOCK ; ++id)begin
            int addr = START_OF_DRAM_ADDRESS+id*SIZE_OF_STOCK;
            _randMgr.randomize();
            $fwrite(file, "@%5h\n", addr);
            $fwrite(file, "%2h %2h %2h %2h\n",
                _randMgr.day,
                _randMgr.indexD[7:0],
                {_randMgr.indexC[3:0], _randMgr.indexD[11:8]},
                _randMgr.indexC[11:4]
            );
            $fwrite(file, "@%5h\n", addr+4);
            $fwrite(file, "%2h %2h %2h %2h\n",
                _randMgr.month,
                _randMgr.indexB[7:0],
                {_randMgr.indexA[3:0], _randMgr.indexB[11:8]},
                _randMgr.indexA[11:4]
            );
        end
        $fclose(file);
    endfunction

    // Setter
    function void loadDramFromDat(string path);
        $readmemh(path, golden_DRAM);
    endfunction

    function void setDataDir(Data_No id, Data_Dir data);
        int baseAddress = START_OF_DRAM_ADDRESS+id*SIZE_OF_STOCK;
        {golden_DRAM[baseAddress+7], golden_DRAM[baseAddress+6][7:4]} = data.Index_A;
        {golden_DRAM[baseAddress+6][3:0], golden_DRAM[baseAddress+5]} = data.Index_B;
        {golden_DRAM[baseAddress+3], golden_DRAM[baseAddress+2][7:4]} = data.Index_C;
        {golden_DRAM[baseAddress+2][3:0], golden_DRAM[baseAddress+1]} = data.Index_D;
        golden_DRAM[baseAddress+4] = data.M;
        golden_DRAM[baseAddress] = data.D;
    endfunction

    // Getter
    function Data_Dir getDataDir(Data_No id);
        Data_Dir out;
        int baseAddress = START_OF_DRAM_ADDRESS+id*SIZE_OF_STOCK;
        out.Index_A = {golden_DRAM[baseAddress+7], golden_DRAM[baseAddress+6][7:4]};
        out.Index_B = {golden_DRAM[baseAddress+6][3:0], golden_DRAM[baseAddress+5]};
        out.Index_C = {golden_DRAM[baseAddress+3], golden_DRAM[baseAddress+2][7:4]};
        out.Index_D = {golden_DRAM[baseAddress+2][3:0], golden_DRAM[baseAddress+1]};
        out.M = golden_DRAM[baseAddress+4];
        out.D = golden_DRAM[baseAddress];
        return out;
    endfunction

    // Dumper
    function reportTable DataDirToTable(Data_Dir in);
        reportTable dataTable;
        dataTable = new("Data Dir Table");
        dataTable.defineCol("Data");
        dataTable.defineCol("Value");
        dataTable.newRow();
        dataTable.addCell("Index A");
        dataTable.addCell($sformatf("%4d / %3h", in.Index_A, in.Index_A));
        dataTable.newRow();
        dataTable.addCell("Index B");
        dataTable.addCell($sformatf("%4d / %3h", in.Index_B, in.Index_B));
        dataTable.newRow();
        dataTable.addCell("Index C");
        dataTable.addCell($sformatf("%4d / %3h", in.Index_C, in.Index_C));
        dataTable.newRow();
        dataTable.addCell("Index D");
        dataTable.addCell($sformatf("%4d / %3h", in.Index_D, in.Index_D));
        dataTable.newRow();
        dataTable.addCell("Date\(M/D\)");
        dataTable.addCell($sformatf("%2d / %2d", in.M, in.D));
        return dataTable;
    endfunction

    function void dumpDramToFile(string path, int rowPerTable=1);
        int file = $fopen(path, "w");
        string content;
        for(int id=0 ; id<NUM_OF_STOCK ; ++id)begin
            Data_Dir data = getDataDir(id);
            string temp;
            reportTable dataTable;
            dataTable = new("Data Dir table");
            dataTable.defineCol("Data");
            dataTable.defineCol("Value");
            dataTable.newRow();
            dataTable.addCell("Id / Addr");
            dataTable.addCell($sformatf("%3d / %5h", id, START_OF_DRAM_ADDRESS+id*SIZE_OF_STOCK));
            dataTable.newRow();
            dataTable.addCell("Index A");
            dataTable.addCell($sformatf("%4d / %3h", data.Index_A, data.Index_A));
            dataTable.newRow();
            dataTable.addCell("Index B");
            dataTable.addCell($sformatf("%4d / %3h", data.Index_B, data.Index_B));
            dataTable.newRow();
            dataTable.addCell("Index C");
            dataTable.addCell($sformatf("%4d / %3h", data.Index_C, data.Index_C));
            dataTable.newRow();
            dataTable.addCell("Index D");
            dataTable.addCell($sformatf("%4d / %3h", data.Index_D, data.Index_D));
            dataTable.newRow();
            dataTable.addCell("Date\(M/D\)");
            dataTable.addCell($sformatf("%2d / %2d", data.M, data.D));

            if(id%rowPerTable==0) begin
                content = {"[Data_Dir table", $sformatf(" %3d]\n", id)};
                content = {content, dataTable.toString(), "\n\n"};
            end
            else begin
                temp = {"[Data_Dir table", $sformatf(" %3d]\n", id)};
                temp = {temp, dataTable.toString(), "\n\n"};
                content = dataTable.combineStringHorizontal(content, temp, "    ");
                if(id%rowPerTable==rowPerTable-1) begin
                    $fwrite(file, "%s", content);
                    content = "";
                end
            end
        end
        // dump remain content
        if(content != "") begin
            $fwrite(file, "%s", content);
        end
        $fclose(file);
    endfunction

    local logger _logger;
    local randMgr _randMgr;
    local logic [7:0] golden_DRAM [((START_OF_DRAM_ADDRESS+SIZE_OF_STOCK*NUM_OF_STOCK)-1):(START_OF_DRAM_ADDRESS+0)];
endclass

`endif