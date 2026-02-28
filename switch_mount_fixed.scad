rack_width = 254.0; // [ 254.0:10 inch, 152.4:6 inch]
rack_height = 1.0; // [0.5:0.5:5]
half_height_holes = true; // [true:Show partial holes at edges, false:Hide partial holes]

switch_width = 135.0;
switch_depth = 135.0;
switch_height = 28.30;

front_wire_holes = false; // [true:Show front wire holes, false:Hide front wire holes]
air_holes = true; // [true:Show air holes, false:Hide air holes]
print_orientation = true; // [true: Place on printbed, false: Facing forward]
tolerance = 0.42;

/* [Hidden] */
height = 44.45 * rack_height;


// The main module containing all internal variables
module switch_mount(switch_width, switch_height, switch_depth) {
    //6 inch racks (mounts=152.4mm; rails=15.875mm; usable space=120.65mm)
    //10 inch racks (mounts=254.0mm; rails=15.875mm; usable space=221.5mm)
    chassis_width = min(switch_width + 12, (rack_width == 152.4) ? 120.65 : 221.5);
    front_thickness = 3.0;
    corner_radius = 4.0;
    chassis_edge_radius = 2.0;
    tolerance = 0.42;

    zip_tie_hole_count = 8;
    zip_tie_hole_width = 1.5;
    zip_tie_hole_length = 5;
    zip_tie_indent_depth = 2;
    zip_tie_cutout_depth = 7;

    chassis_depth_main = switch_depth + zip_tie_cutout_depth;
    chassis_depth_indented = chassis_depth_main - zip_tie_indent_depth;

    hole_total_width = zip_tie_hole_count * zip_tie_hole_width;
    space_between_holes = (rack_width - hole_total_width) / (zip_tie_hole_count + 1);

    $fn = 64;

    // Calculated dimensions
    cutout_w = switch_width + (2 * tolerance);
    cutout_h = switch_height + (2 * tolerance);
    cutout_x = (rack_width - cutout_w) / 2;
    cutout_y = (height - cutout_h) / 2;

    // Helper modules
    module capsule_slot_2d(L, H) {
        hull() {
            translate([-L/2 + H/2, 0]) circle(r=H/2);
            translate([L/2 - H/2, 0]) circle(r=H/2);
        }
    }

    module rounded_rect_2d(w, h, r) {
        hull() {
            translate([r, r]) circle(r=r);
            translate([w-r, r]) circle(r=r);
            translate([w-r, h-r]) circle(r=r);
            translate([r, h-r]) circle(r=r);
        }
    }

    module rounded_chassis_profile(width, height, radius, depth) {
        hull() {
            translate([radius, radius, 0]) cylinder(h = depth, r = radius);
            translate([width - radius, radius, 0]) cylinder(h = depth, r = radius);
            translate([radius, height - radius, 0]) cylinder(h = depth, r = radius);
            translate([width - radius, height - radius, 0]) cylinder(h = depth, r = radius);
        }
    }

    // Create the main body as a separate module
    module main_body() {
        side_margin = (rack_width - chassis_width) / 2;
        chassis_height = switch_height + 12;
        union() {
            // Front panel
            linear_extrude(height = front_thickness) {
                rounded_rect_2d(rack_width, height, corner_radius);
            }
            // Chassis body
            translate([side_margin, (height - chassis_height) / 2, front_thickness]) {
                rounded_chassis_profile(chassis_width, chassis_height, chassis_edge_radius, chassis_depth_main - front_thickness);
            }
        }
    }

    // Create switch cutout with proper lip
    module switch_cutout() {
        lip_thickness = 1.2;
        lip_depth = 0.60;
        // Main cutout minus lip (centered)
        translate([
            (rack_width - (cutout_w - 2*lip_thickness)) / 2,
            (height - (cutout_h - 2*lip_thickness)) / 2,
            -tolerance
        ]) {
            cube([cutout_w - 2*lip_thickness, cutout_h - 2*lip_thickness, chassis_depth_main]);
        }

        // Switch cutout above the lip (centered)
        translate([
            (rack_width - cutout_w) / 2,
            (height - cutout_h) / 2,
            lip_depth
        ]) {
            cube([cutout_w, cutout_h, chassis_depth_main]);
        }
    }

    // Create all rack holes
    module all_rack_holes() {
        hole_spacing_x = (rack_width == 152.4) ? 136.526 : 236.525;
        hole_left_x = (rack_width - hole_spacing_x) / 2;
        hole_right_x = (rack_width + hole_spacing_x) / 2;

        slot_len = (rack_width == 152.4) ? 6.5 : 10.0;
        slot_height = (rack_width == 152.4) ? 3.25 : 7.0;

        u_hole_positions = [6.35, 22.225, 38.1];
        max_u = ceil(rack_height);

        for (side_x = [hole_left_x, hole_right_x]) {
            for (u = [0:max_u-1]) {
                for (hole_pos = u_hole_positions) {
                    hole_y = height - (u * 44.45 + hole_pos);
                    fully_inside = (hole_y >= slot_height/2 && hole_y <= height - slot_height/2);
                    partially_inside = (hole_y + slot_height/2 > 0 && hole_y - slot_height/2 < height);
                    show_hole = fully_inside || (half_height_holes && partially_inside && !fully_inside);
                    if (show_hole) {
                        translate([side_x, hole_y, 0]) {
                            linear_extrude(height = chassis_depth_main) {
                                capsule_slot_2d(slot_len, slot_height);
                            }
                        }
                    }
                }
            }
        }
    }

    // Power wire cutouts
    module power_wire_cutouts() {
        hole_spacing_x = switch_width;
        hole_diameter = 7;
        hole_left_x = (rack_width - hole_spacing_x) / 2 - (hole_diameter /5);
        hole_right_x = (rack_width + hole_spacing_x) / 2 + (hole_diameter /5);
        mid_y = (height - switch_height) / 2 + switch_height / 2;
        for (side_x = [hole_left_x, hole_right_x]) {
            translate([side_x, mid_y, 0]) {
                linear_extrude(height = chassis_depth_main) {
                    circle(d=hole_diameter);
                }
            }
        }
    }

    // Create zip tie holes and indents
    module zip_tie_features() {
        for (i = [0:zip_tie_hole_count-1]) {
            x_pos = (rack_width - switch_width)/2 + (switch_width/(zip_tie_hole_count+1)) * (i+1);
            translate([x_pos, 0, switch_depth]) {
                cube([zip_tie_hole_width, height, zip_tie_hole_length]);
            }
        }

        x_pos = (rack_width - switch_width)/2;
        chassis_height = switch_height + 12;
        translate([x_pos, (height - chassis_height)/2, switch_depth]) {
            cube([switch_width, zip_tie_indent_depth, zip_tie_cutout_depth]);
        }
        translate([x_pos, (height + chassis_height)/2 - zip_tie_indent_depth, switch_depth]) {
            cube([switch_width, zip_tie_indent_depth, zip_tie_cutout_depth]);
        }
    }

    // Air holes: staggered hexagonal honeycomb on all 4 sides of the chassis.
    //
    // Coordinate system reminder:
    //   X = rack width direction (left ↔ right)
    //   Y = rack height direction (bottom ↔ top)
    //   Z = depth direction (front → back)
    //
    // The 4 sides and their drill axes:
    //   TOP    face  → cylinder drills in −Y  ┐ one pass cuts both
    //   BOTTOM face  → cylinder drills in +Y  ┘ faces simultaneously
    //   LEFT   face  → cylinder drills in +X  ┐ one pass cuts both
    //   RIGHT  face  → cylinder drills in −X  ┘ faces simultaneously
    //
    // FIX SUMMARY vs original:
    //
    // Bug 1 – TOP/BOTTOM: cylinders anchored at y=height with h=height only
    // spanned y=0..height. When switch_height made the chassis taller than
    // the rack panel (chassis extends to chassis_top_y > height), the
    // cylinders were fully inside the hollow interior → holes vanished.
    // Fix: start above chassis_top_y and use length = chassis_h_total + 2×hole_d.
    //
    // Bug 2 – LEFT/RIGHT: the previous revision restricted side holes to the
    // narrow bands above/below the switch opening. But the LEFT and RIGHT walls
    // are solid for the FULL chassis height — the switch opening only cuts
    // through the interior, not through the walls. So available_height must
    // be chassis_h_total, not the opening-band remnants.

    module air_holes() {
        hole_d    = 16;
        spacing_x = 15;   // grid pitch in X / Y
        spacing_z = 17;   // grid pitch in Z (depth)
        margin    = 3;    // keep holes away from all edges

        // ── Shared geometry ────────────────────────────────────────────────

        // Full chassis vertical extents in Y
        chassis_h_total  = switch_height + 12;
        chassis_top_y    = (height + chassis_h_total) / 2;
        chassis_bottom_y = (height - chassis_h_total) / 2;

        // Full chassis horizontal extents in X
        chassis_w_local  = min(switch_width + 12, (rack_width == 152.4) ? 120.65 : 221.5);
        side_margin_x    = (rack_width - chassis_w_local) / 2;

        // Depth-direction centre of the switch cavity
        cutout_center_x = rack_width / 2;
        cutout_center_z = front_thickness + switch_depth / 2;

        // Z grid — shared by all faces
        available_depth   = switch_depth - (2 * margin);
        z_cols            = floor(available_depth / spacing_z);
        actual_grid_depth = (z_cols - 1) * spacing_z;
        z_start           = cutout_center_z - actual_grid_depth / 2;

        // Returns true when a Z position keeps the hole within the depth bounds
        function z_ok(z) =
            z + hole_d/2 <= cutout_center_z + switch_depth/2 - margin &&
            z - hole_d/2 >= cutout_center_z - switch_depth/2 + margin;

        // ── TOP & BOTTOM faces ─────────────────────────────────────────────
        // Cylinders drill from above chassis_top_y through to chassis_bottom_y.
        // The X grid spans switch_width (the region bounded by solid top/bottom
        // walls). Stagger: alternate X columns offset by spacing_z/2 in Z.

        available_width   = switch_width - (2 * margin);
        x_rows_tb         = floor(available_width / spacing_x);
        actual_grid_width = (x_rows_tb - 1) * spacing_x;
        x_start_tb        = cutout_center_x - actual_grid_width / 2;

        drill_tb_y_start  = chassis_top_y + hole_d;           // above top face
        drill_tb_y_length = chassis_h_total + 2 * hole_d;     // through bottom face

        if (x_rows_tb > 0 && z_cols > 0) {
            for (i = [0 : x_rows_tb - 1]) {
                for (j = [0 : z_cols - 1]) {
                    z_offset = (i % 2 == 1) ? spacing_z / 2 : 0;
                    x_pos    = x_start_tb + i * spacing_x;
                    z_pos    = z_start    + j * spacing_z + z_offset;

                    if (z_ok(z_pos)) {
                        translate([x_pos, drill_tb_y_start, z_pos]) {
                            rotate([90, 0, 0]) {
                                cylinder(h = drill_tb_y_length, d = hole_d, $fn = 6);
                            }
                        }
                    }
                }
            }
        }

        // ── LEFT & RIGHT faces ─────────────────────────────────────────────
        // The side walls are solid for the FULL chassis height — use
        // chassis_h_total as the available Y span, not switch_height.
        // Cylinders drill from outside the left wall through to the right wall.
        // Stagger: alternate Y rows offset by spacing_z/2 in Z.

        available_height   = chassis_h_total - (2 * margin);
        y_rows_lr          = floor(available_height / spacing_x);
        actual_grid_height = (y_rows_lr - 1) * spacing_x;
        y_center_lr        = height / 2;                        // = chassis centre in Y
        y_start_lr         = y_center_lr - actual_grid_height / 2;

        drill_lr_x_start  = side_margin_x - hole_d;            // outside left wall
        drill_lr_x_length = chassis_w_local + 2 * hole_d;      // through right wall

        if (y_rows_lr > 0 && z_cols > 0) {
            for (i = [0 : y_rows_lr - 1]) {
                for (j = [0 : z_cols - 1]) {
                    z_offset = (i % 2 == 1) ? spacing_z / 2 : 0;
                    y_pos    = y_start_lr + i * spacing_x;
                    z_pos    = z_start    + j * spacing_z + z_offset;

                    if (z_ok(z_pos)) {
                        translate([drill_lr_x_start, y_pos, z_pos]) {
                            rotate([0, 90, 0]) {
                                rotate([0, 0, 90]) {
                                    cylinder(h = drill_lr_x_length, d = hole_d, $fn = 6);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Main assembly
    translate([-rack_width/2, -height/2, 0]) {
        difference() {
            main_body();
            union() {
                switch_cutout();
                all_rack_holes();
                zip_tie_features();
                if (front_wire_holes) {
                    power_wire_cutouts();
                }
                if (air_holes) {
                    air_holes();
                }
            }
        }
    }
}

// Call the module
if (print_orientation) {
    switch_mount(switch_width, switch_height, switch_depth);
} else {
    rotate([-90,0,0])
        translate([0, -height/2, -switch_depth/2])
            switch_mount(switch_width, switch_height, switch_depth);
}
