module face_selector #(
        parameter NUM_IMAGES = 8
    )
    (
        input wire clk,
        input wire rst,

        input wire [31:0] low_data,
        input wire [31:0] mid_data,
        input wire [31:0] high_data,

        input wire [31:0] low_threshold,
        input wire [31:0] mid_threshold,
        input wire [31:0] high_threshold,
        input wire update_face,

        output logic low_valid,
        output logic mid_valid,
        output logic high_valid,


        output logic [$clog2(NUM_IMAGES)-1:0] face_state
    );
    logic [2:0] lmh;

    assign low_valid = (low_data >= low_threshold);
    assign mid_valid = (mid_data >= mid_threshold);
    assign high_valid = (high_data >= high_threshold);

    assign lmh = {low_valid, mid_valid, high_valid};

    // State = EYE_MOUTH
    // Eye: Open, Closed
    // Mouth: Closed, Mid, Open, Wide
    typedef enum logic [2:0] { 
        OPEN_CLOSED = 3'b000,
        OPEN_MID = 3'b010,
        OPEN_OPEN = 3'b001,
        OPEN_WIDE = 3'b011,
        CLOSED_CLOSED = 3'b100,
        CLOSED_MID = 3'b110,
        CLOSED_OPEN = 3'b101,
        CLOSED_WIDE = 3'b111
    } face_states;

    face_states our_face_state;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            our_face_state <= OPEN_CLOSED;
        end else begin
            if (update_face) begin
                if (lmh == 3'b000)
                    our_face_state <= OPEN_CLOSED;
                if (lmh == 3'b100)
                    our_face_state <= CLOSED_CLOSED;

                case (our_face_state)
                    OPEN_CLOSED: begin
                        if (lmh == 3'b001)
                            our_face_state <= OPEN_OPEN;
                        else if (lmh == 3'b010)
                            our_face_state <= OPEN_MID;
                        else if (lmh == 3'b011)
                            our_face_state <= OPEN_WIDE;
                        else if (lmh == 3'b101)
                            our_face_state <= CLOSED_OPEN;
                        else if (lmh == 3'b110)
                            our_face_state <= CLOSED_MID;
                        else if (lmh == 3'b111)
                            our_face_state <= CLOSED_WIDE;
                        else if (lmh == 3'b100)
                            our_face_state <= CLOSED_CLOSED;
                    end

                    OPEN_MID: begin
                        if (lmh == 3'b110)
                            our_face_state <= CLOSED_MID;
                        if (lmh == 3'b011 || lmh == 3'b001)
                            our_face_state <= OPEN_OPEN;
                        if (lmh == 3'b111 || lmh == 3'b101)
                            our_face_state <= CLOSED_OPEN;
                    end

                    OPEN_OPEN: begin
                        if (lmh == 3'b101)
                            our_face_state <= CLOSED_OPEN;
                        if (lmh == 3'b010 || lmh == 3'b000)
                            our_face_state <= OPEN_MID;
                        if (lmh == 3'b110 || lmh == 3'b100)
                            our_face_state <= CLOSED_MID;
                        if (lmh == 3'b011)
                            our_face_state <= OPEN_WIDE;
                        if (lmh == 3'b111)
                            our_face_state <= OPEN_WIDE;
                    end

                    OPEN_WIDE: begin
                        if (lmh == 3'b111)
                            our_face_state <= CLOSED_WIDE;
                        if (lmh == 3'b000 || lmh == 3'b001 || lmh == 3'b010)
                            our_face_state <= OPEN_MID;
                        if (lmh == 3'b100 || lmh == 3'b101 || lmh == 3'b110)
                            our_face_state <= CLOSED_MID;
                    end

                    CLOSED_CLOSED: begin
                        if (lmh == 3'b001)
                            our_face_state <= OPEN_OPEN;
                        else if (lmh == 3'b010)
                            our_face_state <= OPEN_MID;
                        else if (lmh == 3'b011)
                            our_face_state <= OPEN_WIDE;
                        else if (lmh == 3'b101)
                            our_face_state <= CLOSED_OPEN;
                        else if (lmh == 3'b110)
                            our_face_state <= CLOSED_MID;
                        else if (lmh == 3'b111)
                            our_face_state <= CLOSED_WIDE;
                        else if (lmh == 3'b100)
                            our_face_state <= CLOSED_CLOSED;
                        else if (lmh == 3'b000)
                            our_face_state <= OPEN_CLOSED;
                    end

                    CLOSED_MID: begin
                        if (lmh == 3'b010)
                            our_face_state <= OPEN_MID;
                        if (lmh == 3'b011 || lmh == 3'b001)
                            our_face_state <= OPEN_OPEN;
                        if (lmh == 3'b111 || lmh == 3'b101)
                            our_face_state <= CLOSED_OPEN;
                    end

                    CLOSED_OPEN: begin
                        if (lmh == 3'b001)
                            our_face_state <= OPEN_OPEN;
                        if (lmh == 3'b010 || lmh == 3'b000)
                            our_face_state <= OPEN_MID;
                        if (lmh == 3'b110 || lmh == 3'b100)
                            our_face_state <= CLOSED_MID;
                        if (lmh == 3'b011)
                            our_face_state <= OPEN_WIDE;
                        if (lmh == 3'b111)
                            our_face_state <= OPEN_WIDE;
                    end

                    CLOSED_WIDE: begin
                        if (lmh == 3'b011)
                            our_face_state <= OPEN_WIDE;
                        if (lmh == 3'b000 || lmh == 3'b001 || lmh == 3'b010)
                            our_face_state <= OPEN_MID;
                        if (lmh == 3'b100 || lmh == 3'b101 || lmh == 3'b110)
                            our_face_state <= CLOSED_MID;
                    end 
                    default: begin
                        our_face_state <= our_face_state;
                    end
                endcase
            end
        end
    end
    always_comb begin
        case (our_face_state)
            OPEN_CLOSED: face_state = 3'b000;
            OPEN_MID: face_state = 3'b010;
            OPEN_OPEN: face_state = 3'b001;
            OPEN_WIDE: face_state = 3'b011;
            CLOSED_CLOSED: face_state = 3'b100;
            CLOSED_MID: face_state = 3'b110;
            CLOSED_OPEN: face_state = 3'b101;
            CLOSED_WIDE: face_state = 3'b111;
            default: face_state = 3'b000;
        endcase
    end

endmodule