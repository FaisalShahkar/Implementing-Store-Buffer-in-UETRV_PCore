module stb_cache_controller (
    input  logic        clk,
    input  logic        rst_n,
    
    // store_buffer_datapath --> stb_cache_controller    
    input  logic        stb_full,           // Store buffer full flag
    input  logic        stb_empty,          // Store buffer empty flag
    
    // dcache --> stb_cache_controller
    input  logic        dcache2stb_ack,     // Acknowledgement from cache
    
    // stb_cache_controller --> store_buffer_datapath
    output logic        stb_rd_en,          // enable for read counter
    output logic        rd_sel,             // Store buffer mux read selection

    // stb_cache_controller --> dcache
    output logic        stb2dcache_req,     // Store buffer request signal
    output logic        stb2dcache_w_en,    // Last word enable (for last write to cache)
    output logic        dmem_sel_o
);

    typedef enum logic [1:0] {
        IDLE             = 2'b00,
        SB_CACHE_WRITE   = 2'b01
    } state_t;

    state_t current_state, next_state;

    // State transition logic (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic (combinational)
    always_comb begin
        // Default values
        rd_sel          = 1'b0;
        stb2dcache_req  = 1'b0;
        stb2dcache_w_en = 1'b0;
        stb_rd_en       = 1'b0;
        dmem_sel_o      = 1'b0;
        next_state      = current_state;

        case (current_state)
            IDLE: begin
                if (!stb_empty || stb_full) begin
                    stb2dcache_req  = 1'b1;   // Request cache write
                    rd_sel          = 1'b1;   // Read selection for store buffer
                    stb2dcache_w_en = 1'b1;
                    dmem_sel_o      = 1'b1;
                    stb_rd_en       = 1'b0;
                    next_state      = SB_CACHE_WRITE;
                end
                else if(stb_empty) begin
                    rd_sel          = 1'b0;
                    stb2dcache_req  = 1'b0;
                    stb2dcache_w_en = 1'b0;
                    stb_rd_en       = 1'b0;
                    dmem_sel_o      = 1'b0;
                    next_state      = IDLE; 
                end
            end

            SB_CACHE_WRITE: begin
                if (!dcache2stb_ack && !stb_empty) begin
                    stb2dcache_req  = 1'b1;  
                    rd_sel          = 1'b1;   
                    stb2dcache_w_en = 1'b1;
                    dmem_sel_o      = 1'b1;
                    stb_rd_en       = 1'b0;
                    next_state      = SB_CACHE_WRITE;  // Stay SB_CACHE_WRITE state till store buffer contain data
                    
                end
                else if (dcache2stb_ack && !stb_empty) begin
                    stb2dcache_req  = 1'b1;  
                    rd_sel          = 1'b1;   
                    stb2dcache_w_en = 1'b1;
                    dmem_sel_o      = 1'b1;
                    stb_rd_en       = 1'b1;
                    next_state      = SB_CACHE_WRITE;  // Stay SB_CACHE_WRITE state till all data written to cache then cache acknowledges set
                end
                else if (stb_empty) begin
                    stb2dcache_req  = 1'b0;  
                    rd_sel          = 1'b1;  
                    stb2dcache_w_en = 1'b0;
                    dmem_sel_o      = 1'b0;
                    stb_rd_en       = 1'b0;
                    next_state      = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end
endmodule
