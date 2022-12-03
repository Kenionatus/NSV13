#define MIN_RADAR_DELAY 5 SECONDS
#define MAX_RADAR_DELAY 60 SECONDS
#define RADAR_VISIBILITY_PENALTY 5 SECONDS
#define SENSOR_MODE_PASSIVE 1
#define SENSOR_MODE_RADAR 2


/obj/machinery/computer/ship/dradis
	name = "\improper DRADIS computer"
	desc = "The DRADIS system is a series of highly sensitive detection, identification, navigation and tracking systems used to determine the range and speed of objects. This forms the most central component of a spaceship's navigational systems, as it can project the whereabouts of enemies that are out of visual sensor range by tracking their engine signatures."
	icon_screen = "teleport"
	req_access = list()
	circuit = /obj/item/circuitboard/computer/ship/dradis
	var/usingBeacon = FALSE //Var copied from express consoles so this doesn't break. I love abusing inheritance ;)
	var/obj/item/supplypod_beacon/beacon

