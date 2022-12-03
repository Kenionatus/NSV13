#define MIN_RADAR_DELAY 5 SECONDS
#define MAX_RADAR_DELAY 60 SECONDS
#define RADAR_VISIBILITY_PENALTY 5 SECONDS
#define SENSOR_MODE_PASSIVE 1
#define SENSOR_MODE_RADAR 2

/datum/component/radar_ui
	dupe_mode = COMPONENT_DUPE_ALLOWED

/obj/machinery/computer/ship/dradis
	name = "\improper DRADIS computer"
	desc = "The DRADIS system is a series of highly sensitive detection, identification, navigation and tracking systems used to determine the range and speed of objects. This forms the most central component of a spaceship's navigational systems, as it can project the whereabouts of enemies that are out of visual sensor range by tracking their engine signatures."
	icon_screen = "teleport"
	req_access = list()
	circuit = /obj/item/circuitboard/computer/ship/dradis
	var/usingBeacon = FALSE //Var copied from express consoles so this doesn't break. I love abusing inheritance ;)
	var/obj/item/supplypod_beacon/beacon
	var/datum/component/radar_ui/radar_type = datum/component/radar_ui

/obj/machinery/computer/ship/dradis/examine(mob/user)
	. = ..()
	. += "<span class='sciradio'>You can link supplypod beacons to it to tell traders where to deliver your goods! Hit it with a multitool to swap between delivery locations.</span>"
	if(beacon)
		. += "<span class='sciradio'>It's currently linked to [beacon] in [get_area(beacon)]. You can use a multitool to switch whether it delivers here, or to your cargo bay.</span>"

/obj/machinery/computer/ship/dradis/attackby(obj/item/W, mob/living/user, params)
	if(istype(W, /obj/item/supplypod_beacon))
		var/obj/item/supplypod_beacon/sb = W
		if(linked?.dradis != src)
			to_chat(user, "<span class='warning'>Supplypod beacons can only be linked to the primary DRADIS of a ship (try the one in CIC?).</span>")
			return FALSE
		if (sb.express_console != src)
			sb.link_console(src, user)
			return TRUE
		else
			to_chat(user, "<span class='notice'>[src] is already linked to [sb].</span>")
	..()

/obj/machinery/computer/ship/dradis/multitool_act(mob/living/user, obj/item/I)
	usingBeacon = !usingBeacon
	to_chat(user, "<span class='sciradio'>You switch [src]'s trader delivery location to [usingBeacon ? "target supply beacons" : "target the default landing location on your ship"]</span>")
	return TRUE



// Dradis and radar UI subtypes


/**
 * Secondary dradis consoles usable by people who arent on the bridge.
 * All secondary dradis consoles should be a subtype of this.
 */
/obj/machinery/computer/ship/dradis/minor
	name = "air traffic control console"
	radar_ui = /datum/component/radar_ui/minor

/datum/component/radar_ui/minor


/**
 * Another dradis like air traffic control, links to cargo torpedo tubes and delivers freight.
 */
/obj/machinery/computer/ship/dradis/minor/cargo
	name = "\improper Cargo freight delivery console"
	circuit = /obj/item/circuitboard/computer/ship/dradis/cargo
	var/obj/machinery/ship_weapon/torpedo_launcher/cargo/linked_launcher = null
	var/dradis_id = null
	radar_type = datum/component/radar_ui

/obj/machinery/computer/ship/dradis/minor/cargo/Initialize()
	. = ..()
	var/obj/item/paper/paper = new /obj/item/paper(get_turf(src))
	paper.info = ""
	paper.info += "<h2>How to perform deliveries with the Cargo DRADIS</h2>"
	paper.info += "<hr/><br/>"
	paper.info += "Step 1: Find or build a freight torpedo.<br/><br/>"
	paper.info += "Step 2: Load your contents directly into the freight torpedo. Or load your contents into a crate, then load the crate into the freight torpedo (click drag the object onto the torpedo).<br/><br/>"
	paper.info += "Step 3: Load the freight torpedo into the Cargo freight launcher (click drag the torpedo onto the launcher). You may need to use a munitions trolley to move the freight torpedo closer.<br/><br/>"
	paper.info += "Step 4: Use the munitions console to load the payload, chamber the payload, and disable weapon safeties.<br/><br/>"
	paper.info += "Step 5: Put on hearing protection gear, such as earmuffs.<br/><br/>"
	paper.info += "Step 6: Navigate to the cargo DRADIS, and click on the recipient. If the payload is malformed or not chambered, an error will display. If the payload is properly chambered, a final confirmation will display. Click Yes.<br/><br/>"
	paper.update_icon()

	if(!linked_launcher)
		if(dradis_id) //If mappers set an ID
			for(var/obj/machinery/ship_weapon/torpedo_launcher/cargo/W in GLOB.machines)
				if(W.launcher_id == dradis_id && W.z == z)
					linked_launcher = W
					W.linked_dradis = src

/obj/machinery/computer/ship/dradis/minor/cargo/multitool_act(mob/living/user, obj/item/I)
	// Allow relinking a console's cargo launcher
	var/obj/item/multitool/P = I
	// Check to make sure the buffer is a valid cargo launcher before acting on it
	if( ( multitool_check_buffer(user, I) && istype( P.buffer, /obj/machinery/ship_weapon/torpedo_launcher/cargo ) ) )
		var/obj/machinery/ship_weapon/torpedo_launcher/cargo/launcher = P.buffer
		launcher.linked_dradis = src
		linked_launcher = launcher
		P.buffer = null
		to_chat(user, "<span class='notice'>Buffer transferred</span>")
		return TRUE
	// Call the parent proc and allow supply beacon swaps
	else
		return ..()

/datum/component/radar_ui/cargo
	dupe_mode = COMPONENT_DUPE_HIGHLANDER

/datum/component/radar_ui/cargo/New()
	base_sensor_range = hail_range
	. = ..()


/obj/machinery/computer/ship/dradis/mining
	name = "mining DRADIS computer"
	desc = "A modified dradis console which links to the mining ship's mineral scanners, able to pick up asteroids that can be mined."
	req_one_access_txt = "31;48"
	circuit = /obj/item/circuitboard/computer/ship/dradis/mining

/datum/component/radar_ui/mining
	var/show_asteroids = TRUE


/**
 * radar_ui for attaching to small ships (fighters, sabres...)
 */
/datum/component/radar_ui/internal
	start_with_sound = FALSE
	base_sensor_range = SENSOR_RANGE_FIGHTER
	hail_range = 30

/**
Adds a penalty to from how far away you can be detected.
This is completely independant from normal tracking, you get detected either if you are within their sensor range, or if your sensor profile is big enough to be detected by them
args:
penalty: The amount of additional sensor profile
remove_in: Optional arg, if > 0: Will remove the effect in that amount of ticks
*/
/obj/structure/overmap/proc/add_sensor_profile_penalty(penalty, remove_in = -1)
	sensor_profile += penalty
	if(remove_in < 1)
		return
	addtimer(CALLBACK(src, .proc/remove_sensor_profile_penalty, penalty), remove_in)

/**
Reduces sensor profile by the amount given as arg.
Called by add_sensor_profile_penalty if remove_in is used.
*/
/obj/structure/overmap/proc/remove_sensor_profile_penalty(amount)
	sensor_profile -= amount
