all:
	svgtiler -f at.coffee at.asc
	svgtiler -f --uneven at.coffee at.asc
	svgtiler -f context.coffee context.asc
	svgtiler -f escape.txt escape.csv
	svgtiler -f css-escape.css css-escape.txt css-escape.asc
	svgtiler -f glob.coffee
	svgtiler -f mapping.coffee mapping.ssv
	svgtiler -f mappings.coffee -O mappings mapping.ssv
	svgtiler -f set.coffee set.asc
	svgtiler -f \( share-provider.js share-user.js \) share-undefined.js
	svgtiler -f \( -s data=Success\! share-user.js \) share-undefined.js
