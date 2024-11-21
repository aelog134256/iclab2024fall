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
        $display("[INFO] [%s] - %s", _step, meesage);
    endfunction

    function void error(string meesage, logic isFinish=1);
        $display("[ERROR] [%s] - %s", _step, meesage);
        if(isFinish) begin
            $fatal;
        end
    endfunction

    string _step;
endclass

//======================================
//      Parameter
//======================================
class paramMgr;
    function new();
        this._logger = new("paramMgr");
    endfunction

    // Formula
    static function Index getThreshold(Formula_Type formula, Mode mode);
        Index thresholdTable[formula.num()][2**$bits(Mode)] = '{
            {2047, 1023, 'dx, 511}, //Formula_A
            {800, 400, 'dx, 200},   //Formula_B
            {2047, 1023, 'dx, 511}, //Formula_C
            {3, 2, 'dx, 1},         //Formula_D
            {3, 2, 'dx, 1},         //Formula_E
            {800, 400, 'dx, 200},   //Formula_F
            {800, 400, 'dx, 200},   //Formula_G
            {800, 400, 'dx, 200}    //Formula_H
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

    static function Index calcResult(
        Formula_Type formula,
        Index earlyA, Index earlyB, Index earlyC, Index earlyD, 
        Index todayA, Index todayB, Index todayC, Index todayD
    );
        logic signed[$bits(Index)+2:0] res = 0;
        Index earlyList[4] = {earlyA,earlyB,earlyC,earlyD};
        Index earlyMax[$] = earlyList.max();
        Index earlyMin[$] = earlyList.min();
        Index todayList[4] = {todayA,todayB,todayC,todayD};
        Index absList[4] = {paramMgr::abs(earlyA,todayA),paramMgr::abs(earlyB,todayB),paramMgr::abs(earlyC,todayC),paramMgr::abs(earlyD,todayD)};
        Index tmpList[$];
        case(formula)
            Formula_A: begin
                res = $floor((earlyList.sum() with (int'(item)))/4);
            end
            Formula_B: begin
                res = earlyMax[0] - earlyMin[0];
            end
            Formula_C: begin
                res = earlyMin[0];
            end
            Formula_D: begin
                tmpList = earlyList.find(x) with (x>=2047);
                res = tmpList.size();
            end
            Formula_E: begin
                foreach(earlyList[idx]) begin
                    if(earlyList[idx] >= todayList[idx]) res++;
                end
            end
            Formula_F: begin
                absList.sort();
                res = $floor(int'(absList[0] + absList[1] + absList[2])/3);
            end
            Formula_G: begin
                absList.sort();
                res = int'($floor(absList[0]/2) + $floor(absList[1]/4) + $floor(absList[2]/4));
            end
            Formula_H: begin
                res = $floor((absList.sum() with (int'(item)))/4);
            end
            default: begin
                _logger.error($sformatf("Invalid Formula : %s", formula.name()));
                return -1;
            end
        endcase
        return res;
    endfunction

    static function Index abs(Index A, Index B);
        return (A>B) ? (A-B) : (B-A);
    endfunction

    // Date
    static function Day getNbOfDays(Month month);
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

    static function logic dateIsEarlier(Date a, Date b);
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

    static local logger _logger;
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
        _content[0].push_back(info);
    endfunction

    function void addCell(string info);
        _content[$].push_back(info);
    endfunction

    function void newRow();
        _content.push_back({});
    endfunction

    function string toString();
        string seperator = getSeperator();
        string out = {"\n", seperator};
        string element;
        int size;
        foreach(_content[row]) begin
            out = {out, "\n|"};
            foreach(_content[row][col]) begin
                size = getMaxSizeCol(col) - _content[row][col].len();
                element = size>0 ? {size{" "}} : "";
                element = {element, _content[row][col]};
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
        string out = toString();
        out = {out, "\n"};
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

        // If the number of lines in str1 is less than in str2, add blank lines
        for (int i = str1_lines.size(); i < str2_lines.size(); i++) begin
            str1_lines.push_back({maxSize{" "}});
        end

        // Combine
        while (idx1 < str1_lines.size() || idx2 < str2_lines.size()) begin
            string line1 = (idx1 < str1_lines.size()) ? str1_lines[idx1++] : "";
            string line2 = (idx2 < str2_lines.size()) ? str2_lines[idx2++] : "";

            // result = {result, line1, (line2 != "" ? sep : ""), line2, "\n"};
            result = {result, line1, sep, line2, "\n"};
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
        for(int row=0 ; row<_content.size() ; row++) begin
            size = _content[row][col].len() > size ? _content[row][col].len() : size;
        end
        return size;
    endfunction

    local function string getSeperator();
        string out;
        out = {out, "+"};
        for(int col=0 ; col<_content[0].size() ; col++)begin
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