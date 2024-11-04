module lsu_stb_controller (
    input  logic        clk,
    input  logic        rst_n,

    // LSU --> lsu_stb_controller
    input  logic        lsummu2stb_w_en,    // Write enable from LSU
    input  logic        lsummu2stb_req,     // Store request from LSU
    input  logic        dmem_sel_i,         // Input from LSU (data memory select)

    // store_buffer_datapath --> lsu_stb_controller 
    input  logic        stb_full,           // Store buffer stb_full flag
    input  logic        stb_empty,          // store buffer stb_empty flag

    // lsu_stb_controller --> LSU
    output logic        stb2lsummu_ack,     // stb_acknowledgement signal

    // lsu_stb_controller --> store_buffer_datapath
    output logic        stb_wr_en,          // Store buffer write enable
    
    // lsu_stb_controller --> LSU
    output logic        stb2lsummu_stall    // Stall signal if buffer is stb_full
);

    typedef enum logic [1:0] {
        SB_IDLE  = 2'b00,
        SB_WRITE = 2'b01,
        SB_FULL  = 2'b10
    } state_t;

    state_t current_state, next_state;

    // State transition logic (sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= SB_IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic (combinational)
    always_comb begin
        // Default values
        stb_wr_en        = 1'b0;
        stb2lsummu_stall = 1'b0;
        stb2lsummu_ack   = 1'b0;

        case (current_state)
            SB_IDLE: begin
                if (dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && !stb_full) begin
                    stb_wr_en        = 1'b1;  // Enable write to buffer
                    stb2lsummu_stall = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_WRITE;
                end
                else if (dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && stb_full) 
                begin
                    stb2lsummu_stall = 1'b1;
                    stb_wr_en        = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_FULL;   
                end
            end

            SB_WRITE: begin
                if (!stb_empty) 
                begin
                    stb_wr_en        = 1'b0;
                    stb2lsummu_stall = 1'b0;
                    stb2lsummu_ack   = 1'b1;
                    next_state       = SB_IDLE;  // Transition to stb_full state if buffer is stb_full
                end
                else if(dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && !stb_full)begin
                    stb_wr_en        = 1'b1;  // Enable write to buffer
                    stb2lsummu_stall = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_WRITE;
                end
                else if(dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && stb_full)begin
                    stb2lsummu_stall = 1'b1;
                    stb_wr_en        = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_FULL; 
     
                end
            end

            SB_FULL: begin
                stb2lsummu_stall = 1'b1;  // Stall signal if buffer is stb_full
                if (dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && !stb_full) begin
                    stb_wr_en        = 1'b1;
                    stb2lsummu_stall = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_WRITE;  // Go to idle once buffer is not stb_full
                end
                else if(dmem_sel_i && lsummu2stb_w_en && lsummu2stb_req && stb_full) begin
                    stb2lsummu_stall = 1'b1;
                    stb_wr_en        = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_FULL;
                end
                else if (!dmem_sel_i && !lsummu2stb_w_en && !lsummu2stb_req) begin
                    stb2lsummu_stall = 1'b0;
                    stb_wr_en        = 1'b0;
                    stb2lsummu_ack   = 1'b0;
                    next_state       = SB_IDLE;
                end
        
            end

            default: next_state      = SB_IDLE;
        endcase
    end

endmodule
