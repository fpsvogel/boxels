def create_tiles(args, tiles_strings)
  size = args.state.laws.tile_size

  tiles_strings.reverse.flat_map.with_index { |row, y|
    row.chars.map.with_index { |char, x|
      if char == "x"
        {
          x: x * size,
          y: y * size,
          w: size,
          h: size,
          r: 255,
          g: 0,
          b: 0,
        }
      end
    }.compact
  }
end

def add_player_walk(args)
  dx =
    if args.inputs.left
     -args.state.player.walk_accel
    elsif args.inputs.right
      args.state.player.walk_accel
    end

  return unless dx

  # Add walk movement only if the player hasn't reached walk speed, or if it
  # wouldn't make the player move faster (e.g. for decelerating after an impact).
  excess_dx = args.state.player.dx.abs - args.state.player.walk_speed
  excess_dx_after_movement = (args.state.player.dx + dx).abs - args.state.player.walk_speed

  if excess_dx < 0 || excess_dx_after_movement < excess_dx
    args.state.player.dx += dx
  end
end

def add_gravity(args)
  args.state.player.dy -= args.state.laws.gravity
end

def move_player(axis, args)
  args.state.player[axis] += args.state.player[:"d#{axis}"]
end

def check_for_collisions(axis, args)
  intersecting_tile = args.state.tiles.find { |t| t.intersect_rect?(args.state.player) }

  # If there is a collision, move the player to the edge of the collision based
  # on the direction of the player's movement and set the player's dx/dy to 0.
  if intersecting_tile
    measurement = axis == :x ? :w : :h
    speed_on_axis = :"d#{axis}"

    if args.state.player[speed_on_axis] > 0
      args.state.player[axis] = intersecting_tile[axis] - args.state.player[measurement]
    elsif args.state.player[speed_on_axis] < 0
      args.state.player[axis] = intersecting_tile[axis] + intersecting_tile[measurement]
    end

    args.state.player[speed_on_axis] *= -args.state.player.coefficent_of_restitution

    # TODO add friction

    # Jump. # TODO make into a hook
    if axis == :y && args.inputs.up && intersecting_tile.y < args.state.player.y
      args.state.player.dy += args.state.player.jump_power
    end
  end
end

def tick(args)
  args.state.laws ||= {
    tile_size: 50,
    gravity: 0.5,
  }
  args.state.player ||= {
    x: 120,
    y: 500,
    w: args.state.laws.tile_size,
    h: args.state.laws.tile_size,
    r: 0,
    g: 0,
    b: 255,
    dx: 0,
    dy: 0,
    walk_accel: 1,
    walk_speed: 10,
    jump_power: 13,
    coefficent_of_restitution: 0.2,
  }
  args.state.tiles ||= create_tiles(args, %w[
    ..........................
    ..........................
    ..........................
    ..........................
    ..............xxx.........
    ..........................
    ..........................
    ...................xxx...x
    x........................x
    x.............xxx........x
    x.......x.....x..........x
    xxxxxxxxxxxxxxxxxxxxxxxxxx
  ])

  add_player_walk(args)
  add_gravity(args)
  move_player(:x, args)
  check_for_collisions(:x, args) # TODO? use GTK::Geometry.find_collisions
  move_player(:y, args)
  check_for_collisions(:y, args)

  args.outputs.solids << args.state.player
  args.outputs.static_solids << args.state.tiles unless args.outputs.static_solids.any?
  args.outputs.labels << { x: 60, y: 90.from_top, text: "FPS: #{args.gtk.current_framerate.to_sf}" }
end

$gtk.reset
