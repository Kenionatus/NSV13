/datum/overmap_gamemode
	var/name = null											//!Name of the gamemode type
	var/config_tag = null									//!Tag for config file weight
	var/desc = null											//!Description of the gamemode for ADMINS
	var/brief = null										//!Description of the gamemode for PLAYERS
	var/selection_weight = 0								//!Used to determine the chance of this gamemode being selected
	var/required_players = 0								//!Required number of players for this gamemode to be randomly selected
	var/max_players = 0										//!Maximum amount of players allowed for this mode, 0 = unlimited
	var/difficulty = null									//!Difficulty of the gamemode as determined by player count / abus abuse: 1 is minimum, 10 is maximum
	var/starting_system = null								//!Here we define where our player ships will start
	var/starting_faction = null 							//!Here we define which faction our player ships belong
	///0 - Objectives reset remind. 1 - Combat resets reminder. 2 - Combat delays reminder. 3 - Disables reminder
	var/objective_reminder_setting = OVERMAP_MODE_REMINDER_OBJECTIVES
	var/objective_reminder_interval = 15 MINUTES			//!Interval between objective reminders
	var/combat_delay = 0									//!How much time is added to the reminder timer
	var/list/objectives = list()							//!The actual gamemode objectives go here after being selected
	var/list/fixed_objectives = list()						//!The fixed objectives for the mode - always selected
	var/list/random_objectives = list()						//!The random objectives for the mode - the pool to be chosen from
	var/random_objective_amount = 0							//!How many random objectives we are going to get
	var/whitelist_only = FALSE								//!Can only be selected through map bound whitelists
	var/debug_mode = FALSE 									//!Debug var, for gamemode-specific testing

	//Reminder messages
	var/reminder_origin = "Naval Command"
	var/reminder_one = "This is Centcomm to all vessels assigned to patrol the Rosetta Cluster, please continue on your mission"
	var/reminder_two = "This is Centcomm to all vessels assigned to patrol the Rosetta Cluster, your inactivity has been noted and will not be tolerated."
	var/reminder_three = "This is Centcomm to all vessels assigned to patrol the Rosetta Cluster, we are not paying you to idle in space during your assigned mission"
	var/reminder_four = "This is Centcomm to the vessel currently assigned to the Rosetta Cluster, you are expected to fulfill your assigned mission"
	var/reminder_five = "This is Centcomm, due to your slow pace, a Syndicate Interdiction fleet has tracked you down, prepare for combat!"

/datum/overmap_gamemode/New()
	objectives = list(
		/datum/overmap_objective/perform_jumps
	)

/datum/overmap_gamemode/Destroy()
	for(var/datum/overmap_objective/objective in objectives)
		QDEL_NULL(objective)
	objectives.Cut()
	. = ..()

/datum/overmap_gamemode/proc/consequence_one()

/datum/overmap_gamemode/proc/consequence_two()
	var/datum/faction/F = SSstar_system.faction_by_name(SSstar_system.find_main_overmap().faction)
	F.lose_influence(25)

/datum/overmap_gamemode/proc/consequence_three()
	var/datum/faction/F = SSstar_system.faction_by_name(SSstar_system.find_main_overmap().faction)
	F.lose_influence(25)

/datum/overmap_gamemode/proc/consequence_four()
	var/datum/faction/F = SSstar_system.faction_by_name(SSstar_system.find_main_overmap().faction)
	F.lose_influence(25)

/datum/overmap_gamemode/proc/consequence_five()
	//Hotdrop O'Clock
	var/obj/structure/overmap/OM = SSstar_system.find_main_overmap()
	var/datum/star_system/target
	if(SSstar_system.ships[OM]["current_system"] != null)
		target = OM.current_system
	else
		target = SSstar_system.ships[OM]["target_system"]
	priority_announce("Attention all ships throughout the fleet, assume DEFCON 1. A Syndicate invasion force has been spotted in [target]. All fleets must return to allied space and assist in the defense.") //need a faction message
	var/datum/fleet/F = new /datum/fleet/interdiction() //need a fleet
	target.fleets += F
	F.current_system = target
	F.assemble(target)
	SSovermap_mode.objective_reminder_stacks = 0 //Reset

/datum/overmap_gamemode/proc/check_completion() //This gets called by checking the communication console/modcomp program + automatically once every 10 minutes
	if(SSovermap_mode.already_ended)
		return
	if(SSovermap_mode.objectives_completed)
		victory()
		return

	var/objective_length = objectives.len
	var/objective_check = 0
	var/successes = 0
	var/failed = FALSE
	for(var/datum/overmap_objective/O in objectives)
		O.check_completion() 	//First we try to check completion on each objective
		if(O.status == OVERMAP_MODE_STATUS_OVERRIDE) //Victory override check
			victory()
			return
		else if(O.status == OVERMAP_MODE_STATUS_COMPLETED)
			objective_check ++
			successes++
		else if(O.status == OVERMAP_MODE_STATUS_FAILED)
			objective_check ++
			if(O.ignore_check == TRUE) //This was a gamemode objective
				failed = TRUE
	if(successes > SSovermap_mode.highest_objective_completion)
		SSovermap_mode.modify_threat_elevation(-TE_OBJECTIVE_THREAT_NEGATION * (successes - SSovermap_mode.highest_objective_completion))
		SSovermap_mode.highest_objective_completion = successes
	if(istype(SSticker.mode, /datum/game_mode/pvp)) //If the gamemode is PVP and a faction has over a 700 points, they win.
		for(var/datum/faction/F in SSstar_system.factions)
			var/datum/game_mode/pvp/mode = SSticker.mode
			if(F.tickets >= 700)
				mode.winner = F //This should allow the mode to finish up by itself
				mode.check_finished()
	if((objective_check >= objective_length) && !failed)
		victory()

/datum/overmap_gamemode/proc/victory()
	SSovermap_mode.objectives_completed = TRUE
	if(SSovermap_mode.admin_override)
		message_admins("[GLOB.station_name] has completed its objectives but round end has been overriden by admin intervention")
		return
	if(SSvote.mode == "Press On Or Return Home?") // We're still voting
		return

	var/datum/star_system/S = SSstar_system.return_system
	S.hidden = FALSE
	if(!SSovermap_mode.round_extended)	//If we haven't yet extended the round, let us vote!
		priority_announce("Mission Complete - Vote Pending") //TEMP get better words
		SSvote.initiate_vote("Press On Or Return Home?", "Centcomm", forced=TRUE, popup=FALSE)
	else	//Begin FTL return jump
		var/obj/structure/overmap/OM = SSstar_system.find_main_overmap()
		if(!length(OM.current_system?.enemies_in_system))
			priority_announce("Mission Complete - Returning to [S.name]") //TEMP get better words
			OM.force_return_jump()

/datum/overmap_gamemode/proc/defeat() //Override this if defeat is to be called based on an objective
	priority_announce("Mission Critical Failure - Standby for carbon asset liquidation")
	SSticker.mode.check_finished(TRUE)
	SSticker.force_ending = TRUE

/datum/overmap_objective
	var/name										//!Name for admin view
	var/desc										//!Short description for admin view
	var/brief										//!Description for PLAYERS
	var/stage										//!For multi step objectives
	var/binary = TRUE								//!Is this just a simple T/F objective?
	var/tally = 0									//!How many of the objective goal has been completed
	var/target = 0									//!How many of the objective goal is required
	var/status = OVERMAP_MODE_STATUS_INPROGRESS					//!0 = In-progress, 1 = Completed, 2 = Failed, 3 = Victory Override (this will end the round)
	var/extension_supported = FALSE 				//!Is this objective available to be a random extended round objective?
	var/ignore_check = FALSE						//!Used for checking extended rounds
	var/instanced = FALSE							//!Have we yet run the instance proc for this objective?
	var/objective_number = 0						//!The objective's index in the list. Useful for creating arbitrary report titles
	var/required_players = 0						//!Minimum number of players to get this if it's a random/extended objective
	var/maximum_players = 0							//!Maximum number of players to get this if it's a random/extended objective. 0 is unlimited.

/datum/overmap_objective/New()

/datum/overmap_objective/proc/instance() //!Used to generate any in world assets
	if ( SSovermap_mode.announced_objectives )
		// If this objective was manually added by admins after announce, prints a new report. Otherwise waits for the gamemode to be announced before instancing reports
		print_objective_report()

	instanced = TRUE

/datum/overmap_objective/proc/check_completion()

/datum/overmap_objective/proc/print_objective_report()

/datum/overmap_objective/custom
	name = "Custom"

/datum/overmap_objective/custom/New(passed_input) //!Receive the string and make it brief/desc
	.=..()
	desc = passed_input
	brief = passed_input
