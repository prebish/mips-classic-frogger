# JOEL PREBISH

# need this early included so we have constants for declaring arrays in data seg
.include "game_constants.asm"
.data

# set to 1 to make it impossible to get a game over!
.eqv GRADER_MODE 0

# player's score and number of lives
score: .word 0
lives: .word 3

# boolean (1 means the game is over)
game_over: .word 0

# how many active objects there are. this many slots of the below arrays represent
# active objects.
cur_num_objs: .word 0

# Object arrays. These are parallel arrays. The player object is in slot 0,
# so the "player_x", "player_y", "player_timer" etc. labels are pointing to the
# same place as slot 0 of those arrays.

object_type: .byte 0:MAX_NUM_OBJECTS
player_x:
object_x: .byte 0:MAX_NUM_OBJECTS
player_y:
object_y: .byte 0:MAX_NUM_OBJECTS
player_timer:
object_timer: .byte 0:MAX_NUM_OBJECTS
player_delay:
object_delay: .byte 0: MAX_NUM_OBJECTS
player_vel:
object_vel: .byte 0:MAX_NUM_OBJECTS

# this is the 2d array for our map
tilemap: .byte 0:MAP_SIZE

.text

#-------------------------------------------------------------------------------------------------
# include AFTER our initial data segment stuff for easier memory debugging

.include "display_2227_0611.asm"
.include "map.asm"
.include "textures.asm"
.include "obj.asm"

#-------------------------------------------------------------------------------------------------

.globl main
main:
	# this populates the tilemap array and the object arrays
	jal load_map

	# do...
	_game_loop:
		jal check_input
		jal update_all
		jal draw_all
		jal display_update_and_clear
		jal wait_for_next_frame
	# ...while(!game_over)
	lw t0, game_over
	beq t0, 0, _game_loop

	# show the game over screen and exit
	jal show_game_over
syscall_exit

#-------------------------------------------------------------------------------------------------

show_game_over:
enter
	jal display_update_and_clear

	li   a0, 5
	li   a1, 10
	lstr a2, "GAME OVER"
	li   a3, COLOR_YELLOW
	jal  display_draw_colored_text

	li   a0, 5
	li   a1, 30
	lstr a2, "SCORE: "
	jal  display_draw_text

	li   a0, 41
	li   a1, 30
	lw   a2, score
	jal  display_draw_int

	jal display_update
leave

#-------------------------------------------------------------------------------------------------

update_all:
enter
	jal obj_move_all
	jal maybe_spawn_object
	jal player_collision
	jal offscreen_obj_removal
leave

#-------------------------------------------------------------------------------------------------

draw_all:
enter
	jal draw_tilemap
	jal obj_draw_all
	jal draw_hud
leave

#-------------------------------------------------------------------------------------------------

draw_tilemap:
enter s0, s1

li s0, 0 # Initialize row to 0
loop_row:
    bge s0, MAP_HEIGHT, exit_loop_row 	# IF STATEMENT

    li s1, 0		# Initialize col to 0
    loop_col:
        bge s1, MAP_WIDTH, exit_loop_col # IF STATEMENT
        
        # a0 = (col * 5) - 3;
	mul a0, s1, 5    
	addi a0, a0, -3 
        
        # a1 = (row * 5) + 4;
        mul a1, s0, 5
	addi a1, a1, 4       
        
        # t0 = tilemap[(row * MAP_WIDTH) + col];
        mul t0, s0, MAP_WIDTH 	# t0 = row * MAP_WIDTH
        add t0, t0, s1 		# t0 = t0 + col
        lb t0, tilemap(t0)
        
        # a2 = texture_atlas[t0 * 4];
        mul t0, t0, 4
        lw a2, texture_atlas(t0)
         
        jal display_blit_5x5_trans
        
        addi s1, s1, 1 	# Increment col by 1
        j loop_col 	# Jump to the beginning of the column loop
        
        

    exit_loop_col:
    addi s0, s0, 1 	# Increment row by 1
    j loop_row 		# Jump to the beginning of the row loop

exit_loop_row:
leave s0, s1

#-------------------------------------------------------------------------------------------------

draw_hud:
enter s0

# display_draw_int(0, 4, score);
li a0, 0
li a1, 4
lw a2, score
jal display_draw_int
	
# for(int s0 = 0; s0 >= lives; s0++)
li s0, 0 	# Initialize s0 to 0
_loop_lives:
	lw t0, lives # Load lives
	bge s0, t0, _exit_loop_lives
	
	# get x and y and hearts
	mul a0, s0, 5 		# X
	li a1, 59 		# Y
	la a2, tex_heart 	#hearts
	
	jal display_blit_5x5_trans
	
	add s0, s0, 1 # Increment -> s0++
	j _loop_lives
_exit_loop_lives:	
	
	


leave s0

#-------------------------------------------------------------------------------------------------

obj_draw_all:
enter s0

# Initialize s0 = cur_num_objs - 1
lb t0, cur_num_objs
sub s0, t0, 1
_loop_draw_all:
	blt s0, zero, _exit_draw_all
	
	# Load x and y 
	lb a0, object_x(s0)
	lb a1, object_y(s0)
	
	# Load pattern arg
	lb t0, object_type(s0)
	mul t0, t0, 4
	lw a2, obj_textures(t0)
	
	jal display_blit_5x5_trans
	
	addi s0, s0, -1
	j _loop_draw_all
_exit_draw_all:
	


leave s0

#-------------------------------------------------------------------------------------------------

obj_move_all:
enter s0

    li s0, 0            # Initialize s0 = 0
    lb t9, cur_num_objs # t9 = cur_num_objs

_loop_move_all:
    bge s0, t9, _exit_move_all # Exit the loop if s0 >= t9

    # Decrement object_timer[]
    lb t0, object_timer(s0)
    addi t0, t0, -1
    sb t0, object_timer(s0)

    blez t0, _if_less_equal # If object_timer[s0] <= 0, jump to if_less_equal
    j _endif_less_equal    # Otherwise, jump to endif_less_equal

_if_less_equal:
    # object_x(s0) += object_vel(s0)
    lb t0, object_x(s0)
    lb t1, object_vel(s0)
    add t0, t0, t1 # Add object_vel[s0] to object_x[s0]
    sb t0, object_x(s0)
    # object_timer(s0) = object_delay(s0)
    lb t0, object_delay(s0)
    sb t0, object_timer(s0)
    
_endif_less_equal:
    addi s0, s0, 1   # Increment s0 to move to the next object
    j _loop_move_all  # Jump back to the beginning of the loop

_exit_move_all:
leave s0

#-------------------------------------------------------------------------------------------------

check_input:
enter

    jal input_get_keys_pressed
    
    # cases
    beq v0, KEY_L, _case_L
    beq v0, KEY_R, _case_R
    beq v0, KEY_U, _case_U
    beq v0, KEY_D, _case_D
    
    j _break
    
    _case_L:	
    	lb t0, player_x
    	li t1, PLAYER_MIN_X
    	
    	# if(player_x > PLAYER_MIN_X)
    	bgt t0, t1, _L_greater
    	j _done_moving
    	
    	# player_x -= PLAYER_VELOCITY
    	_L_greater:
    		sub t0, t0, PLAYER_VELOCITY
    		sb t0, player_x
    		j _done_moving
    		
    _case_R:
        lb t0, player_x
        li t1, PLAYER_MAX_X
        
        # if(player_x < PLAYER_MAX_X)
        blt t0, t1, _R_less      
        j _done_moving
        
        # player_x += PLAYER_VELOCITY
        _R_less:
            add t0, t0, PLAYER_VELOCITY
            sb t0, player_x
            j _done_moving
    
    _case_U:
        lb t0, player_y
        li t1, PLAYER_MIN_Y
        
        # if(player_y > PLAYER_MIN_Y)
        bgt t0, t1, _U_greater
        j _done_moving
        
        # player_y -= PLAYER_VELOCITY
        _U_greater:
            sub t0, t0, PLAYER_VELOCITY
            sb t0, player_y   
            j _done_moving
        
        
    _case_D:
        lb t0, player_y
        li t1, PLAYER_MAX_Y
        
        #if(player_y < PLAYER_MAX_Y)  
        blt t0, t1, _D_less
        j _done_moving
        
        #player_y += PLAYER_VELOCITY
        _D_less:       
            addi t0, t0, PLAYER_VELOCITY
            sb t0, player_y
            
            j _done_moving

        
        
    _done_moving:
        sb zero, player_delay
        sb zero, player_vel
        sb zero, player_timer
    
    _break:
    
leave

#-------------------------------------------------------------------------------------------------

player_collision:
enter s0, s1
	
	# tilemap row // row = t0
	lb t0, player_y
	div t0, t0, 5 
        
        # tilemap col // col = t1
        lb t1, player_x
        div t1, t1, 5
	add t1, t1, 1       
        
        # t0 = tilemap[(row * MAP_WIDTH) + col];
        mul t0, t0, MAP_WIDTH 	# t0 = row * MAP_WIDTH
        add s0, t0, t1 		# t0 = t0 + col
        lb s0, tilemap(s0)
  
        
        bne s0, TILE_OUCH, _not_tile_ouch
        	jal kill_player
		j _return
	_not_tile_ouch:
		li s1, 0	# Initialize s1 -> 0
		_loop:
		# If i < cur_num_objs
		lw t0, cur_num_objs 	# Load cur_num_objs
		bge s1, t0, _end_loop
			lb a0, player_x
			lb a1, player_y
			lb a2, object_x(s1)
			lb a3, object_y(s1)
			jal bounds_check
			#print_str "after bounds \n"
			
			# if bounds_check returns 1
			bne v0, 1, _zero_bounds
				lb t0, object_type(s1)
				
				# If object_type = fast/slow car...
				beq t0, OBJ_CAR_FAST, _kill_the_player
				beq t0, OBJ_CAR_SLOW, _kill_the_player
				
				# If object_type = log/croc...
				beq t0, OBJ_LOG, _ride_on_it
				beq t0, OBJ_CROC, _ride_on_it
				
				# If object_type = goal...
				beq t0, OBJ_GOAL, _got_the_goal
				j _continue
					
				# Cases
				_kill_the_player:
					jal kill_player
					j _return
						
				_ride_on_it:
					move a0, s1
					jal player_move_with_object
					j _return
						
				_got_the_goal:
					move a0, s1
					jal player_get_goal
					j _return
				
		_zero_bounds:
	_continue:						
		addi s1, s1, 1
		j _loop
	_end_loop:
		bne s0, TILE_WATER, _not_water
			jal kill_player
		_not_water:
_return:
leave s0, s1

#-------------------------------------------------------------------------------------------------

kill_player:
enter
	# Setting lives to t9
	lw t9, lives
	
	# If lives = 1
	bne t9, 1, _take_life
	
		# frog reset
		li t0, PLAYER_START_X
		sb t0, player_x
		
		li t0, PLAYER_START_Y
		sb t0, player_y
		
		# other resets
		sb zero, player_delay
		sb zero, player_vel
		sb zero, player_timer
	
		bne zero, GRADER_MODE, _grader_mode
			li t0, 1
			sw t0, game_over
			j _end
	
		_grader_mode:
			j _end
			
	_take_life:
		
		# Decrement lives
		add t0, t9, -1
		sw t0, lives
		
		
		# frog reset
		li t0, PLAYER_START_X
		sb t0, player_x
		
		li t0, PLAYER_START_Y
		sb t0, player_y
		
		# other resets
		sb zero, player_delay
		sb zero, player_vel
		sb zero, player_timer
		
		j _end
		
	_end:
		

leave 

#-------------------------------------------------------------------------------------------------

player_get_goal:
enter 

	jal remove_obj
	lw t0, score
	add t0, t0, GOAL_SCORE
	sw t0, score
	
	bne t0, MAX_SCORE, equal_to
		li t0, 1
		sw t0, game_over
		
	equal_to:
		# frog reset
		li t0, PLAYER_START_X
		sb t0, player_x
		
		li t0, PLAYER_START_Y
		sb t0, player_y
		
		# other resets
		sb zero, player_vel
		sb zero, player_timer
		
leave

