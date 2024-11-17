`ifndef UTILITY
`define UTILITY

`include "Usertype.sv"
import usertype::*;

//======================================
//      Parameter
//======================================
parameter START_OF_DRAM_ADDRESS = 65536;
parameter SIZE_OF_STOCK = 8;
parameter NUM_OF_STOCK = 256;

//======================================
//      Logger
//======================================
class logger;
    function new(string step);
        this._step = step;
    endfunction

    function void info(string meesage);
        $display("[INFO] [%s] - %s", this._step, meesage);
    endfunction

    function void error(string meesage, logic isFinish=1);
        $display("[ERROR] [%s] - %s", this._step, meesage);
        if(isFinish) begin
            $fatal;
        end
    endfunction

    string _step;
endclass

//======================================
//      Parameter
//======================================
// TODO : Static method
class paramMgr;
    function new();
        this._logger = new("paramMgr");
    endfunction

    function Day getNbOfDays(Month month);
        case(month)
            1, 3, 5, 7, 8, 10, 12:
                return 31;
            4, 6, 9, 11:
                return 30;
            2:
                return 28;
            default: begin
                _logger.error($sformatf("Invalid Month : %d", month));
                return 28;
            end
        endcase
    endfunction

    function Index getThreshold(Formula_Type formula, Mode mode);
        Index thresholdTable[formula.num()][mode.num()] = '{
            {2047, 1023, 511}, //Formula_A
            {800, 400, 200},   //Formula_B
            {2047, 1023, 511}, //Formula_C
            {3, 2, 1},         //Formula_D
            {3, 2, 1},         //Formula_E
            {800, 400, 200},   //Formula_F
            {800, 400, 200},   //Formula_G
            {800, 400, 200}    //Formula_H
        };
        if (
            formula inside {
                Formula_A, Formula_B,
                Formula_C, Formula_D,
                Formula_E, Formula_F,
                Formula_G, Formula_H } &&
            mode inside {Insensitive, Normal, Sensitive}) begin
            return thresholdTable[formula][mode];
        end
        else begin
            _logger.error($sformatf("Invalid Formula or Mode: %s, %s", formula.name(), mode.name()));
            return -1;
        end
    endfunction

    function logic dateIsEarlier(Date a, Date b);
        if(a.M < b.M) begin
            return 1;
        end
        else if(a.M > b.M) begin
            return 0;
        end
        else begin
            if(a.D < b.D) begin
                return 1;
            end
            else if(a.D > b.D) begin
                return 0;
            end
            else begin
                return 0;
            end
        end
    endfunction

    local logger _logger;
endclass

//======================================
//      Report Table
//======================================
class reportTable;
    function new(string name);
        this._content = '{{}};
        this._logger = new(name);
    endfunction
    
    function void defineCol(string info);
        this._content[0].push_back(info);
    endfunction

    function void addCell(string info);
        this._content[$].push_back(info);
    endfunction

    function void newRow();
        this._content.push_back({});
    endfunction

    function string getTable();
        string seperator = getSeperator();
        string out = {"\n", seperator};
        string element;
        int size;
        foreach(this._content[row]) begin
            out = {out, "\n|"};
            foreach(this._content[row][col]) begin
                size = getMaxSizeCol(col) - this._content[row][col].len();
                element = size>0 ? {size{" "}} : "";
                element = {element, this._content[row][col]};
                out = {out, " "};
                out = {out, element};
                out = {out, " |"};
            end
            out = {out, "\n"};
            out = {out, seperator};
        end
        return out;
    endfunction

    function void show();
        string out = getTable();
        _logger.info(out);
    endfunction

    function string combineStringHorizontal(string str1, string str2, string sep=" ");
        string str1_lines[$] = split(str1, "\n");
        string str2_lines[$] = split(str2, "\n");
        string result;
        int idx1=0, idx2=0;
        int maxSize=0;

        // Find the maximum size
        foreach (str1_lines[i]) begin
            if (str1_lines[i].len() > maxSize) begin
                maxSize = str1_lines[i].len();
            end
        end

        // Append space to the max size
        foreach (str1_lines[i]) begin
            str1_lines[i] = {str1_lines[i], {(maxSize - str1_lines[i].len()){" "}}};
        end

        // Combine
        while (idx1 < str1_lines.size() || idx2 < str2_lines.size()) begin
            string line1 = (idx1 < str1_lines.size()) ? str1_lines[idx1++] : "";
            string line2 = (idx2 < str2_lines.size()) ? str2_lines[idx2++] : "";

            result = {result, line1, (line2 != "" ? sep : ""), line2, "\n"};
        end
        return result;
    endfunction

    // Utitlity
    typedef string string_queue[$];
    function string_queue split(string str, string sep="\n");
        string list[$];
        int pos = 0;
        int findIdx = 0;
        while(pos < str.len()) begin
            for(findIdx=pos ; findIdx<str.len()-sep.len()+1 ; findIdx++) begin
                if(str.substr(findIdx, findIdx+sep.len()-1)==sep) begin
                    break;
                end
            end
            list.push_back(str.substr(pos, findIdx-1));
            pos = findIdx + sep.len();
        end
        return list;
    endfunction

    local function int getMaxSizeCol(int col);
        int size = 0;
        for(int row=0 ; row<this._content.size() ; row++) begin
            size = this._content[row][col].len() > size ? this._content[row][col].len() : size;
        end
        return size;
    endfunction

    local function string getSeperator();
        string out;
        out = {out, "+"};
        for(int col=0 ; col<this._content[0].size() ; col++)begin
            int size = getMaxSizeCol(col);
            for(int i=0 ; i<size+2 ; i++)begin
                out = {out, "-"};
            end
            out = {out, "+"};
        end
        return out;
    endfunction

    local string _content[$][$];
    local logger _logger;
endclass

`endif