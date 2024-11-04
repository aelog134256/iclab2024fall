/*
    @debug method : display
        
    @description :
        Run convolution
            matrix : 1 * 6 * 6
            kernel : 5 * 2 * 2
            output : 5 * 5 * 5
        
    @issue :
        
    @todo :
        
*/
`ifdef RTL
	`define CYCLE_TIME_clk1 47.1
	`define CYCLE_TIME_clk2 10.1
`endif
`ifdef GATE
	`define CYCLE_TIME_clk1 47.1
	`define CYCLE_TIME_clk2 10.1
`endif

module PATTERN(
	clk1,
	clk2,
	rst_n,
	in_valid,
	in_row,
	in_kernel,
	out_valid,
	out_data
);
//======================================
//      INPUT & OUTPUT
//======================================
output reg clk1, clk2;
output reg rst_n;
output reg in_valid;
output reg [17:0] in_row;
output reg [11:0] in_kernel;

input out_valid;
input [7:0] out_data;

//======================================
//      PARAMETERS & VARIABLES
//======================================
//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
// Can be modified by user
integer   TOTAL_PATNUM = 10;
integer   SIMPLE_PATNUM = 10;
integer   SEED = 5487;
parameter DEBUG = 1;
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
parameter CYCLE_clk1 = `CYCLE_TIME_clk1;
parameter CYCLE_clk2 = `CYCLE_TIME_clk2;
parameter DELAY = 5000;

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
// size
parameter SIZE_OF_MATRIX = 6;
parameter SIZE_OF_KERNEL = 2;
parameter SIZE_OF_OUTPUT = SIZE_OF_MATRIX - SIZE_OF_KERNEL + 1; // 5
// bit
parameter BITS_OF_MATRIX = 3;
parameter BITS_OF_KERNEL = 3;
parameter BITS_OF_OUTPUT = 8;
// input num
parameter NUM_ELEMENTS_PER_ROW = 6;
parameter NUM_OF_KERNEL = 6;
parameter NUM_OF_OUTPUT = NUM_OF_KERNEL; // 6
// data
reg[BITS_OF_MATRIX-1:0] _matrix                   [SIZE_OF_MATRIX-1:0][SIZE_OF_MATRIX-1:0];
reg[BITS_OF_KERNEL-1:0] _kernel[NUM_OF_KERNEL-1:0][SIZE_OF_KERNEL-1:0][SIZE_OF_KERNEL-1:0];
reg[BITS_OF_OUTPUT-1:0] _output[NUM_OF_OUTPUT-1:0][SIZE_OF_OUTPUT-1:0][SIZE_OF_OUTPUT-1:0];
reg[BITS_OF_OUTPUT-1:0]   _your[NUM_OF_OUTPUT-1:0][SIZE_OF_OUTPUT-1:0][SIZE_OF_OUTPUT-1:0];
// Output
parameter OUTNUM = NUM_OF_OUTPUT * SIZE_OF_OUTPUT * SIZE_OF_OUTPUT;

//
// Radnom
//
task randomize_input;
    integer _num;
    integer _row;
    integer _col;
begin
    // Matrix
    for(_row=0 ; _row<SIZE_OF_MATRIX ; _row=_row+1) begin
        for(_col=0 ; _col<SIZE_OF_MATRIX ; _col=_col+1) begin
            _matrix[_row][_col] = {$random(SEED)} % (2**BITS_OF_MATRIX);
        end
    end
    // Kernel
    for(_num=0 ; _num<NUM_OF_KERNEL ; _num=_num+1) begin
        for(_row=0 ; _row<SIZE_OF_KERNEL ; _row=_row+1) begin
            for(_col=0 ; _col<SIZE_OF_KERNEL ; _col=_col+1) begin
                _kernel[_num][_row][_col] = {$random(SEED)} % (2**BITS_OF_KERNEL);
            end
        end
    end
end endtask

//
// Calculation
//
task run_convolution;
    integer _num;
    integer _row;
    integer _col;
    integer _innerRow;
    integer _innerCol;
begin
    // Clear output
    for(_num=0 ; _num<NUM_OF_OUTPUT ; _num=_num+1) begin
        for(_row=0 ; _row<SIZE_OF_OUTPUT ; _row=_row+1) begin
            for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) begin
                _output[_num][_row][_col] = 0;
            end
        end
    end
    // Convolution
    for(_num=0 ; _num<NUM_OF_OUTPUT ; _num=_num+1) begin
        for(_row=0 ; _row<SIZE_OF_OUTPUT ; _row=_row+1) begin
            for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) begin
                for(_innerRow=0 ; _innerRow<SIZE_OF_KERNEL ; _innerRow=_innerRow+1) begin
                    for(_innerCol=0 ; _innerCol<SIZE_OF_KERNEL ; _innerCol=_innerCol+1) begin
                        _output[_num][_row][_col] = _output[_num][_row][_col] +
                            _matrix[_row+_innerRow][_col+_innerCol] *
                                _kernel[_num][_innerRow][_innerCol];
                    end
                end
            end
        end
    end
end endtask

//
// Dump
//
parameter integer DUMP_SIZE_INPUT  = 8;//$ceil(BITS_OF_MATRIX * $log10(2));
parameter integer DUMP_SIZE_OUTPUT = 8;//$ceil(BITS_OF_OUTPUT * $log10(2));
dumper #(.DUMP_ELEMENT_SIZE(DUMP_SIZE_INPUT)) inputDumper();
dumper #(.DUMP_ELEMENT_SIZE(DUMP_SIZE_OUTPUT)) outputDumper();

task show_matrix_and_kernel_by_index;
    input integer _num;
    integer _row;
    integer _col;
    reg[DUMP_SIZE_INPUT*8:1] _str;
begin
    inputDumper.displaySeperator(SIZE_OF_MATRIX+1);
    inputDumper.writeCell("Matrix", "s", 1);
    for(_col=0 ; _col<SIZE_OF_MATRIX ; _col=_col+1) inputDumper.writeCell(_col, "d", 0);
    inputDumper.displayLine();
    inputDumper.displaySeperator(SIZE_OF_MATRIX+1);
    for(_row=0 ; _row<SIZE_OF_MATRIX ; _row=_row+1) begin
        inputDumper.writeCell(_row, "d", 1);
        for(_col=0 ; _col<SIZE_OF_MATRIX ; _col=_col+1) begin
            inputDumper.writeCell(_matrix[_row][_col], "d", 0);
        end
        inputDumper.displayLine();
    end
    inputDumper.displaySeperator(SIZE_OF_MATRIX+1);

    inputDumper.displayLine();

    inputDumper.displaySeperator(SIZE_OF_KERNEL+1);
    $sformat(_str, "Kernel %-d", _num);
    inputDumper.writeCell(_str, "s", 1);
    for(_col=0 ; _col<SIZE_OF_KERNEL ; _col=_col+1) inputDumper.writeCell(_col, "d", 0);
    inputDumper.displayLine();
    inputDumper.displaySeperator(SIZE_OF_KERNEL+1);
    for(_row=0 ; _row<SIZE_OF_KERNEL ; _row=_row+1) begin
        inputDumper.writeCell(_row, "d", 1);
        for(_col=0 ; _col<SIZE_OF_KERNEL ; _col=_col+1) begin
            inputDumper.writeCell(_kernel[_num][_row][_col], "d", 0);
        end
        inputDumper.displayLine();
    end
    inputDumper.displaySeperator(SIZE_OF_KERNEL+1);
    inputDumper.displayLine();
end endtask

task show_output_by_index;
    input integer _num;
    integer _row;
    integer _col;
    reg[DUMP_SIZE_OUTPUT*8:1] _str;
begin
    outputDumper.displaySeperator(SIZE_OF_OUTPUT+1);
    $sformat(_str, "Output %-d", _num);
    outputDumper.writeCell(_str, "s", 1);
    for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) outputDumper.writeCell(_col, "d", 0);
    outputDumper.displayLine();
    outputDumper.displaySeperator(SIZE_OF_OUTPUT+1);
    for(_row=0 ; _row<SIZE_OF_OUTPUT ; _row=_row+1) begin
        outputDumper.writeCell(_row, "d", 1);
        for(_col=0 ; _col<SIZE_OF_OUTPUT ; _col=_col+1) begin
            outputDumper.writeCell(_output[_num][_row][_col], "d", 0);
        end
        outputDumper.displayLine();
    end
    outputDumper.displaySeperator(SIZE_OF_OUTPUT+1);
    outputDumper.displayLine();
end endtask

//======================================
//              MAIN
//======================================
initial exe_task;

//======================================
//              CLOCK
//======================================
always	#(CYCLE_clk1/2.0) clk1 = ~clk1;
initial	clk1 = 0;
always	#(CYCLE_clk2/2.0) clk2 = ~clk2;
initial	clk2 = 0;

//======================================
//              TASKS
//======================================
task exe_task; begin
    reset_task;
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
    force clk1 = 0;
    force clk2 = 0;
    rst_n = 1;
    in_valid = 0;
    in_row = 'dx;
    in_kernel = 'dx;

    tot_lat = 0;

    repeat(5) #(CYCLE_clk2/2.0) rst_n = 0;
    repeat(5) #(CYCLE_clk2/2.0) rst_n = 1;
    if(out_valid !== 0 || out_data !== 0) begin
        $display("[ERROR] [Reset] Output signal should be 0 at %-12d ps  ", $time*1000);
        repeat(5) #(CYCLE_clk2);
        $finish;
    end
    #(CYCLE_clk2/2.0) release clk1;
    #(CYCLE_clk2/2.0) release clk2;
end endtask

task input_task;
    integer _num;
    integer _row;
    integer _col;
    integer _rowK;
    integer _colK;
begin
    repeat(({$random(SEED)} % 3 + 1)) @(negedge clk1);
    randomize_input;
    for(_row=0, _num=0 ; _row<SIZE_OF_MATRIX && _num<NUM_OF_KERNEL ; _row=_row+1, _num=_num+1) begin
        // in valid
        in_valid = 1;
        // matrix
        in_row = 'dx;
        for(_col=SIZE_OF_MATRIX-1 ; _col>=0 ; _col=_col-1) begin
            in_row = {in_row, _matrix[_row][_col]};
        end
        // kernel
        in_kernel = 'dx;
        for(_rowK=SIZE_OF_KERNEL-1 ; _rowK>=0 ; _rowK=_rowK-1) begin
            for(_colK=SIZE_OF_KERNEL-1 ; _colK>=0 ; _colK=_colK-1) begin
                in_kernel = {in_kernel, _kernel[_num][_rowK][_colK]};
            end
        end
        @(negedge clk1);
    end

    in_valid = 0;
    in_row = 'dx;
    in_kernel = 'dx;
end endtask

task cal_task; begin
    run_convolution;
end endtask

task wait_task; begin
    exe_lat = -1;
    while(out_valid !== 1) begin
        if(out_data !== 0) begin
            $display("[ERROR] [WAIT] Output signal should be 0 at %-12d ps", $time*1000);
            repeat(5) @(negedge clk1);
            $finish;
        end
        if(exe_lat == DELAY) begin
            $display("[ERROR] [WAIT] The execution latency at %-12d ps is over %5d cycles", $time*1000, DELAY);
            repeat(5) @(negedge clk1);
            $finish; 
        end
        exe_lat = exe_lat + 1;
        @(negedge clk1);
    end
end endtask

task check_task;
    integer out_lat;
    integer out_cnt;
begin
    out_lat = 0;
    out_cnt = 0;
    while(out_cnt < OUTNUM) begin
        // Wait
        while(out_valid !== 1) begin
            if(out_data !== 0) begin
                $display("[ERROR] [OUTPUT] Output signal should be 0 at %-12d ps", $time*1000);
                repeat(5) @(negedge clk1);
                $finish;
            end
            if(out_lat == DELAY) begin
                $display("[ERROR] [OUTPUT] The execution latency at %-12d ps is over %5d cycles", $time*1000, DELAY);
                repeat(5) @(negedge clk1);
                $finish; 
            end
            out_lat = out_lat + 1;
            @(negedge clk1);
        end
        // Get output
        if(out_valid===1) begin
            _your
                [out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT)]
                [(out_cnt%(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT))/SIZE_OF_OUTPUT]
                [out_cnt%SIZE_OF_OUTPUT] = out_data;

            if(
                _output[out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT)]
                [(out_cnt%(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT))/SIZE_OF_OUTPUT]
                [out_cnt%SIZE_OF_OUTPUT] !== out_data) begin
                    $display("[ERROR] [OUTPUT] Output is not correct...\n");
                    show_matrix_and_kernel_by_index(out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT));
                    show_output_by_index(out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT));
                    $display("[ERROR] [OUTPUT] (%2d, %2d, %2d) is not correct\n",
                        out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT),
                        (out_cnt%(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT))/SIZE_OF_OUTPUT,
                        out_cnt%SIZE_OF_OUTPUT
                    );
                    $display("[ERROR] [OUTPUT] Your   : %2d", out_data);
                    $display("[ERROR] [OUTPUT] Golden : %2d", _output[out_cnt/(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT)]
                        [(out_cnt%(SIZE_OF_OUTPUT*SIZE_OF_OUTPUT))/SIZE_OF_OUTPUT]
                        [out_cnt%SIZE_OF_OUTPUT]);
                    repeat(5) @(negedge clk1);
                    $finish;
            end
            tot_lat = tot_lat + out_lat;
            out_lat = 0;
            out_cnt = out_cnt + 1;
            @(negedge clk1);
        end
    end

    if(out_valid===1) begin
        $display("[ERROR] [OUTPUT] Out cycles is more than %3d at %-12d ps", OUTNUM, $time*1000);
        repeat(5) @(negedge clk1);
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
    repeat(5) @(negedge clk1);
    $finish;
end endtask

endmodule

module dumper #(
    parameter DUMP_ELEMENT_SIZE = 4
);

// Dump
parameter DUMP_NUM_OF_SPACE = 2;
parameter DUMP_NUM_OF_SEP = 2;
parameter SIZE_OF_BUFFER = 256;

//
// File
//
task addLine;
    input integer file;
begin
    $fwrite(file, "\n");
end endtask

task addSeperator;
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

// TODO
// Only support %d %s
// Should consider the %f ex : %8.3f, %12.1f
task addCell;
    input integer file;
    input reg[DUMP_ELEMENT_SIZE*8:1] _in;
    input reg[8:1] _type;
    input reg _isStart;
    reg[SIZE_OF_BUFFER*8:1] _format;
    reg[DUMP_ELEMENT_SIZE*8:1] _inFormat;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line;
begin
    // Format
    $sformat(_format, "%%%-d", DUMP_ELEMENT_SIZE);
    _format = {_format[(SIZE_OF_BUFFER-1)*8:1], _type};
    $sformat(_inFormat, _format, _in);
    // Output
    _line = _isStart ? "| " : " ";
    _line = {_line, _inFormat};
    _line = {_line, " |"};
    $fwrite(file, "%0s", _line);
end endtask

//
// Display
//
task displayLine;
begin
    $write("\n");
end endtask

task displaySeperator;
    input integer _num;
    integer _idx;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line; // 4 = 2 spaces with 2 "+"
begin
    _line = "";
    for(_idx=1 ; _idx<=DUMP_ELEMENT_SIZE+2 ; _idx=_idx+1) begin
        _line = {_line, "-"};
    end
    _line = {_line, "+"};
    $write("+");
    for(_idx=0 ; _idx<_num ; _idx=_idx+1) $write("%0s", _line);
    $write("\n");
end endtask

// TODO
// Only support %d %s
// Should consider the %f ex : %8.3f, %12.1f
task writeCell;
    input reg[DUMP_ELEMENT_SIZE*8:1] _in;
    input reg[8:1] _type;
    input reg _isStart;
    reg[SIZE_OF_BUFFER*8:1] _format;
    reg[DUMP_ELEMENT_SIZE*8:1] _inFormat;
    reg[(DUMP_ELEMENT_SIZE+DUMP_NUM_OF_SPACE+DUMP_NUM_OF_SEP)*8:1] _line;
begin
    // Format
    $sformat(_format, "%%%-d", DUMP_ELEMENT_SIZE);
    _format = {_format[(SIZE_OF_BUFFER-1)*8:1], _type};
    $sformat(_inFormat, _format, _in);
    // Output
    _line = _isStart ? "| " : " ";
    _line = {_line, _inFormat};
    _line = {_line, " |"};
    $write("%0s", _line);
end endtask

endmodule