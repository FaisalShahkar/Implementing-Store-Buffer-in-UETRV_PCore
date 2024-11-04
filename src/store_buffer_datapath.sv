module store_buffer_datapath #(
    parameter BLEN = 4,         // Buffer Length
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BYTE_SEL_WIDTH = 4
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // LSU --> store_buffer_datapath
    input  logic [ADDR_WIDTH-1:0]       lsummu2stb_addr,        // Address input from LSU/MMU
    input  logic [DATA_WIDTH-1:0]       lsummu2stb_wdata,       // Data input from LSU/MMU
    input  logic [BYTE_SEL_WIDTH-1:0]   lsummu2stb_sel_byte,    // Byte selection input from LSU/MMU
    
    // lsu_stb_controller --> store_buffer_datapath
    input  logic                        stb_wr_en,              // Write enable signal

    // stb_cache_controller --> store_buffer_datapath
    input  logic                        stb_rd_en,              // Read enable signal
    input  logic                        rd_sel,                 // Read Selection signal

    // store_buffer_datapath --> dcache 
    output logic [ADDR_WIDTH-1:0]       stb2dcache_addr,        // Address output to Cache
    output logic [DATA_WIDTH-1:0]       stb2dcache_wdata,        // Data output to Cache
    output logic [BYTE_SEL_WIDTH-1:0]   stb2dcache_sel_byte,    // Byte selection output to Cache

    // store_buffer_datapath --> store buffer controllers
    output logic                        stb_full,               // Full signal
    output logic                        stb_empty               // Empty signal
);

    // Buffer Registers (arrays to hold multiple entries)
    logic [ADDR_WIDTH-1:0]     addr_buf     [BLEN-1:0];
    logic [DATA_WIDTH-1:0]     data_buf     [BLEN-1:0];
    logic [BYTE_SEL_WIDTH-1:0] sel_byte_buf [BLEN-1:0];
    logic [BLEN-1:0]           valid_buf;                   // Valid entries in buffer

    // Buffer Counter (to track read and write index)
    logic [$clog2(BLEN)-1:0]  rd_index;
    logic [$clog2(BLEN)-1:0]  wr_index;

    // counters for read and write operaitons
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_index <= 0;
            rd_index <= 0;
        end
        else if (stb_wr_en) begin
            wr_index <= wr_index + 1;
        end
        else if (stb_rd_en) begin
            rd_index <= rd_index + 1;
        end
        else begin
            wr_index <= wr_index;
            rd_index <= rd_index;
        end
    end

    // Write/Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_index <= 0;
            valid_buf <= '0;
        end 
        else if (stb_wr_en) begin
            // Write new values to buffer at wr_index
            addr_buf     [wr_index] <= lsummu2stb_addr;
            data_buf     [wr_index] <= lsummu2stb_wdata;
            sel_byte_buf [wr_index] <= lsummu2stb_sel_byte;
            valid_buf    [wr_index] <= 1'b1;  
        end
        else if (stb_rd_en && (valid_buf[rd_index] == 1'b1)) begin
            valid_buf    [rd_index] <= 1'b0;  // Mark entry as invalid
        end            
        else begin
            addr_buf[rd_index]     <= addr_buf[rd_index];
            data_buf    [rd_index] <= data_buf          [rd_index];
            sel_byte_buf[rd_index] <= sel_byte_buf      [rd_index];
            valid_buf   [rd_index] <= valid_buf         [rd_index];
        end
    end
    
    // Read mux
    always_comb begin
        if (rd_sel && (valid_buf[rd_index] == 1'b1)) begin
            stb2dcache_addr     = addr_buf      [rd_index];
            stb2dcache_wdata     = data_buf      [rd_index];
            stb2dcache_sel_byte = sel_byte_buf  [rd_index];
        end
        else begin
            stb2dcache_addr     = '0;
            stb2dcache_wdata     = '0;
            stb2dcache_sel_byte = '0;
        end
    end

    // full/empty logic
    assign stb_full  = ($signed(valid_buf) == (-1)) ? 1'b1 : 1'b0;
    assign stb_empty = ($signed(valid_buf) == '0)   ? 1'b1 : 1'b0;

endmodule
