extends Control


func _ready():

	var arraynumbs:Array[int] = []
	var digits_sum:int = 0
	var digits_string:String = ""
	for i in 500:
		var randm:int = randi_range(1,438)
		digits_string += str(randm)
	print(digits_string)
	for i in digits_string:
		digits_sum += i.to_int()
	print(digits_sum)
	#return
	var sum_fiz:int = 0
	var fizz_buzz_array:Array = []
	for i in range(1, 101):
		if i % 15 == 0:
			fizz_buzz_array.push_back("FizzBuzz")
		elif i % 3 == 0:
			fizz_buzz_array.push_back("Fizz")
			sum_fiz += i
		elif i % 5 == 0:
			fizz_buzz_array.push_back("Buzz")
		else:
			fizz_buzz_array.push_back(i)

	print(sum_fiz)
	return

	#var vowelcount:String = "Lorem ipsum odor amet, consectetuer adipiscing elit. Potenti sodales duis turpis curabitur dapibus etiam netus dignissim. Maecenas cubilia eget sit diam sollicitudin curabitur. Vulputate augue curabitur neque luctus dolor ornare eu felis litora. Litora per porta consectetur euismod senectus. Sollicitudin dolor aliquet urna massa diam facilisi ante fames.
#
#Placerat et facilisi in aenean maecenas. Lacinia etiam mus facilisis volutpat nisl fusce odio. Lacus a augue phasellus et placerat inceptos. Sociosqu primis nulla metus magnis suscipit imperdiet laoreet. Gravida dis ultrices ornare sociosqu ullamcorper dictum vivamus. Ridiculus sed semper at luctus, venenatis hendrerit malesuada nibh parturient. Mi sit ultrices penatibus placerat quis tincidunt semper fusce. Morbi rutrum aenean etiam; sodales libero netus semper magnis gravida!
#
#Vivamus ipsum semper himenaeos torquent eu euismod nec. Scelerisque rhoncus accumsan ridiculus ultrices lacinia ullamcorper hac. Litora convallis ad porta integer laoreet. Ahabitasse pretium enim nibh vulputate dui maximus. Fermentum lorem dis lacinia ligula phasellus metus non iaculis. Quisque tristique dignissim tortor mattis class pellentesque mus posuere? Eleifend nisi ultrices nam urna ultricies scelerisque. Ridiculus quisque rhoncus inceptos facilisi torquent sollicitudin. Nostra quam ad suscipit tempus nibh lobortis nisl litora.
#
#Aptent ac commodo sed quisque maecenas pharetra dignissim. Hac vel lobortis purus dolor phasellus bibendum dolor. Mi maximus nibh pharetra auctor ante quam gravida adipiscing consequat? Potenti conubia tempor consequat vitae dis elementum torquent. Fermentum aptent maximus vehicula; sodales bibendum erat commodo. Ultricies dolor viverra vestibulum cubilia adipiscing curae natoque magnis arcu. Massa convallis erat aliquam potenti hendrerit vestibulum. Neque aenean quam curabitur lacinia ac mauris lectus. Adipiscing facilisis ultrices donec dolor fusce commodo ante. Ultrices quis a; finibus aliquet iaculis etiam.".to_upper()
	#var vowelsy:Array = ["A","E","I","O","U"]
	#var vowelsum = 0
#
	#for i in vowelcount:
		#if vowelsy.has(i.to_upper()):
			#vowelsum += 1
#
	#print (vowelsum)
	#return
	var message = "hopefully you used code to decode this since it's long enough that it would be quite annoying to do manually word by word and letter by letter wouldn't it? Anyways if you are wondering about it to find the answer to this puzzle count the vowels that are in this hidden message. If you haven't properly done the whole message I guess it would be kind of hard after decoding it to actually count all the vowels in it huh"

	var splitm = message.split(" ", false)
	for i in splitm.size():
		var array_word:Array = []
		for l in splitm[i]:
			array_word.push_back(l)
		array_word.reverse()
		for l in array_word.size():
			splitm[i][l] = array_word[l]

	var words = "cras fermentum orci massa sed maximus elit laoreet vitae nullam id eleifend lorem Integer nulla nunc pulvinar in tristique quis, viverra sit amet magna fusce a turpis velit praesent volutpat libero id dignissim facilisis pellentesque aliquet diam id tellus cursus malesuada sed congue congue metus non placerat felis mattis fringilla cras fermentum orci massa sed maximus elit laoreet vitae nullam id eleifend lorem Integer nulla nunc pulvinar in tristique quis, viverra sit amet magna fusce a turpis velit praesent volutpat libero id dignissim facilisis pellentesque aliquet diam id tellus cursus malesuada sed congue congue metus non placerat felis mattis fringilla"
	var weird_words_split = words.split(" ",false)
	for i in weird_words_split.size():
		var array_word:Array = []
		for l in weird_words_split[i]:
			array_word.push_back(l)
		array_word.reverse()
		for l in array_word.size():
			weird_words_split[i][l] = array_word[l]

	var final_message:Array = []
	for i in splitm.size() * 2:
		if i % 2 != 0:
			final_message.push_back(splitm[0])
			splitm.remove_at(0)
		else:
			final_message.push_back(weird_words_split[0])
			weird_words_split.remove_at(0)
	print(" ".join(final_message))
	var vowels:Array = ["a","e","i","o","u"]
	var vowel_count:int = 0
	for i in message:
		if vowels.has(i):
			vowel_count+=1
	print (vowel_count)
