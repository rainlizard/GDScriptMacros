@tool
extends EditorPlugin


var script_editor : TextEdit
var cursor_line = -1

var macroStr := {}
var macroArgs := {}
var macroPath := "res://addons/GDScriptMacros/macros.txt"
var macroDate : int


func check_macro(line: int) -> void:
	print("checking macro: ", line)
	var writtenLine := script_editor.get_line(line)

	var keyword = writtenLine.strip_edges(true, true)
	var splitLine = Array(keyword.split(" ", false))
	# given keyword and given arguments
	keyword = splitLine.pop_front()
	var givenArgs = splitLine
	# only continue if the given keyword exists within macros.txt
	if macroStr.has(keyword):
		# the number of arguments given must match the number of arguments as written inside macros.txt
		if givenArgs.size() != macroArgs[keyword].size(): return
		# begin construction of a new line
		var constructLine = writtenLine
		var indent = get_indentation(writtenLine)
		constructLine = indent + macroStr[keyword]
		# Apply indentation to each line in the macro result
		constructLine = constructLine.replace('\n', '\n' + indent)
		# Arguments
		if macroArgs.has(keyword):
			for i in givenArgs.size():
				constructLine = constructLine.replace(macroArgs[keyword][i], givenArgs[i])
		# finalize
		script_editor.set_line(line, constructLine)


func get_indentation(string: String) -> String:
	var indentation := ""
	for i in string:
		if i == '\t' or i == ' ':
			indentation += i
		else:
			break
	return indentation


func _init_macro_file() -> void:
	var file := File.new()

	var date := file.get_modified_time(macroPath)
	if date == macroDate:  # prevent loading macro file twice by checking date.
		return
	macroDate = date

	file.open(macroPath, File.READ)
	var keyword : String

	while true:
		var line := file.get_line()
		if line.begins_with("[macro]"):
			# trim the previous entry's final "\n", just to remove an unncessary extra line.
			if keyword:
				macroStr[keyword] = macroStr[keyword].trim_suffix("\n")
			# new keyword
			keyword = line.trim_prefix("[macro]")
			# separate keyword from arguments
			var splitLine : Array = Array(keyword.split(" ", false))
			keyword = splitLine.pop_front()
			# put an array of arguments into macroArgs dictionary, or have it be a blank array if there are no arguments
			macroArgs[keyword] = []
			for i in splitLine:  # "splitLine" consists of only arguments since the front was popped
				macroArgs[keyword].append(i)
			# create keyword dictionary entry (set its value later)
			macroStr[keyword] = ""
		else:
			if !file.eof_reached():
				if keyword:
					macroStr[keyword] += line + "\n"
			else:
				if keyword:
					macroStr[keyword] += line
				break
	file.close()


func _ready():
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	_init_macro_file()


func _notification(what: int):
	if what == 1004: #1004 is FOCUS_IN, using the ENUM NAME doesnt work atm
		_init_macro_file()  # reinit macro if user modified file
		


func _on_text_changed():
	if is_instance_valid(script_editor):
		if cursor_line != script_editor.get_caret_line():
			check_macro(cursor_line)
			cursor_line = script_editor.get_caret_line()


func _on_gui_focus_changed(node: Node):
	if node is TextEdit:
		if is_instance_valid(script_editor):
			script_editor.text_changed.disconnect(_on_text_changed)
		script_editor = node
		script_editor.text_changed.connect(_on_text_changed)
