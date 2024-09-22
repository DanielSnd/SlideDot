# Question Types:
# WR: Written Response
# SA: Short Answer
# M: Matching
# MC: Multiple Choice
# TF: True/False
# MS: Multi-Select
# O: Ordering

# Format:
# [Question Type] Question Title {{Hint}}
# Question Text
# Points: X
# Difficulty: Y
# [Type-specific content]
# ---

# WR (Written Response):
# Initial Text: [text]
# Answer Key: [text]

# SA (Short Answer):
# Input Box: [num_lines],[width]
# *[points] Correct Answer [regexp]
# [points] Partially Correct Answer

# M (Matching):
# Scoring: [EquallyWeighted/Exact]
# Choice: [text] => Match: [text]

# MC (Multiple Choice) and MS (Multi-Select):
# Scoring: [AllOrNothing/RightAnswers] (only for MS)
# *[points] Correct Answer || [feedback]
# [points] Incorrect Answer || [feedback]

# TF (True/False):
# *True || [feedback]
# False || [feedback]

# O (Ordering):
# Scoring: [RightMinusWrong/Exact]
# 1. [text] || [feedback]

# General:
# Image: [path]
# Feedback: [text]

extends Node

var output :PackedStringArray= []
var default_points = 1
var default_difficulty = 1

func parse_questions(input_text):
	output.clear()
	output.append(',,,,')

	var questions = input_text.split("---")
	for i in range(questions.size()):
		parse_question(questions[i].strip_edges(), i + 1)

	return "\n".join(output)

func parse_question(question:String, question_number):
	if question.strip_edges().is_empty():
		return
	var lines = question.split("\n")
	if lines.size() < 2:
		print("Error in question %d: Insufficient lines" % question_number)
		return

	var type = lines[0].split(" ")[0]
	var title_and_hint = lines[0].substr(lines[0].find(" ") + 1)
	var hint = ""
	var question_text = ""

	if "{{" in title_and_hint:
		var parts = title_and_hint.split("{{")
		question_text = parts[0].strip_edges()
		hint = parts[1].split("}}")[0].strip_edges()
	else:
		question_text = title_and_hint

	output.append("NewQuestion," + type + ",,,")
	output.append('QuestionText,"' + question_text + '",,,')

	var points_set = false
	var difficulty_set = false
	if type == "MC" or type == "MS":
		if not question.contains("*"):
			print("Error in question %d: No right answer selected")

	var scoring_set = false
	var choices = []
	var matches = []
	var feedbacks = []

	for line in lines.slice(1, lines.size()):
		if line.begins_with("Points:"):
			output.append("Points," + line.split(":")[1].strip_edges() + ",,,")
			points_set = true
		elif line.begins_with("Difficulty:"):
			output.append("Difficulty," + line.split(":")[1].strip_edges() + ",,,")
			difficulty_set = true
		elif line.begins_with("Image:"):
			output.append('Image,"' + line.split(":")[1].strip_edges() + '",,,')
		elif line.begins_with("Scoring:"):
			output.append("Scoring," + line.split(":")[1].strip_edges() + ",,,")
			scoring_set = true
		elif line.begins_with("Feedback:"):
			feedbacks.append(line.split(":")[1].strip_edges())
		elif type == "WR":
			parse_wr(line, question_number)
		elif type == "SA":
			parse_sa(line, question_number)
		elif type == "M":
			feedbacks += parse_matching(line, choices, matches, question_number)
		elif type == "MC" or type == "MS":
			parse_mc_ms(line, type, question_number)
		elif type == "TF":
			parse_tf(line, question_number)
		elif type == "O":
			parse_ordering(line, question_number)
		elif line.strip_edges() != "":
			# Instead of printing an error, we'll assume this is part of the question text
			output.append('QuestionText,"' + line.strip_edges() + '",,,')

	if not points_set:
		output.append("Points," + str(default_points) + ",,,")
	if not difficulty_set:
		output.append("Difficulty," + str(default_difficulty) + ",,,")

	if hint:
		output.append('Hint,"' + hint + '",,,')

	if type == "M":
		for i in range(choices.size()):
			output.append('Choice,' + str(i+1) + ',"' + choices[i] + '",,')
		for i in range(matches.size()):
			output.append('Match,' + str(i+1) + ',"' + matches[i] + '",,')
		if feedbacks:
			output.append('Feedback,"' + " | ".join(feedbacks) + '",,,')

	output.append(",,,,")

func parse_wr(line, question_number):
	if line.begins_with("Initial:"):
		output.append('InitialText,"' + line.split(":")[1].strip_edges() + '",,,')
	elif line.begins_with("Answer:"):
		output.append('AnswerKey,"' + line.split(":")[1].strip_edges() + '",,,')
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized WR format: %s" % [question_number, line])

func parse_sa(line, question_number):
	if line.begins_with("Input:"):
		var params = line.split(":")[1].split(",")
		if params.size() != 2:
			print("Error in question %d: Invalid Input format" % question_number)
		else:
			output.append("InputBox," + params[0].strip_edges() + "," + params[1].strip_edges() + ",,")
	elif line.begins_with("*") or not line.begins_with(" "):
		var parts = line.split(" ", 1)
		var points = "100" if line.begins_with("*") else "0"
		var answer = parts[1] if line.begins_with("*") else line
		var regexp = "regexp" if "regexp" in answer else ""
		output.append('Answer,' + points + ',"' + answer.strip_edges() + '",' + regexp + ',')
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized SA format: %s" % [question_number, line])

func parse_matching(line, choices, matches, question_number):
	var feedbacks = []
	if "=>" in line:
		var parts = line.split("=>")
		if parts.size() != 2:
			print("Error in question %d: Invalid Matching format" % question_number)
		else:
			var choice = parts[0].split(":")[1].strip_edges() if ":" in parts[0] else parts[0].strip_edges()
			var match_parts = parts[1].split("||", true, 1)
			var match_text = match_parts[0].strip_edges()
			choices.append(choice)
			matches.append(match_text)
			if match_parts.size() > 1:
				feedbacks.append(choice + " => " + match_text + ": " + match_parts[1].strip_edges())
	elif line.begins_with("Feedback:"):
		feedbacks.append(line.split(":")[1].strip_edges())
	elif line.begins_with("Scoring:"):
		pass
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized Matching format: %s" % [question_number, line])

	return feedbacks

func parse_mc_ms(line, type, question_number):
	if line.begins_with("*") or line[0].is_valid_int() or line[0] != " ":
		var parts = line.split("||", true, 1)
		var answer = parts[0].strip_edges()
		var feedback = parts[1].strip_edges() if parts.size() > 1 else ""
		var points = "100" if answer.begins_with("*") else "0"
		answer = answer.lstrip("*")
		if answer[0].is_valid_int():
			var space_index = answer.find(" ")
			points = answer.substr(0, space_index)
			answer = answer.substr(space_index + 1)
		output.append('Option,' + points + ',"' + answer + '",,"' + feedback + '"')
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized %s format: %s" % [question_number, type, line])

func parse_tf(line, question_number):
	if line.begins_with("*True") or line.begins_with("*False") or line.begins_with("True") or line.begins_with("False"):
		var parts = line.split("||", true, 1)
		var answer = parts[0].lstrip("*").strip_edges()
		var feedback = parts[1].strip_edges() if parts.size() > 1 else ""
		var points = "100" if line.begins_with("*") else "0"
		output.append(answer.to_upper() + ',' + points + ',"' + feedback + '",,')
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized TF format: %s" % [question_number, line])

func parse_ordering(line, question_number):
	if not line.begins_with(" "):
		var parts = line.split("||")
		var item = parts[0].strip_edges()
		var feedback = parts[1].strip_edges() if parts.size() > 1 else ""
		output.append('Item,"' + item + '",,"' + feedback + '",')
	elif line.strip_edges() != "":
		print("Error in question %d: Unrecognized Ordering format: %s" % [question_number, line])

# Usage example:
# var parser = preload("res://code/question_parser.gd").new()
# var markdown_text = """
# MC Multiple Choice Question {{Hint text}}
# What is the capital of France?
# *100 Paris || Correct! Paris is the capital of France.
# 0 London || London is the capital of the United Kingdom, not France.
# 0 Berlin || Berlin is the capital of Germany, not France.
# 0 Madrid || Madrid is the capital of Spain, not France.
# Feedback: The capital of France is Paris.
# ---
# """
# var csv_output = parser.parse_questions(markdown_text)
# print(csv_output)
