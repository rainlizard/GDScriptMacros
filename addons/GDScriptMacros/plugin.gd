tool
extends EditorPlugin
var editorInterface = get_editor_interface()
var scriptEditor = editorInterface.get_script_editor()
var txtEd = null
var macroStr = {}
var macroArgs = {}
var macroFile = File.new()
var cursorLineNumber = -1

func _ready():
	get_viewport().connect("gui_focus_changed", self, "gui_focus_changed")
	
	macroFile.open("res://addons/GDScriptMacros/macros.txt", File.READ)
	var keyword = null
	while true:
		var line = macroFile.get_line()
		
		if line.begins_with("[macro]") == true:
			
			# Trim the previous entry's final "\n", just to remove an unncessary extra line.
			if keyword != null:
				macroStr[keyword] = macroStr[keyword].trim_suffix("\n")
			
			# New keyword
			keyword = line.trim_prefix("[macro]")
			# Separate keyword from arguments
			var splitLine = Array(keyword.split(" ",false))
			keyword = splitLine.pop_front()
			# Put an array of arguments into macroArgs dictionary, or have it be a blank array if there are no arguments
			macroArgs[keyword] = []
			for i in splitLine: # "splitLine" consists of only arguments since the front was popped
				macroArgs[keyword].append(i)
			
			# Create keyword dictionary entry (set its value later)
			macroStr[keyword] = ""
		else:
			if macroFile.eof_reached() == false:
				if keyword != null:
					macroStr[keyword] += line + "\n"
			else:
				if keyword != null:
					macroStr[keyword] += line
				break
	macroFile.close()

func gui_focus_changed(focusedControl):
	if focusedControl is TextEdit:
		if is_instance_valid(txtEd) == true:
			# Disconnect previous text editor
			txtEd.disconnect("cursor_changed",self,"cursor_changed")
		txtEd = focusedControl
		txtEd.connect("cursor_changed",self,"cursor_changed")

func cursor_changed():
	if is_instance_valid(txtEd) == true:
		if cursorLineNumber != txtEd.cursor_get_line():
			checkMacro(cursorLineNumber)
			cursorLineNumber = txtEd.cursor_get_line()

func checkMacro(lineNum):
	var writtenLine = txtEd.get_line(lineNum)

	var keyword = writtenLine.strip_edges(true,true)
	var splitLine = Array(keyword.split(" ",false))
	
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
		constructLine = constructLine.replace('\n', '\n'+indent)
		
		# Arguments
		if macroArgs.has(keyword):
			for i in givenArgs.size():
				constructLine = constructLine.replace(macroArgs[keyword][i], givenArgs[i])
		
		# Finalize
		txtEd.set_line(lineNum, constructLine)

func get_indentation(string):
	var indentation = ""
	for i in string:
		if i == '\t' or i == ' ':
			indentation += i
		else:
			break
	return indentation