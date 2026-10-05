extends TestCase
## The controls card's key names (#35) come from the InputMap, so they can't drift from the bindings.


func test_key_names_follow_the_input_map() -> void:
	check_eq(ControlsCard.keys(&"switch"), "J / Z", "Switch")
	check_eq(ControlsCard.keys(&"tow"), "L / C", "Tow")
	check_eq(ControlsCard.keys(&"pause"), "Escape / P / Enter", "Pause")
	check(ControlsCard.keys(&"dash").contains("Space"), "Dash: got %s" % ControlsCard.keys(&"dash"))
