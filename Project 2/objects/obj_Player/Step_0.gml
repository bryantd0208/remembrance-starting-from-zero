// --- HORIZONTAL MOVEMENT INPUT ---
var moving = false;

if (keyboard_check(vk_left) || keyboard_check(ord("A"))) {
    image_xscale = -1;
    hspeed = -player_speed;
    moving = true;
}
else if (keyboard_check(vk_right) || keyboard_check(ord("D"))) {
    image_xscale = 1;
    hspeed = player_speed;
    moving = true;
}
else {
    hspeed = 0;
}

// --- JUMP INPUT ---
var ground_check_offset = gravity_flip;

if ((keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W")))) {
    if (place_meeting(x, y + ground_check_offset, obj_CollisionTiles)) {
        vspeed = -jump_force * gravity_flip;
        audio_play_sound(snd_player_jump, 1, false); // 🔊 jump
    }
    else if (wall_slide) {
        vspeed = -wall_jump_v_force * gravity_flip;
        hspeed = -wall_dir * wall_jump_h_force;
        wall_slide = false;
        audio_play_sound(snd_player_jump, 1, false); // 🔊 wall jump
    }
}

// --- SHORT HOP CONTROL ---
if (vspeed * gravity_flip < 0) {
    if (!(keyboard_check(vk_up) || keyboard_check(ord("W")))) {
        var max_short_hop_vspeed = 2.5;
        if (abs(vspeed) > max_short_hop_vspeed) {
            vspeed = -max_short_hop_vspeed * gravity_flip;
        }
    }
}

// --- UPDATE STATE ---
if (!moving) {
    player_state = PlayerState.IDLE;
} else {
    if (keyboard_check(vk_shift)) {
        player_speed = run_speed;
        player_state = PlayerState.RUNNING;
    } else {
        player_speed = base_speed;
        player_state = PlayerState.WALKING;
    }

    // 🔊 Footstep sound (light control, only one per press)
    if (grounded && !audio_is_playing(snd_player_step)) {
        audio_play_sound(snd_player_step, 1, false);
    }
}

// --- HORIZONTAL COLLISION ---
wall_slide = false;
wall_dir = 0;

if (place_meeting(x + hspeed, y, obj_CollisionTiles)) {
    if (hspeed != 0) {
        wall_slide = true;
        wall_dir = sign(hspeed);
    }
    hspeed = 0;
}

if (wall_slide) {
    show_debug_message("Wall sliding! Grounded = " + string(grounded));
}

// --- VERTICAL COLLISION ---
if (place_meeting(x, y + vspeed, obj_CollisionTiles)) {
    var sign_v = sign(vspeed);
    while (!place_meeting(x, y + sign_v, obj_CollisionTiles)) {
        y += sign_v;
    }
    vspeed = 0;
} else {
    if (abs(vspeed) < 1 && place_meeting(x, y + sign(gravity_flip), obj_CollisionTiles)) {
        while (!place_meeting(x, y + sign(gravity_flip), obj_CollisionTiles)) {
            y += sign(gravity_flip);
        }
        vspeed = 0;
    }
    else {
        y += vspeed;
    }
}

// --- APPLY HORIZONTAL MOVEMENT ---
x += hspeed;

// --- LANDING SOUND (trigger on actual transition) ---
var prev_grounded = grounded;
grounded = place_meeting(x, y + gravity_flip, obj_CollisionTiles);

if (!prev_grounded && grounded) {
    audio_play_sound(snd_player_land, 1, false); // 🔊 land
}

// --- GLOBAL HIT FREEZE ---
if (global.hit_freeze_timer > 0) {
    global.hit_freeze_timer -= 1;
    exit;
}

// --- DAMAGE HANDLING ---
if (player_state == PlayerState.DAMAGED) {
    if (!damage_taken) {
        current_health -= 30;
        damage_taken = true;
        show_debug_message("Player took damage! HP: " + string(current_health));
    }

    damage_timer += 1;
    hspeed = lerp(hspeed, knockback_target_hspeed, 0.25);
    vspeed = lerp(vspeed, knockback_target_vspeed, 0.25);

    if (damage_timer > 10) {
        damage_timer = 0;
        player_state = PlayerState.IDLE;
        hspeed = 0;
        vspeed = 0;
        knockback_target_hspeed = 0;
        knockback_target_vspeed = 0;
        damage_taken = false;
    }
}

// --- STATE INPUT CHECK (DEFEND, ATTACK) ---
if (player_state != PlayerState.DAMAGED) {
    if (keyboard_check(vk_control)) {
        player_state = PlayerState.DEFENDING;
    }
    else if (keyboard_check_pressed(vk_space)) {
        if (player_state != PlayerState.DEFENDING) {
            player_state = PlayerState.ATTACKING;

            var slash_offset = 32;
            var slash_x = x + (image_xscale * slash_offset);
            var slash_y = y;

            var slash = instance_create_layer(slash_x, slash_y, "Instances", obj_sword_slash);

            if (image_xscale == -1) {
                slash.direction = 180;
                slash.image_xscale = -1;
            } else {
                slash.direction = 0;
                slash.image_xscale = 1;
            }

        }
    }
}

// --- GRAVITY FLIP CHECK ---
if (keyboard_check_pressed(ord("G")) && !global.gravity_flipping) {
    scr_gravity_flip();
}
if (global.gravity_flipping) {
    scr_gravity_flip();
}

// --- STORY START (Escape) ---
if (keyboard_check(vk_escape)) {
    var story = [
        "Once upon a time, a raccoon cleaned the world...",
        "He faced many dangers and obstacles ahead.",
        "But with courage, he continued forward."
    ];
    scr_start_dialogue(story, spr_zero_text);
}

// --- OUT OF BOUNDS DEATH CHECK ---
if (!global.game_lost) {
    var buffer = 300;
    if (x < -buffer || x > 1920 + buffer || y < -buffer || y > 1080 + buffer) {
        global.game_lost = true;
        room_goto(rm_Lose);
    }
}


// --- LOSS CONDITION ---
if (current_health <= 0 && !global.game_lost) {
    global.game_lost = true;
    room_goto(rm_Lose);
}


// --- APPLY GRAVITY and WALL SLIDE ---
if (!grounded) {
    vspeed += gravity_force * gravity_flip;

    if (wall_slide && vspeed * gravity_flip > wall_slide_speed) {
        vspeed = wall_slide_speed * gravity_flip;
    }
} else {
    if (sign(vspeed) == sign(gravity_flip)) {
        vspeed = 0;
    }
}

// --- Familiar Teleport Control ---
if (keyboard_check_pressed(ord("F"))) {
    if (!variable_global_exists("familiar_mode")) global.familiar_mode = 0;
    global.familiar_mode = (global.familiar_mode + 1) mod 3;

    if (global.familiar_mode == 1) {
        show_debug_message("Select a location for the familiar.");
    } else if (global.familiar_mode == 2) {
        show_debug_message("Familiar locked in place.");
    } else {
        show_debug_message("Familiar is following again.");
    }
}

if (global.familiar_mode == 1 && mouse_check_button_pressed(mb_left)) {
    global.familiar_target_x = camera_get_view_x(view_camera[0]) + mouse_x;
    global.familiar_target_y = camera_get_view_y(view_camera[0]) + mouse_y;
    global.familiar_mode = 2;

    show_debug_message("Familiar target selected at: " + string(global.familiar_target_x) + ", " + string(global.familiar_target_y));
}

if (sprite_index == -1) sprite_index = spr_CollisionTileTest;

visible = true;
image_alpha = 1;
image_blend = c_white;
depth = -10000;

// --- PASSIVE HEALTH REGEN ---
if (player_state != PlayerState.ATTACKING && player_state != PlayerState.RUNNING && grounded && current_health < max_health) {
    regen_timer += 1;

    if (regen_timer >= regen_interval) {
        current_health = min(current_health + regen_amount, max_health);
        regen_timer = 0;
    }
} else {
    regen_timer = 0;
}
