`define CYCLE_TIME 10.0

`include "../00_TESTBED/pseudo_DRAM.v"

`define DRAM_DAT_FILE_NAME "../00_TESTBED/DRAM/dram.dat"

module PATTERN(
    // Input Signals
    clk,
    rst_n,
    in_valid,
    in_pic_no,
    in_mode,
    in_ratio_mode,
    out_valid,
    out_data
);

//======================================
//      INPUT & OUTPUT
//======================================
output reg       clk, rst_n;
output reg       in_valid;

output reg [3:0] in_pic_no;
output reg       in_mode;
output reg [1:0] in_ratio_mode;

input out_valid;
input [7:0] out_data;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
// -------------------------------------
// [Simple pattern]
//      1. data will be range in -5~5
//      2. There is no error 
integer   SIMPLE_PATNUM = 10;
// -------------------------------------
// -------------------------------------
// [Mode]
//      0 : generate the simple dram.dat
//      1 : generate the regular dram.dat
//      2 : validate design
integer   MODE = 2;
// -------------------------------------
integer   SEED = 5487;
parameter DEBUG = 0;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 20000;
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
// Input
parameter NUM_OF_MODE = 2;
parameter NUM_OF_RATIO = 4;
// Image
parameter NUM_OF_PIC = 16;
parameter NUM_OF_CHANNEL = 3; // (R, G, B)
parameter SIZE_OF_PIC = 32;
parameter START_OF_DRAM_ADDRESS = 65536;
parameter BITS_OF_PIXEL = 8;
// Dump
parameter DUMP_ELEMENT_SIZE = 4;
parameter DUMP_NUM_OF_SPACE = 2;
parameter DUMP_NUM_OF_SEP = 2;
// Data
reg[BITS_OF_PIXEL-1:0] _image[NUM_OF_PIC-1:0][NUM_OF_CHANNEL-1:0][SIZE_OF_PIC-1:0][SIZE_OF_PIC-1:0];
integer _noPic;
integer _mode;
integer _ratio;

//
// Load
//
task load_pic_from_dram;
    integer file;
    integer status;
    integer val;
    integer _cnt;
    integer _pic;
    integer _ch;
    integer _row;
    integer _col;
begin
    file = $fopen(`d_DRAM_p_r, "r");
    if (file == 0) begin
        $display("[ERROR] [FILE] The file (%0s) can't be opened", `d_DRAM_p_r);
        $finish;
    end
    _cnt = 0;
    _pic = 0;
    _ch  = 0;
    _row = 0;
    _col = 0;
    while(!$feof(file))begin
        // Address
        status = $fscanf(file, "@%h", val);
        // Pixel
        status = $fscanf(file, "%2h", val);
        if (status == 1) begin
            _image[_pic][_ch][_row][_col] = val;
            _cnt = _cnt + 1;
        end
        _pic = (_cnt/(SIZE_OF_PIC*SIZE_OF_PIC*NUM_OF_CHANNEL))%NUM_OF_PIC;
        _ch  = (_cnt/(SIZE_OF_PIC*SIZE_OF_PIC))%NUM_OF_CHANNEL;
        _row = (_cnt/SIZE_OF_PIC)%SIZE_OF_PIC;
        _col = _cnt%SIZE_OF_PIC;
    end
    $fclose(file);
end endtask

//
// Dump
//
task fwrite_new_line;
    input integer file;
begin
    $fwrite(file, "\n");
end endtask

task fwrite_seperator;
    input integer file;
    input integer _num;
    integer _idx;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line; // 4 = 2 spaces with 2 "+"
begin
    _line = "";
    for(_idx=1 ; _idx<=DUMP_ELEMENT_SIZE+2 ; _idx=_idx+1) begin
        _line = {_line, "-"};
    end
    _line = {_line, "+"};
    $fwrite(file, "+");
    for(_idx=0 ; _idx<_num ; _idx=_idx+1) $fwrite(file, "%0s", _line);
    $fwrite(file, "\n");
end endtask

task fwrite_element;
    input integer file;
    input reg[DUMP_ELEMENT_SIZE*8:1] _in;
    input reg _isStart;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line;
begin
    _line = _isStart ? "| " : " ";
    _line = {_line, _in};
    _line = {_line, " |"};
    $fwrite(file, "%0s", _line);
end endtask

task dump_image;
    integer _ch;
    integer _row;
    integer _col;
begin

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
    case(MODE)
        'd0, 'd1: generate_dram_task;
        'd2: validate_design_task;
        default: begin
            $display("[ERROR] [PARAMETER] Mode (%-d) isn't valid...", MODE);
            $finish;
        end
    endcase
end endtask

task generate_dram_task;
    integer file;
    integer _pic;
    integer _ch;
    integer _row;
    integer _col;
begin
    $display("[Info] Start to generate dram.dat");
    file = $fopen(`DRAM_DAT_FILE_NAME, "w");
    if (file == 0) begin
        $display("[ERROR] [FILE] The file (%0s) can't be opened", `DRAM_DAT_FILE_NAME);
        $finish;
    end
    for(_pic=0 ; _pic<NUM_OF_PIC ; _pic=_pic+1) begin
        $fwrite(file, "@%-5h\n",
            START_OF_DRAM_ADDRESS+_pic*NUM_OF_CHANNEL*SIZE_OF_PIC*SIZE_OF_PIC);
        for(_ch=0 ; _ch<NUM_OF_CHANNEL ; _ch=_ch+1) begin
            for(_row=0 ; _row<SIZE_OF_PIC ; _row=_row+1) begin
                for(_col=0 ; _col<SIZE_OF_PIC ; _col=_col+1) begin
                    if(MODE == 0) $fwrite(file, "%02h ", {$random(SEED)} % 26); // simple
                    else          $fwrite(file, "%02h ", {$random(SEED)} % 2**BITS_OF_PIXEL); // regular
                end
                $fwrite(file, "\n");
            end
            $fwrite(file, "\n");
        end
    end
    $fclose(file);
    $finish;
end endtask

task validate_design_task; begin
    reset_task;
    load_pic_from_dram;
    for(pat=0 ; pat<TOTAL_PATNUM ; pat=pat+1) begin
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
    in_pic_no = 'dx;
    in_mode = 'dx;
    in_ratio_mode = 'dx;

    tot_lat = 0;

    repeat(5) #(CYCLE/2.0) rst_n = 0;
    repeat(5) #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out_data !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) release clk;
end endtask

task input_task; begin
    repeat(2) @(negedge clk);
    _noPic = {$random(SEED)} % NUM_OF_PIC;
    _mode = {$random(SEED)} % NUM_OF_MODE;
    _ratio = (_mode == 1) ? {$random(SEED)} % NUM_OF_RATIO : 'dx;

    in_valid = 1;
    in_pic_no = _noPic;
    in_mode = _mode;
    in_ratio_mode = (_mode == 1) ? _ratio : 'dx;
    @(negedge clk);
    in_valid = 0;
    in_pic_no = 'dx;
    in_mode = 'dx;
    in_ratio_mode = 'dx;
end endtask

task cal_task; begin
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

        // TODO

        out_lat = out_lat + 1;
        @(negedge clk);
    end
    if(out_lat<OUTNUM) begin
        $display("[ERROR] [OUTPUT] Out cycles is less than %3d at %-12d ps", OUTNUM, $time*1000);
        repeat(5) @(negedge clk);
        $finish;
    end

    // TODO

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
