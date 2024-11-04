
module tb_store_buffer_top;

    // Parameters
    parameter NUM_RAND_TESTS = 7;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter BYTE_SEL_WIDTH = 4;
    parameter BLEN = 8;

    // DUT signals
    logic                       clk;
    logic                       rst_n;
    
    // LSU --> store_buffer_top
    logic [ADDR_WIDTH-1:0]      lsummu2stb_addr;
    logic [DATA_WIDTH-1:0]      lsummu2stb_wdata;
    logic [BYTE_SEL_WIDTH-1:0]  lsummu2stb_sel_byte;
    logic                       lsummu2stb_w_en;
    logic                       lsummu2stb_req;
    logic                       dmem_sel_i;

    // store_buffer_top --> LSU
    logic                       stb2lsummu_stall;
    logic                       stb2lsummu_ack;       // Store Buffer acknowledges the write

    // dcache --> store_buffer_top
    logic                       dcache2stb_ack;

    // store_buffer_top --> dcache
    logic [ADDR_WIDTH-1:0]      stb2dcache_addr;
    logic [DATA_WIDTH-1:0]      stb2dcache_wdata;
    logic [BYTE_SEL_WIDTH-1:0]  stb2dcache_sel_byte;
    logic                       stb2dcache_w_en;      // Write enable from Store Buffer
    logic                       stb2dcache_req;       // Store request from Store Buffer
    logic                       stb2dcache_empty;
    logic                       dmem_sel_o;           // Data memory select from Store Buffer

    // Instantiate the DUT (Device Under Test)
    store_buffer_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_SEL_WIDTH(BYTE_SEL_WIDTH),
        .BLEN(BLEN)
    ) DUT (
        .clk                    (clk),
        .rst_n                  (rst_n),


        // LSU --> store_buffer_top
        .lsummu2stb_addr        (lsummu2stb_addr),
        .lsummu2stb_wdata       (lsummu2stb_wdata),
        .lsummu2stb_sel_byte    (lsummu2stb_sel_byte),
        .lsummu2stb_w_en        (lsummu2stb_w_en),
        .lsummu2stb_req         (lsummu2stb_req),
        .dmem_sel_i             (dmem_sel_i),

        // store_buffer_top --> LSU
        .stb2lsummu_stall       (stb2lsummu_stall),        
        .stb2lsummu_ack         (stb2lsummu_ack),

        // store_buffer_top --> dcache
        .stb2dcache_addr        (stb2dcache_addr),
        .stb2dcache_wdata       (stb2dcache_wdata),
        .stb2dcache_sel_byte    (stb2dcache_sel_byte),
        .stb2dcache_w_en        (stb2dcache_w_en),
        .stb2dcache_req         (stb2dcache_req),
        .stb2dcache_empty       (stb2dcache_empty),
        .dmem_sel_o             (dmem_sel_o),

        //dcache --> store_buffer_top
        .dcache2stb_ack         (dcache2stb_ack)

    );

    // Clock generation
    always #5 clk = ~clk;

    task init_sequence;
        clk                 = 0;
        rst_n               = 0;
        dmem_sel_i          = 0;
        lsummu2stb_w_en     = 0;
        lsummu2stb_req      = 0;
        dcache2stb_ack      = 0;

        lsummu2stb_addr     = 32'b0;
        lsummu2stb_wdata    = 32'b0;
        lsummu2stb_sel_byte = 4'b1111;    
    endtask

    task reset_apply;
        rst_n = 0;
        @(posedge clk);
        rst_n = 1;    
    endtask  

    // Test stimulus
    initial begin
        // Initialize signals
        $display("Initailize the Signals");
        init_sequence();

        // Assert reset
        $display("Assert Reset");
        reset_apply();

        // Directed Tests
        $display("Directed Tests");
        write_to_buffer(1, 100, 4);
        write_to_buffer(2, 400, 3);
        write_to_buffer(3, 300, 2);
        write_to_buffer(4, 600, 1);

        // Random Tests
        $display("Random Tests");
        test_random_signals();
        @(posedge clk);

        // Write to Cache 
        $display("Test 3: Write to Cache");
        while (!stb2dcache_empty) begin
            write_to_cache();
        end
        @(posedge clk);

        // store buffer should be empty after all data write to cache
        $display("store buffer empty(1) or not(0): %b",stb2dcache_empty);
        
        // End the simulation
        $display("End of Simulation");
        $finish;
    end

    // Task to write to store buffer
    task write_to_buffer(
        input [ADDR_WIDTH-1:0] addr, 
        input [DATA_WIDTH-1:0] data, 
        input [BYTE_SEL_WIDTH-1:0] byte_sel
    );
        begin
            lsummu2stb_addr         <= addr;
            lsummu2stb_wdata        <= data;
            lsummu2stb_sel_byte     <= byte_sel;
            dmem_sel_i              <= 1;
            lsummu2stb_w_en         <= 1;
            lsummu2stb_req          <= 1;  // actually valid signal
            @(posedge clk);
            if(stb2lsummu_stall)begin
                $display("Wait for some cycles .......");
                lsummu2stb_w_en         <= 1;
                lsummu2stb_req          <= 1;  
            end
            else 
            begin
                while (!stb2lsummu_ack) begin // actually ready signal
                    @(posedge clk);
                end
                
            end
            
            lsummu2stb_w_en <= 0;
            lsummu2stb_req <= 0;
            @(posedge clk);
            $display("LSU to Store Buffer Write: Adddress:%h Data:%h",lsummu2stb_addr,lsummu2stb_wdata);
        end
    endtask

    logic [31:0]dcache[0:31];
    task write_to_cache();
        dcache2stb_ack = 0;
        @(posedge clk);
        while (!stb2dcache_req)   
            @(posedge clk);
        
        if (stb2dcache_w_en) begin
            dcache[stb2dcache_addr] = stb2dcache_wdata;
        end  
        dcache2stb_ack = 1;
        $display("Store Buffer to Cache write: Adddress:%h Data:%h ",stb2dcache_addr,stb2dcache_wdata);
        repeat(1)@(posedge clk);
        dcache2stb_ack = 0;   
    endtask

    // Task for random test
    int i;
    task test_random_signals();
        for (i=0; i<NUM_RAND_TESTS; i++) begin
            write_to_buffer($random, $random, $random); 
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0,tb_store_buffer_top);
    end

endmodule