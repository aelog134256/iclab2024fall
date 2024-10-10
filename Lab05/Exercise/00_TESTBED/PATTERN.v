/*
    @debug method : dump file
        
    @description :
        
    @issue :
        
    @todo :
        
*/

`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif
`ifdef POST
    `define CYCLE_TIME 20.0
`endif

module PATTERN(
    // Output signals
    clk,
	rst_n,
	
	in_valid,
	in_valid2,
	
    image,
	template,
	image_size,
	action,

    // Input signals
	out_valid,
	out_value
);

//======================================
//      INPUT & OUTPUT
//======================================
// Output
output reg       clk, rst_n;
output reg       in_valid;
output reg       in_valid2;

output reg [7:0] image;
output reg [7:0] template;
output reg [1:0] image_size;
output reg [2:0] action;

// Input
input out_valid;
input out_value;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
integer   SIMPLE_PATNUM = 10;
integer   SETNUM = 8;
integer   SEED = 5487;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter DEBUG = 1;
parameter CYCLE = `CYCLE_TIME;
parameter DELAY = 5000;
integer   OUTNUM = -1;

// PATTERN CONTROL
integer stop;
integer set;
integer pat;
integer exe_lat;
integer out_lat;
integer out_check_idx;
integer tot_lat;
integer input_delay;
integer each_delay;

// FILE CONTROL
integer file;
integer file_out;

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
parameter NUM_OF_CHANNEL = 3; // red, green, blue
parameter MAX_SIZE_OF_IMAGE = 16;
parameter SIZE_OF_TEMPLATE = 3;
parameter MIN_SIZE_OF_ACTION = 2;
parameter MAX_SIZE_OF_ACTION = 8;
parameter NUM_OF_FIRST_ACTION_TYPE = 3;
parameter LAST_ACTION_TYPE = 7;
// Input
reg[7:0] _image[NUM_OF_CHANNEL-1:0][MAX_SIZE_OF_IMAGE-1:0][MAX_SIZE_OF_IMAGE-1:0];
reg[7:0] _template[SIZE_OF_TEMPLATE-1:0][SIZE_OF_TEMPLATE-1:0];
reg[2:0] _actionList[MAX_SIZE_OF_ACTION-1:0];
integer _imageSize;
integer _actionSize;

// Intermediate output
reg[7:0] _intermediate[MAX_SIZE_OF_ACTION-1:0][MAX_SIZE_OF_IMAGE-1:0][MAX_SIZE_OF_IMAGE-1:0];
integer _intermediateSize[MAX_SIZE_OF_ACTION-1:0];

//
// Clear
//
task clear_input;
    integer ch_idx;
    integer row_idx;
    integer col_idx;
begin
    for(ch_idx=0 ; ch_idx<NUM_OF_CHANNEL ; ch_idx=ch_idx+1) begin
        for(row_idx=0 ; row_idx<MAX_SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
            for(col_idx=0 ; col_idx<MAX_SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
                _image[ch_idx][row_idx][col_idx] = 0;
            end
        end
    end
    for(row_idx=0 ; row_idx<SIZE_OF_TEMPLATE ; row_idx=row_idx+1) begin
        for(col_idx=0 ; col_idx<SIZE_OF_TEMPLATE ; col_idx=col_idx+1) begin
            _template[row_idx][col_idx] = 0;
        end
    end
end endtask

task clear_intermediate;
    integer num_idx;
    integer row_idx;
    integer col_idx;
begin
    for(num_idx=0 ; num_idx<MAX_SIZE_OF_ACTION ; num_idx=num_idx+1) begin
        _intermediateSize[num_idx] = 0;
        for(row_idx=0 ; row_idx<NUM_OF_CHANNEL ; row_idx=row_idx+1) begin
            for(col_idx=0 ; col_idx<NUM_OF_CHANNEL ; col_idx=col_idx+1) begin
                _intermediate[num_idx][row_idx][col_idx] = 0;
            end
        end
    end
end endtask


//
// Operation
//
task run_action;
    input integer _actIdx;
    input reg[2:0] _actType;
begin
    case(_actType)
        'd0: gray_transf_max_intermediate(_actIdx);
        'd1: gray_transf_avg_intermediate(_actIdx);
        'd2: gray_transf_wght_intermediate(_actIdx);
        'd3: max_pool_intermediate(_actIdx);
        'd4: negative_intermediate(_actIdx);
        'd5: horiz_flip_intermediate(_actIdx);
        'd6: img_filter_intermediate(_actIdx);
        'd7: cross_corr_intermediate(_actIdx);
        default: begin
            $display("[ERROR] [Run Action] Error action type...");
            $finish;
        end
    endcase
end endtask

task gray_transf_max_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
    for(row_idx=0 ; row_idx<MAX_SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
        for(col_idx=0 ; col_idx<MAX_SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
            _intermediate[_actIdx][row_idx][col_idx] =
                _max(
                    _image[0][row_idx][col_idx],
                    _image[1][row_idx][col_idx],
                    _image[2][row_idx][col_idx]
                );
        end
    end
end endtask

task gray_transf_avg_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
    for(row_idx=0 ; row_idx<MAX_SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
        for(col_idx=0 ; col_idx<MAX_SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
            _intermediate[_actIdx][row_idx][col_idx] =
                $floor(
                    (_image[0][row_idx][col_idx]+
                    _image[1][row_idx][col_idx]+
                    _image[2][row_idx][col_idx])/3
                );
        end
    end
end endtask

task gray_transf_wght_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
    for(row_idx=0 ; row_idx<MAX_SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
        for(col_idx=0 ; col_idx<MAX_SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
            _intermediate[_actIdx][row_idx][col_idx] =
                _image[0][row_idx][col_idx]/4+
                _image[1][row_idx][col_idx]/2+
                _image[2][row_idx][col_idx]/4;
        end
    end
end endtask

task max_pool_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
end endtask

task negative_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
end endtask

task horiz_flip_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
end endtask

task img_filter_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
end endtask

task cross_corr_intermediate;
    input integer _actIdx;
    integer row_idx;
    integer col_idx;
begin
end endtask

//
// Generate input
//
task randomize_figure;
    integer ch_idx;
    integer row_idx;
    integer col_idx;
begin
    for(ch_idx=0 ; ch_idx<NUM_OF_CHANNEL ; ch_idx=ch_idx+1) begin
        for(row_idx=0 ; row_idx<MAX_SIZE_OF_IMAGE ; row_idx=row_idx+1) begin
            for(col_idx=0 ; col_idx<MAX_SIZE_OF_IMAGE ; col_idx=col_idx+1) begin
                _image[ch_idx][row_idx][col_idx] = (pat<SIMPLE_PATNUM)
                    ? {$random(SEED)} % 5
                    : {$random(SEED)} % 256;
            end
        end
    end
    for(row_idx=0 ; row_idx<SIZE_OF_TEMPLATE ; row_idx=row_idx+1) begin
        for(col_idx=0 ; col_idx<SIZE_OF_TEMPLATE ; col_idx=col_idx+1) begin
            _template[row_idx][col_idx] = (pat<SIMPLE_PATNUM)
                ? {$random(SEED)} % 5
                : {$random(SEED)} % 256;
        end
    end
end endtask

task randomize_action;
    integer _i;
begin
    _actionSize = {$random(SEED)} % (MAX_SIZE_OF_ACTION - MIN_SIZE_OF_ACTION + 1) + MIN_SIZE_OF_ACTION;
    _actionList[0] = {$random(SEED)} % NUM_OF_FIRST_ACTION_TYPE;
    _actionList[_actionSize-1] = LAST_ACTION_TYPE;
    for(_i=1 ; _i<_actionSize ; _i=_i+1)begin
        _actionList[_i] = {$random(SEED)} % (LAST_ACTION_TYPE - NUM_OF_FIRST_ACTION_TYPE) + NUM_OF_FIRST_ACTION_TYPE;
    end
end endtask

//
// Utility
//
function[7:0] _max;
    input reg[7:0] _in1;
    input reg[7:0] _in2;
    input reg[7:0] _in3;

    reg[7:0] _tmp;
begin
    _tmp = (_in1>_in2) ? (_in1) : (_in2);
    _max = (_tmp>_in3) ? (_tmp) : (_in3);
end endfunction

//
// Dump
//

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
        reset_figure_task;
        input_figure_task;
        for(set=0 ; set<SETNUM ; set=set+1) begin
            input_action_task;
            cal_task;
            wait_task;
            check_task;
            // Print Pass Info and accumulate the total latency
            $display("%0sPASS PATTERN NO.%4d / Set #%1d %0sCycles: %3d%0s",txt_blue_prefix, pat, set, txt_green_prefix, exe_lat, reset_color);
        end
    end
    pass_task;
end endtask

task reset_task; begin
    force clk = 0;
    rst_n = 1;
    in_valid = 0;
    in_valid2 = 0;
    image = 0;
    template = 0;
    image_size = 0;
    action = 0;

    tot_lat = 0;

    #(CYCLE/2.0) rst_n = 0;
    #(CYCLE/2.0) rst_n = 1;
    if(out_valid !== 0 || out_value !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE);
        $finish;
    end
    #(CYCLE/2.0) rst_n = 1;
    #(CYCLE/2.0) release clk;
end endtask

task reset_figure_task; begin
    clear_input;
    clear_intermediate;
end endtask

task input_figure_task; begin
    randomize_figure;
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
end endtask

task input_action_task; begin
    randomize_action;
    repeat(({$random(SEED)} % 3 + 2)) @(negedge clk);
end endtask

task cal_task;
    integer _actIdx;
begin
    for(_actIdx=0 ; _actIdx<_actionSize ; _actIdx=_actIdx+1)begin
        run_action(_actIdx, _actionList[_actIdx]);
    end
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out_value !== 0) begin
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

task check_task; begin
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