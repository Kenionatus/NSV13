/obj/machinery/ship_weapon/hybrid
	name = "Hybrid ship weapon class"
	desc = "Don't use this directly. Use subtypes"

	active_power_usage = 0 //! Going to pull from a wire rather then APC
	idle_power_usage = 50 //! We'll scale this with charge - if its charged, its gonna be leaking

	var/capacitor_charge = 0 //! Current capacitor charge
	var/capacitor_max_charge = 400000 //! Maximum charge required for firing - as determined by ammo type - preset to slug
	var/capacitor_current_charge_rate = 0 //! Current charge rate - as determined by players
	var/capacitor_max_charge_rate = 200000 //! Maximum rate of charge ie max power draw - 200kW

/obj/machinery/ship_weapon/hybrid/process()
	if(capacitor_charge == capacitor_max_charge)
		active_power_usage = capacitor_charge / 10 //We still draw to maintain charge
	if(!try_use_power(active_power_usage))
		if(capacitor_charge > 0)
			capacitor_charge -= (capacitor_charge / capacitor_max_charge) * 500 //Slowly depletes capacitor if not maintaining power supply
			set_light(3, 4, LIGHT_COLOR_RED)
			if(capacitor_charge <= 0)
				capacitor_charge = 0
		return FALSE
	if(capacitor_current_charge_rate == 0)
		set_light(3, 4, LIGHT_COLOR_RED)
		return FALSE
	if(capacitor_charge < capacitor_max_charge)
		capacitor_charge += capacitor_current_charge_rate
		set_light(3, 4, LIGHT_COLOR_LIGHT_CYAN)
	if(capacitor_charge >= capacitor_max_charge)
		capacitor_charge = capacitor_max_charge
		set_light(3, 4, LIGHT_COLOR_LIGHT_CYAN)

/obj/machinery/ship_weapon/hybrid_rail/fire(atom/target, shots = weapon_type.burst_size, manual = TRUE)
	set waitfor = FALSE //As to not hold up any feedback messages.
	if(can_fire(shots))
		if(manual)
			linked.last_fired = overlay
		for(var/i = 0, i < shots, i++)
			state = STATE_FIRING
			do_animation()
			overmap_fire(target)

			ammo -= chambered
			local_fire()
			qdel(chambered)
			chambered = null
			capacitor_charge = 0

			if(length(ammo))
				state = STATE_FED
			else
				state = STATE_NOTLOADED
			//Semi-automatic, chamber the next one
			if(semi_auto)
				chamber(rapidfire = TRUE)
			after_fire()
	return FALSE

/**
 * Attempt to draw power from power node below gun.
 *
 * Arguments:
 * * amount: Watts of power to draw
 *
 * Returns:
 * * TRUE if enough power is available, powernet available and draw successful, FALSE othewise
 */
/obj/machinery/ship_weapon/hybrid/proc/try_use_power(amount)
	var/turf/T = get_turf(src)
	var/obj/structure/cable/C = T.get_cable_node()
	if(C)
		if(!C.powernet)
			return FALSE
		var/power_in_net = CLAMP(C.powernet.avail - C.powernet.load, 0, C.powernet.avail)

		if(power_in_net && power_in_net >= amount)
			C.powernet.load += amount
			return TRUE
		return FALSE
	return FALSE
