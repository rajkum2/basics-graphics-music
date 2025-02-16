`include "config.svh"

module lab_top # (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,
               screen_width  = 640,
               screen_height = 480,
               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,
               w_x           = $clog2(screen_width),
               w_y           = $clog2(screen_height)
) (
    input                        clk,
    input                        slow_clk,
    input                        rst,
    input        [w_key   - 1:0] key,
    input        [w_sw    - 1:0] sw,
    output logic [w_led   - 1:0] led,
    output logic [7:0]           abcdefgh,
    output logic [w_digit - 1:0] digit,
    input        [w_x - 1:0]     x,
    input        [w_y - 1:0]     y,
    output logic [w_red   - 1:0] red,
    output logic [w_green - 1:0] green,
    output logic [w_blue  - 1:0] blue,
    input        [23:0]          mic,
    output       [15:0]          sound,
    input                        uart_rx,
    output                       uart_tx,
    inout        [w_gpio - 1:0]  gpio
);

    assign led        = '0;
    assign abcdefgh   = '0;
    assign digit      = '0;
    assign sound      = '0;
    assign uart_tx    = '1;

    wire [3:0] x4;
    generate
        if (w_x > 6)
            assign x4 = x [6:3];
        else
            assign x4 = x;
    endgenerate

    logic [3:0] red_4, green_4, blue_4;

    // Game parameters
    parameter PADDLE_WIDTH = 60;
    parameter PADDLE_HEIGHT = 10;
    parameter BALL_SIZE = 10;
    parameter PADDLE_Y_POS = 440;  // Paddle position from bottom
    parameter BALL_SPEED = 1;

    // Game state registers
    logic [w_x-1:0] paddle_x;      // Paddle position
    logic [w_x-1:0] ball_x;        // Ball position
    logic [w_y-1:0] ball_y;
    logic [w_x-1:0] ball_dx;       // Ball direction
    logic [w_y-1:0] ball_dy;
    
    // Game logic
    always_ff @(posedge slow_clk or posedge rst) begin
        if (rst) begin
            // Initialize game state
            paddle_x <= (screen_width - PADDLE_WIDTH) / 2;
            ball_x <= screen_width / 2;
            ball_y <= screen_height / 2;
            ball_dx <= BALL_SPEED;
            ball_dy <= BALL_SPEED;
        end else begin
            // Move paddle based on switches
            if (sw[0] && paddle_x > 0)  // Move left
                paddle_x <= paddle_x - 2;
            if (sw[1] && paddle_x < (screen_width - PADDLE_WIDTH))  // Move right
                paddle_x <= paddle_x + 2;

            // Update ball position
            ball_x <= ball_x + ball_dx;
            ball_y <= ball_y + ball_dy;

            // Ball collision with walls
            if (ball_x <= 0 || ball_x >= (screen_width - BALL_SIZE))
                ball_dx <= -ball_dx;
            if (ball_y <= 0)
                ball_dy <= -ball_dy;

            // Ball collision with paddle
            if (ball_y >= PADDLE_Y_POS - BALL_SIZE &&
                ball_y <= PADDLE_Y_POS + PADDLE_HEIGHT &&
                ball_x >= paddle_x - BALL_SIZE &&
                ball_x <= paddle_x + PADDLE_WIDTH) begin
                ball_dy <= -ball_dy;
            end

            // Reset ball if it goes below paddle
            if (ball_y >= screen_height) begin
                ball_x <= screen_width / 2;
                ball_y <= screen_height / 2;
            end
        end
    end

    // Display logic
    always_comb begin
        red_4   = '0;
        green_4 = '0;
        blue_4  = '0;

        if (x < screen_width && y < screen_height) begin
            // Draw paddle
            if (y >= PADDLE_Y_POS && y <= (PADDLE_Y_POS + PADDLE_HEIGHT) &&
                x >= paddle_x && x <= (paddle_x + PADDLE_WIDTH)) begin
                red_4   = 4'hF;
                green_4 = 4'hF;
                blue_4  = 4'hF;
            end
            
            // Draw ball
            else if (x >= ball_x && x <= (ball_x + BALL_SIZE) &&
                     y >= ball_y && y <= (ball_y + BALL_SIZE)) begin
                red_4   = 4'hF;
                green_4 = 4'h0;
                blue_4  = 4'h0;
            end
        end
    end

    `ifdef VERILATOR
        assign red   = w_red'   ( red_4   );
        assign green = w_green' ( green_4 );
        assign blue  = w_blue'  ( blue_4  );
    `else
        generate
            if (w_red > 4 & w_green > 4 & w_blue > 4) begin
                assign red   = { red_4   , { (w_red   - 4) {1'b0} } };
                assign green = { green_4 , { (w_green - 4) {1'b0} } };
                assign blue  = { blue_4  , { (w_blue  - 4) {1'b0} } };
            end else begin
                assign red   = w_red'   ( red_4   );
                assign green = w_green' ( green_4 );
                assign blue  = w_blue'  ( blue_4  );
            end
        endgenerate
    `endif

endmodule
