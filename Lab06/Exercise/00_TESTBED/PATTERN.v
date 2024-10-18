/*
    @debug method : display
        
    @description :
        
    @issue :
        
    @todo :

*/

`ifdef RTL
    `define CYCLE_TIME 6.0
`endif
`ifdef GATE
    `define CYCLE_TIME 6.0
`endif

module PATTERN(
    // Output signals
    clk,
	rst_n,
	in_valid,
    in_data, 
	in_mode,
    // Input signals
    out_valid, 
	out_data
);

//======================================
//      INPUT & OUTPUT
//======================================
output reg clk, rst_n, in_valid;
output reg [8:0] in_mode;
output reg [14:0] in_data;

input out_valid;
input [206:0] out_data;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
parameter SEED = 54871;
// Control the probability of error bit generating
// probability = ERR_NUM/ERR_DEN;
parameter ERR_NUM = 2;
parameter ERR_DEN = 2;
//
parameter DEBUG = 0;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 1000;
parameter OUTNUM = 1;

// PATTERN CONTROL
integer pat;
integer exe_lat;
integer tot_lat;

// String control
// Should use %0s
reg[9*8:1]  reset_color       = "\033[1;0m";
reg[10*8:1] txt_black_prefix  = "\033[1;30m";
reg[10*8:1] txt_red_prefix    = "\033[1;31m";
reg[10*8:1] txt_green_prefix  = "\033[1;32m";
reg[10*8:1] txt_yellow_prefix = "\033[1;33m";
reg[10*8:1] txt_blue_prefix   = "\033[1;34m";

reg[10*8:1] bkg_black_prefix  = "\033[40;1m";
reg[10*8:1] bkg_red_prefix    = "\033[41;1m";
reg[10*8:1] bkg_green_prefix  = "\033[42;1m";
reg[10*8:1] bkg_yellow_prefix = "\033[43;1m";
reg[10*8:1] bkg_blue_prefix   = "\033[44;1m";
reg[10*8:1] bkg_white_prefix  = "\033[47;1m";

//======================================
//      DATA MODEL
//======================================
parameter NUM_OF_MODE = 3;
parameter SIZE_OF_MATRIX = 4;
parameter MAX_SIZE_OF_MAXTRIX = 4;
parameter MIN_SIZE_OF_MAXTRIX = 2;
parameter DATA_BIT = 11;
parameter MODE_BIT = 5;
parameter NUM_OF_DATA_HAMMING_BITS = 4;//$clog2(DATA_BIT)+1;
parameter NUM_OF_MODE_HAMMING_BITS = 4;//$clog2(MODE_BIT)+1;
parameter NUN_OF_ENCODE_DATA = DATA_BIT+NUM_OF_DATA_HAMMING_BITS;
parameter NUN_OF_ENCODE_MODE = MODE_BIT+NUM_OF_MODE_HAMMING_BITS;

reg[DATA_BIT-1:0] _data[SIZE_OF_MATRIX-1:0][SIZE_OF_MATRIX-1:0];
reg[NUN_OF_ENCODE_DATA-1:0] _encodeData[SIZE_OF_MATRIX-1:0][SIZE_OF_MATRIX-1:0];
reg[MODE_BIT-1:0] _mode;
reg[NUN_OF_ENCODE_MODE-1:0] _encodeMode;
integer _windowSize;

reg[206:0] _yourDeterminant;
reg[206:0] _goldDeterminant;
/*
    5'b00100 : 2*2
    5'b00110 : 3*3
    5'b10110 : 4*4
*/

// genvar gen_row, gen_col;
// generate
//     for(gen_row=0 ; gen_row<SIZE_OF_MATRIX ; gen_row=gen_row+1) begin : hcgRow
//         for(gen_col=0 ; gen_col<SIZE_OF_MATRIX ; gen_col=gen_col+1) begin : hcgCol
//             hammingCodeGenerator #(
//                 .SEED(SEED)
//                 ,.IP_BIT(DATA_BIT)
//                 ,.ERR_NUM(ERR_NUM)
//                 ,.ERR_DEN(ERR_DEN)
//                 ) dataHCG();
//         end
//     end
// endgenerate

hammingCodeGenerator #(
    .SEED(SEED)
    ,.IP_BIT(DATA_BIT)
    ,.ERR_NUM(ERR_NUM)
    ,.ERR_DEN(ERR_DEN)
    ) dataHCG();

hammingCodeGenerator #(
     .SEED(SEED)
    ,.IP_BIT(MODE_BIT)
    ,.ERR_NUM(ERR_NUM)
    ,.ERR_DEN(ERR_DEN)
    ) modeHCG();

//
// Operation
//
task cal_determinant; begin
end endtask

//
// Display
//
task show_matrix_and_mode; begin
    $display("[Info] [Mode] : %-b", _mode);
    $display("[Info]    window size : %-d\n", _windowSize);
    
    $display("[Info] [Matrix]\n");

    $display("[Info] [Determinant] : ");
    $display("[Info]    Your determinant : \n%d", _yourDeterminant);
    $display("[Info]    Gold determinant : \n%d\n", _goldDeterminant);
end endtask

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              CLOCK
//======================================
initial clk = 1'b0;
always #(CYCLE/2.0) clk = ~clk;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
    for(pat=0 ; pat<TOTAL_PATNUM ; pat=pat+1) begin
        run_hamming_code_task;
        input_task;
        cal_task;
        wait_task;
        check_task;
        // Print Pass Info and accumulate the total latency
        $display("%0sPASS PATTERN NO.%4d %0sCycles: %3d%0s",txt_blue_prefix, pat, txt_green_prefix, exe_lat, reset_color);
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    in_data = 'dx;
    in_mode = 'dx;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out_data !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) rst_n = 1;
    #(CYCLE/2.0) release clk;
end endtask

task run_hamming_code_task;
    integer _row;
    integer _col;
begin
    // mode
    case({$random(SEED)}%NUM_OF_MODE)
        'd0:begin
            modeHCG.setData('b00100);
            _windowSize = 2;
        end
        'd1:begin
            modeHCG.setData('b00110);
            _windowSize = 3;
        end
        'd2:begin
            modeHCG.setData('b10110);
            _windowSize = 4;
        end
        default:begin
            $display("[ERROR] [RUN HAMMING CODE] Invalid mode : %-b", modeHCG.getOriginalData());
            $finish;
        end
    endcase
    modeHCG.run();
    _mode = modeHCG.getOriginalData();
    _encodeMode = modeHCG.getEncodeDataWithErr();

    // matrix
    for(_row=0 ; _row<SIZE_OF_MATRIX ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_MATRIX ; _col=_col+1) begin
            dataHCG.randomize_data();
            dataHCG.run();
            _data[_row][_col] = dataHCG.getOriginalData();
            _encodeData[_row][_col] = dataHCG.getEncodeDataWithErr();
        end
    end
end endtask

task input_task;
    integer _row;
    integer _col;
begin
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
    for(_row=0 ; _row<SIZE_OF_MATRIX ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_MATRIX ; _col=_col+1) begin
            in_valid = 1;
            // mode
            if(_row===0 && _col===0) in_mode = _encodeMode;
            else in_mode = 'dx;
            // data
            in_data = _encodeData[_row][_col];
            
            @(negedge clk);
        end
    end
    in_valid = 0;
    in_mode = 'dx;
    in_data = 'dx;
end endtask

task cal_task; begin
    cal_determinant;
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out_data !== 0) begin
            $display("[ERROR] [WAIT] Output signal should be 0 at %-12d ps  ", $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end
        if(exe_lat == DELAY) begin
            $display("[ERROR] [WAIT] The execution latency at %-12d ps is over %5d cycles  ", $time*1000, DELAY);
            repeat(5) @(negedge clk);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk);
    end
end endtask

task check_task;
    integer out_lat;
begin
    out_lat = 0;
    while(out_valid===1) begin
        if(out_lat==OUTNUM) begin
            $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUTNUM, $time*1000);
            repeat(5) @(negedge clk);
            $finish;
        end

        _yourDeterminant = out_data;

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    if(out_lat<OUTNUM) begin
        $display("[ERROR] [OUTPUT] Out cycles is less than %3d at %-12d ps", OUTNUM, $time*1000);
        repeat(5) @(negedge clk);
        $finish;
    end

    if(_yourDeterminant !== _goldDeterminant) begin
        $display("[ERROR] [OUTPUT] Out is not correct\n");
        show_matrix_and_mode;
        repeat(5) @(negedge clk);
        $finish;
    end

    tot_lat = tot_lat + exe_lat;
end endtask

task pass_task; begin
    $display("\033[1;33m                `oo+oy+`                            \033[1;35m Congratulation!!! \033[1;0m                                   ");
    $display("\033[1;33m               /h/----+y        `+++++:             \033[1;35m PASS This Lab........Maybe \033[1;0m                          ");
    $display("\033[1;33m             .y------:m/+ydoo+:y:---:+o             \033[1;35m Total Latency : %-10d\033[1;0m                                ", tot_lat);
    $display("\033[1;33m              o+------/y--::::::+oso+:/y                                                                                     ");
    $display("\033[1;33m              s/-----:/:----------:+ooy+-                                                                                    ");
    $display("\033[1;33m             /o----------------/yhyo/::/o+/:-.`                                                                              ");
    $display("\033[1;33m            `ys----------------:::--------:::+yyo+                                                                           ");
    $display("\033[1;33m            .d/:-------------------:--------/--/hos/                                                                         ");
    $display("\033[1;33m            y/-------------------::ds------:s:/-:sy-                                                                         ");
    $display("\033[1;33m           +y--------------------::os:-----:ssm/o+`                                                                          ");
    $display("\033[1;33m          `d:-----------------------:-----/+o++yNNmms                                                                        ");
    $display("\033[1;33m           /y-----------------------------------hMMMMN.                                                                      ");
    $display("\033[1;33m           o+---------------------://:----------:odmdy/+.                                                                    ");
    $display("\033[1;33m           o+---------------------::y:------------::+o-/h                                                                    ");
    $display("\033[1;33m           :y-----------------------+s:------------/h:-:d                                                                    ");
    $display("\033[1;33m           `m/-----------------------+y/---------:oy:--/y                                                                    ");
    $display("\033[1;33m            /h------------------------:os++/:::/+o/:--:h-                                                                    ");
    $display("\033[1;33m         `:+ym--------------------------://++++o/:---:h/                                                                     ");
    $display("\033[1;31m        `hhhhhoooo++oo+/:\033[1;33m--------------------:oo----\033[1;31m+dd+                                                 ");
    $display("\033[1;31m         shyyyhhhhhhhhhhhso/:\033[1;33m---------------:+/---\033[1;31m/ydyyhs:`                                              ");
    $display("\033[1;31m         .mhyyyyyyhhhdddhhhhhs+:\033[1;33m----------------\033[1;31m:sdmhyyyyyyo:                                            ");
    $display("\033[1;31m        `hhdhhyyyyhhhhhddddhyyyyyo++/:\033[1;33m--------\033[1;31m:odmyhmhhyyyyhy                                            ");
    $display("\033[1;31m        -dyyhhyyyyyyhdhyhhddhhyyyyyhhhs+/::\033[1;33m-\033[1;31m:ohdmhdhhhdmdhdmy:                                           ");
    $display("\033[1;31m         hhdhyyyyyyyyyddyyyyhdddhhyyyyyhhhyyhdhdyyhyys+ossyhssy:-`                                                           ");
    $display("\033[1;31m         `Ndyyyyyyyyyyymdyyyyyyyhddddhhhyhhhhhhhhy+/:\033[1;33m-------::/+o++++-`                                            ");
    $display("\033[1;31m          dyyyyyyyyyyyyhNyydyyyyyyyyyyhhhhyyhhy+/\033[1;33m------------------:/ooo:`                                         ");
    $display("\033[1;31m         :myyyyyyyyyyyyyNyhmhhhyyyyyhdhyyyhho/\033[1;33m-------------------------:+o/`                                       ");
    $display("\033[1;31m        /dyyyyyyyyyyyyyyddmmhyyyyyyhhyyyhh+:\033[1;33m-----------------------------:+s-                                      ");
    $display("\033[1;31m      +dyyyyyyyyyyyyyyydmyyyyyyyyyyyyyds:\033[1;33m---------------------------------:s+                                      ");
    $display("\033[1;31m      -ddhhyyyyyyyyyyyyyddyyyyyyyyyyyhd+\033[1;33m------------------------------------:oo              `-++o+:.`             ");
    $display("\033[1;31m       `/dhshdhyyyyyyyyyhdyyyyyyyyyydh:\033[1;33m---------------------------------------s/            -o/://:/+s             ");
    $display("\033[1;31m         os-:/oyhhhhyyyydhyyyyyyyyyds:\033[1;33m----------------------------------------:h:--.`      `y:------+os            ");
    $display("\033[1;33m         h+-----\033[1;31m:/+oosshdyyyyyyyyhds\033[1;33m-------------------------------------------+h//o+s+-.` :o-------s/y  ");
    $display("\033[1;33m         m:------------\033[1;31mdyyyyyyyyymo\033[1;33m--------------------------------------------oh----:://++oo------:s/d  ");
    $display("\033[1;33m        `N/-----------+\033[1;31mmyyyyyyyydo\033[1;33m---------------------------------------------sy---------:/s------+o/d  ");
    $display("\033[1;33m        .m-----------:d\033[1;31mhhyyyyyyd+\033[1;33m----------------------------------------------y+-----------+:-----oo/h  ");
    $display("\033[1;33m        +s-----------+N\033[1;31mhmyyyyhd/\033[1;33m----------------------------------------------:h:-----------::-----+o/m  ");
    $display("\033[1;33m        h/----------:d/\033[1;31mmmhyyhh:\033[1;33m-----------------------------------------------oo-------------------+o/h  ");
    $display("\033[1;33m       `y-----------so /\033[1;31mNhydh:\033[1;33m-----------------------------------------------/h:-------------------:soo  ");
    $display("\033[1;33m    `.:+o:---------+h   \033[1;31mmddhhh/:\033[1;33m---------------:/osssssoo+/::---------------+d+//++///::+++//::::::/y+`  ");
    $display("\033[1;33m   -s+/::/--------+d.   \033[1;31mohso+/+y/:\033[1;33m-----------:yo+/:-----:/oooo/:----------:+s//::-.....--:://////+/:`    ");
    $display("\033[1;33m   s/------------/y`           `/oo:--------:y/-------------:/oo+:------:/s:                                                 ");
    $display("\033[1;33m   o+:--------::++`              `:so/:-----s+-----------------:oy+:--:+s/``````                                             ");
    $display("\033[1;33m    :+o++///+oo/.                   .+o+::--os-------------------:oy+oo:`/o+++++o-                                           ");
    $display("\033[1;33m       .---.`                          -+oo/:yo:-------------------:oy-:h/:---:+oyo                                          ");
    $display("\033[1;33m                                          `:+omy/---------------------+h:----:y+//so                                         ");
    $display("\033[1;33m                                              `-ys:-------------------+s-----+s///om                                         ");
    $display("\033[1;33m                                                 -os+::---------------/y-----ho///om                                         ");
    $display("\033[1;33m                                                    -+oo//:-----------:h-----h+///+d                                         ");
    $display("\033[1;33m                                                       `-oyy+:---------s:----s/////y                                         ");
    $display("\033[1;33m                                                           `-/o+::-----:+----oo///+s                                         ");
    $display("\033[1;33m                                                               ./+o+::-------:y///s:                                         ");
    $display("\033[1;33m                                                                   ./+oo/-----oo/+h                                          ");
    $display("\033[1;33m                                                                       `://++++syo`                                          ");
    $display("\033[1;0m"); 
    repeat(5) @(negedge clk);
    $finish;
end endtask

endmodule

//================================================================================================================

//======================================
//
//
//      Hamming Code Generator
//
//
//======================================
module hammingCodeGenerator #(
    parameter SEED = 5487,
    parameter IP_BIT = 8,
    parameter ERR_NUM = 2,
    parameter ERR_DEN = 2
);

//======================================
//      INPUT & OUTPUT
//======================================
parameter DISPLAY_ELEMENT_SIZE = 3;
parameter DISPLAY_NUM_OF_SPACE = 2;
parameter DISPLAY_NUM_OF_SEP   = 2;
parameter NUM_OF_HAMMING_BITS = $clog2(IP_BIT)+1;
parameter SIZE_OF_ENCODE_DATE = IP_BIT+NUM_OF_HAMMING_BITS;

// Encode
reg[IP_BIT-1:0] _data = 'dx;
reg[NUM_OF_HAMMING_BITS-1:0] _encodeTable[SIZE_OF_ENCODE_DATE:1];
reg[NUM_OF_HAMMING_BITS-1:0] _hammingCode;
reg[SIZE_OF_ENCODE_DATE-1:0] _encodeData;
reg[SIZE_OF_ENCODE_DATE-1:0] _encodeDataWithErr;
integer errPos = -1;

// Decode
reg[NUM_OF_HAMMING_BITS-1:0] _decodeTable[SIZE_OF_ENCODE_DATE:1];
reg[NUM_OF_HAMMING_BITS-1:0] _decodeResult;

//
// Setter
//
task setData;
    input reg[IP_BIT-1:0] _in;
begin
    _data = _in;
end endtask

//
// Getter
//
function[IP_BIT-1:0] getOriginalData; begin
    getOriginalData = _data;
end endfunction

function[SIZE_OF_ENCODE_DATE-1:0] getEncodeData; begin
    getEncodeData = _encodeData;
end endfunction

function[SIZE_OF_ENCODE_DATE-1:0] getEncodeDataWithErr; begin
    getEncodeDataWithErr = _encodeDataWithErr;
end endfunction

//
// Operation
//
task randomize_data; begin
    _data = {$random(SEED)};
    errPos = -1;
end endtask

task run; begin
    if(^_data === 1'bx) begin
        $display("[ERROR] [HCG] The original data should be randomized or set by user first");
        $finish;
    end
    generate_encode_table;
    combine_hamming_code;
    randomize_error_bit;
    generate_decode_table;
end endtask

task generate_encode_table;
    integer _bit;
    integer _tableCnt;
begin
    // table
    _tableCnt = 0;
    for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
        if(!isPowerOf2(_bit)) begin
            // data[]==1 => generate hamming code
            if(_data[IP_BIT-_tableCnt-1]) begin
                _encodeTable[_bit] = _bit;
            end
            // Increase the count to select the table index
            _tableCnt = _tableCnt+1;
        end
    end
end endtask

task combine_hamming_code;
    integer _bit;
    integer _hammingBit;
    integer _tableCnt;
begin
    // hamming code
    _hammingCode = 0;
    _tableCnt = 0;
    for(_hammingBit=0 ; _hammingBit<NUM_OF_HAMMING_BITS ; _hammingBit=_hammingBit+1) begin
        for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
            if(!isPowerOf2(_bit)) begin
                // data[]==1 => generate hamming code
                if(_data[IP_BIT-_tableCnt-1]) begin
                    _hammingCode[_hammingBit] = _hammingCode[_hammingBit] ^ _encodeTable[_bit][_hammingBit];
                end
                // Increase the count to select the table index
                _tableCnt = _tableCnt+1;
            end
        end
    end

    _tableCnt = 0;
    for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
        if(isPowerOf2(_bit)) begin
            _encodeData[SIZE_OF_ENCODE_DATE-_bit] = _hammingCode[$clog2(_bit)];
        end
        else begin
            _encodeData[SIZE_OF_ENCODE_DATE-_bit] = _data[IP_BIT-_tableCnt-1];
            _tableCnt = _tableCnt+1;
        end
    end

end endtask

task randomize_error_bit; begin
    _encodeDataWithErr = _encodeData;
    if({$random(SEED)} % ERR_DEN < ERR_NUM) begin
        // index : 1 ~ SIZE_OF_ENCODE_DATE
        // bit   : (SIZE_OF_ENCODE_DATE-1) ~ 0
        errPos = {$random(SEED)} % SIZE_OF_ENCODE_DATE + 1;
        _encodeDataWithErr[SIZE_OF_ENCODE_DATE-errPos] = ~_encodeDataWithErr[SIZE_OF_ENCODE_DATE-errPos];
    end
end endtask

task generate_decode_table;
    integer _bit;
    integer _hammingBit;
    integer _tableCnt;
begin
    // table
    _tableCnt = 0;
    for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
        if(_encodeDataWithErr[SIZE_OF_ENCODE_DATE-_bit]) begin
            _decodeTable[_bit] = _bit;
        end
    end

    // find error
    _decodeResult = 0;
    _tableCnt = 0;
    for(_hammingBit=0 ; _hammingBit<NUM_OF_HAMMING_BITS ; _hammingBit=_hammingBit+1) begin
        for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
            if(_encodeDataWithErr[SIZE_OF_ENCODE_DATE-_bit]) begin
                _decodeResult[_hammingBit] = _decodeResult[_hammingBit] ^ _decodeTable[_bit][_hammingBit];
            end
        end
    end
end endtask

//
// Display
//
task display_seperator;
    input integer _num;
    integer _idx;
    reg[(DISPLAY_ELEMENT_SIZE+DISPLAY_NUM_OF_SPACE+DISPLAY_NUM_OF_SEP)*8:1] _line; // 4 = 2 spaces with 2 "+"
begin
    _line = "";
    for(_idx=1 ; _idx<=DISPLAY_ELEMENT_SIZE+2 ; _idx=_idx+1) begin
        _line = {_line, "-"};
    end
    _line = {_line, "+"};
    $write("+");
    for(_idx=0 ; _idx<_num ; _idx=_idx+1) $write("%0s", _line);
    $write("\n");
end endtask

task display_element;
    input reg[DISPLAY_ELEMENT_SIZE*8:1] _in;
    input reg _isStart;
    reg[(DISPLAY_ELEMENT_SIZE+DISPLAY_NUM_OF_SPACE+DISPLAY_NUM_OF_SEP)*8:1] _line;
begin
    _line = _isStart ? "| " : " ";
    _line = {_line, _in};
    _line = {_line, " |"};
    $write("%0s", _line);
end endtask

task show_encode_processing;
    integer _idx;
    integer _bit;
    integer _tableCnt;

    reg[DISPLAY_ELEMENT_SIZE*8:1] _str;
begin
    // data
    $display("[Info] Show the hamming encoding processing\n");
    $display("[Info] [Original data] :");
    $display("[Info]    # of bits : %-3d", IP_BIT);
    $display("[Info]         data : %-b\n", _data);

    $display("[Info] bit table of original data :\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("idx", 1);
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        $sformat(_str, "%3d", _idx);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("bit", 1);
    _tableCnt = 0;
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        if(!isPowerOf2(_idx)) begin
            $sformat(_str, "%3d", _data[IP_BIT-_tableCnt-1]);
            display_element(_str, 0);
            // Increase the count to select the table index
            _tableCnt = _tableCnt+1;
        end
        else begin
            display_element("  X", 0);
        end
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);
    $write("\n");

    // Hamming code table
    $display("[Info] [Hamming code] :");
    $display("[Info]    # of bits : %-3d\n", NUM_OF_HAMMING_BITS);


    $display("[Info] [Hamming encode table] :\n");
    
    display_seperator(NUM_OF_HAMMING_BITS+1);

    display_element("   ", 1);
    for(_idx=NUM_OF_HAMMING_BITS-1 ; _idx>=0 ; _idx=_idx-1) begin
        $sformat(_str, "%3d", 2**_idx);
        display_element(_str, 0);
    end
    $write("\n");
   
    display_seperator(NUM_OF_HAMMING_BITS+1);

    _tableCnt = 0;
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        if(!isPowerOf2(_idx)) begin
            if(_data[IP_BIT-_tableCnt-1]) begin
                $sformat(_str, "%3d", _idx);
                display_element(_str, 1);
                for(_bit=NUM_OF_HAMMING_BITS-1 ; _bit>=0 ; _bit=_bit-1) begin
                    $sformat(_str, "%3d", _encodeTable[_idx][_bit]);
                    display_element(_str, 0);
                end
                $write("\n");
            end
            // Increase the count to select the table index
            _tableCnt = _tableCnt+1;
        end
    end

    display_seperator(NUM_OF_HAMMING_BITS+1);

    display_element("   ", 1);
    for(_idx=NUM_OF_HAMMING_BITS-1 ; _idx>=0 ; _idx=_idx-1) begin
        $sformat(_str, "%3d", _hammingCode[_idx]);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(NUM_OF_HAMMING_BITS+1);
    $write("\n");


    // Encoded data
    $display("[Info] [Encoded data] :");
    $display("[Info]    # of bits : %-3d", SIZE_OF_ENCODE_DATE);
    $display("[Info]         data : %-b\n", _encodeData);

    $display("[Info] bit table of encoded data :\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("idx", 1);
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        $sformat(_str, "%3d", _idx);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("bit", 1);
    _tableCnt = 0;
    for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
        $sformat(_str, "%3d", _encodeData[SIZE_OF_ENCODE_DATE-_bit]);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);
    $write("\n");

    // Error data
    if(errPos === -1) begin
        $display("[Info] This pattern doesn't have error bit in the encoded data\n");
    end
    else begin
        $display("[Info] [Encoded data with error] :");
        $display("[Info]    position : %-3d", errPos);
        $display("[Info]        data : %-b\n", _encodeDataWithErr);
    end

end endtask

task show_decode_processing;
    integer _idx;
    integer _bit;
    integer _tableCnt;

    reg[DISPLAY_ELEMENT_SIZE*8:1] _str;
begin
    $display("[Info] [Encoded data with error] : %-b\n", _encodeDataWithErr);

    if(errPos === -1) begin
        $display("[Info] This pattern doesn't have error bit in the encoded data\n");
    end
    else begin
        $display("[Info] Error position : %-3d\n", errPos);
    end

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("idx", 1);
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        $sformat(_str, "%3d", _idx);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);

    display_element("bit", 1);
    _tableCnt = 0;
    for(_bit=1 ; _bit<=SIZE_OF_ENCODE_DATE ; _bit=_bit+1) begin
        $sformat(_str, "%3d", _encodeDataWithErr[SIZE_OF_ENCODE_DATE-_bit]);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(SIZE_OF_ENCODE_DATE+1);
    $write("\n");

    $display("[Info] [Hamming decode table] :\n");
    
    display_seperator(NUM_OF_HAMMING_BITS+1);

    display_element("   ", 1);
    for(_idx=NUM_OF_HAMMING_BITS-1 ; _idx>=0 ; _idx=_idx-1) begin
        $sformat(_str, "%3d", 2**_idx);
        display_element(_str, 0);
    end
    $write("\n");
   
    display_seperator(NUM_OF_HAMMING_BITS+1);

    _tableCnt = 0;
    for(_idx=1 ; _idx<=SIZE_OF_ENCODE_DATE ; _idx=_idx+1) begin
        if(_encodeDataWithErr[SIZE_OF_ENCODE_DATE-_idx]) begin
            $sformat(_str, "%3d", _idx);
            display_element(_str, 1);
            for(_bit=NUM_OF_HAMMING_BITS-1 ; _bit>=0 ; _bit=_bit-1) begin
                $sformat(_str, "%3d", _decodeTable[_idx][_bit]);
                display_element(_str, 0);
            end
            $write("\n");
        end
    end

    display_seperator(NUM_OF_HAMMING_BITS+1);

    display_element("   ", 1);
    for(_idx=NUM_OF_HAMMING_BITS-1 ; _idx>=0 ; _idx=_idx-1) begin
        $sformat(_str, "%3d", _decodeResult[_idx]);
        display_element(_str, 0);
    end
    $write("\n");

    display_seperator(NUM_OF_HAMMING_BITS+1);
    $write("\n");
end endtask

//
// Utility
//
function isPowerOf2;
    input integer _numOfBits;
begin
    isPowerOf2 = 0;
    if((2**$clog2(_numOfBits) - _numOfBits) === 0) isPowerOf2 = 1;
end endfunction


endmodule