@tool
extends EditorPlugin

var script_editor : TextEdit
var cursor_line = -1

var macroStr := {}
var macroArgs := {}
var macroPath := "res://addons/GDScriptMacros/macros.txt"
var macroDate : int


func check_macro(line: int) -> void:
	var writtenLine := script_editor.get_line(line)

	var keyword = writtenLine.strip_edges(true, true)
	var splitLine = Array(keyword.split(" ", false))
	# Given keyword and given arguments
	keyword = splitLine.pop_front()
	var givenArgs = splitLine
	# Only continue if the given keyword exists within macros.txt
	if macroStr.has(keyword):
		# The number of arguments given must match the number of arguments as written inside macros.txt
		if givenArgs.size() != macroArgs[keyword].size(): return
		# Begin construction of a new line
		var constructLine = writtenLine
		var indent = get_indentation(writtenLine)
		constructLine = indent + macroStr[keyword]
		# Apply indentation to each line in the macro result
		constructLine = constructLine.replace('\n', '\n' + indent)
		# Arguments
		if macroArgs.has(keyword):
			for i in givenArgs.size():
				constructLine = constructLine.replace(macroArgs[keyword][i], givenArgs[i])
		# Finalize
		script_editor.set_line(line, constructLine)
		
		# Fixes a crash when macro contains a new line and you move the cursor to that new line when executing the macro
		if constructLine.ends_with("\n"):
			script_editor.set_caret_line(line+1)
		
		# Update instantly
		script_editor.visible = false
		script_editor.visible = true
		script_editor.grab_focus()


func get_indentation(string: String) -> String:
	var indentation := ""
	for i in string:
		if i == '\t' or i == ' ':
			indentation += i
		else:
			break
	return indentation


func _init_macro_file() -> void:
	var date := FileAccess.get_modified_time(macroPath)
	if date == macroDate:  # Prevent loading macro file twice by checking date
		return
	macroDate = date

	var file := FileAccess.open(macroPath, FileAccess.READ)
	var keyword : String

	while true:
		var line := file.get_line()
		if line.begins_with("[macro]"):
			# Trim the previous entry's final "\n", just to remove an unncessary extra line
			if keyword:
				macroStr[keyword] = macroStr[keyword].trim_suffix("\n")
			# New keyword
			keyword = line.trim_prefix("[macro]")
			# Separate keyword from arguments
			var splitLine : Array = Array(keyword.split(" ", false))
			keyword = splitLine.pop_front()
			# Put an array of arguments into macroArgs dictionary, or have it be a blank array if there are no arguments
			macroArgs[keyword] = []
			for i in splitLine:  # "splitLine" consists of only arguments since the front was popped
				macroArgs[keyword].append(i)
			# Create keyword dictionary entry (set its value later)
			macroStr[keyword] = ""
		else:
			if !file.eof_reached():
				if keyword:
					macroStr[keyword] += line + "\n"
			else:
				if keyword:
					macroStr[keyword] += line
				break
	file = null


func _ready():
	get_viewport().connect("gui_focus_changed",Callable(self,"_on_gui_focus_changed"))
	_init_macro_file()

func _notification(what: int):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		_init_macro_file()  # Reinit macro if user modified file


func _on_caret_changed():
	if is_instance_valid(script_editor):
		if cursor_line != script_editor.get_caret_line():
			check_macro(cursor_line)
			cursor_line = script_editor.get_caret_line()


func _on_gui_focus_changed(node: Node):
	if node is TextEdit:
		if is_instance_valid(script_editor):
			script_editor.disconnect("caret_changed",Callable(self,"_on_caret_changed"))
		script_editor = node
		script_editor.connect("caret_changed",Callable(self,"_on_caret_changed"))
