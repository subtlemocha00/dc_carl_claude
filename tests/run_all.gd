extends SceneTree
## Runs every tests/test_*.gd file in its own Godot process and prints a summary.
##
## Run from the project folder:
##     godot --headless --path . -s res://tests/run_all.gd
##
## Tests with "windowed" in their file name need a real window, so they are started
## without --headless (a game window opens briefly).
## A test fails if it exits with a non-zero code or prints any engine ERROR or WARNING. The only
## exception is an error the test provoked on purpose and checked: for each one it prints
## "EXPECTED ERROR: <text>" (game_test.gd, take_engine_messages()), which excuses exactly one
## "ERROR: <text>" line with that same text.
## Exits with code 0 when every test passes and 1 otherwise.


func _initialize() -> void:
	var godot := OS.get_executable_path()
	var project_folder := ProjectSettings.globalize_path("res://")
	var test_files := Array(DirAccess.get_files_at("res://tests")).filter(
			func(file: String) -> bool: return file.begins_with("test_") and file.ends_with(".gd"))
	test_files.sort()

	var failed := 0
	for file: String in test_files:
		var arguments := PackedStringArray(["--path", project_folder, "-s", "res://tests/" + file])
		if not file.contains("windowed"):
			arguments.insert(0, "--headless")
		var output := []
		var exit_code := OS.execute(godot, arguments, output, true)
		var log_text := "\n".join(output)
		var lines := Array(log_text.split("\n"))
		var expected_errors := {}
		for line: String in lines:
			if line.begins_with("EXPECTED ERROR: "):
				var text := line.trim_prefix("EXPECTED ERROR: ")
				expected_errors[text] = expected_errors.get(text, 0) + 1
		var engine_problems := lines.filter(func(line: String) -> bool:
			if line.begins_with("ERROR: ") and expected_errors.get(line.trim_prefix("ERROR: "), 0) > 0:
				expected_errors[line.trim_prefix("ERROR: ")] -= 1
				return false
			return line.begins_with("ERROR") or line.begins_with("WARNING") or line.begins_with("SCRIPT ERROR"))
		var passed := exit_code == 0 and engine_problems.is_empty()
		print("%s  %s" % ["PASS" if passed else "FAIL", file])
		if not passed:
			failed += 1
			print("      exit code %d, %d engine error/warning line(s):" % [exit_code, engine_problems.size()])
			print("      " + log_text.strip_edges().replace("\n", "\n      "))

	print("%d of %d test files passed." % [test_files.size() - failed, test_files.size()])
	quit(0 if failed == 0 else 1)
