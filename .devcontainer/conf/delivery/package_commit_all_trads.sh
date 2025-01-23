#!/usr/bin/node


const { exec, execSync } = require("child_process");


// Generate base (remove parenthesis after)
/*
const regex = /^([a-zA-Z -.]+)(.*)\(([a-zA-Z-_@]+)\)/gm;

const str = `English (en) LANGUE SOURCE
1855 total des chaînes
 mars 21 2023, 16:38
Arabic (ar)
0% révisées 65.34% traduites
 mars 14 2023, 15:21


Asturian (ast) IL N’Y A AUCUN TRADUCTEUR
0% révisées 0% traduites
 mars 14 2023, 15:21


Basque (eu)
0% révisées 68.79% traduites
 mars 14 2023, 15:21


Bosnian (Bosnia and Herzegovina) (bs_BA)
0% révisées 96.87% traduites
 mars 14 2023, 15:21


Bulgarian (Bulgaria) (bg_BG)
0% révisées 98.01% traduites
 mars 14 2023, 15:21


Catalan (ca)
0% révisées 94.82% traduites
 mars 14 2023, 15:21


Chinese (China) (zh_CN)
0% révisées 89.11% traduites
 mars 14 2023, 15:21


Chinese (Taiwan) (zh_TW)
0% révisées 88.41% traduites
 mars 14 2023, 15:21


Croatian (Croatia) (hr_HR)
0% révisées 90.78% traduites
 mars 14 2023, 15:21


Czech (cs)
0% révisées 95.63% traduites
 mars 14 2023, 15:21


Danish (Denmark) (da_DK)
0% révisées 100% traduites
 mars 14 2023, 15:21


Dutch (nl)
0% révisées 98.06% traduites
 mars 14 2023, 15:21


Finnish (fi)
0% révisées 85.82% traduites
 mars 14 2023, 15:21


French (fr)
0% révisées 100% traduites
 mars 14 2023, 15:21


German (de)
10.89% révisées 100% traduites
 mars 15 2023, 07:59


Hebrew (he)
0% révisées 87.12% traduites
 mars 14 2023, 15:21


Hungarian (hu)
0% révisées 98.71% traduites
 mars 14 2023, 15:21


Icelandic (is)
0% révisées 60.54% traduites
 mars 14 2023, 15:21


Indonesian (Indonesia) (id_ID)
0% révisées 93.32% traduites
 mars 14 2023, 15:21


Italian (it)
0% révisées 98.06% traduites
 mars 14 2023, 15:21


Japanese (ja)
0% révisées 90.94% traduites
 mars 14 2023, 15:21


Kazakh (kk)
0% révisées 96.82% traduites
 mars 14 2023, 15:21


Latvian (lv)
0% révisées 93.96% traduites
 mars 14 2023, 15:21


Lithuanian (lt)
0% révisées 81.24% traduites
 mars 14 2023, 15:21


Macedonian (Macedonia) (mk_MK)
0% révisées 93.05% traduites
 mars 14 2023, 15:21


Norwegian Bokmål (Norway) (nb_NO)
0% révisées 100% traduites
 mars 14 2023, 15:21


Norwegian Nynorsk (Norway) (nn_NO)
0% révisées 75.85% traduites
 mars 14 2023, 15:21


Polish (pl)
0% révisées 97.95% traduites
 mars 14 2023, 15:21


Portuguese (pt)
0% révisées 91.21% traduites
 mars 14 2023, 15:21


Portuguese (Brazil) (pt_BR)
0% révisées 97.74% traduites
 mars 14 2023, 15:21


Romanian (Romania) (ro_RO)
0% révisées 93.91% traduites
 mars 14 2023, 15:21


Russian (ru)
0% révisées 98.01% traduites
 mars 14 2023, 15:21


Serbian (sr)
97.63% révisées 98.38% traduites
 févr. 13 2023, 17:53


Serbian (Latin) (sr@latin)
0% révisées 95.2% traduites
 mars 14 2023, 15:21


Serbian (Latin) (Montenegro) (sr_ME@latin)
0% révisées 96.33% traduites
 mars 14 2023, 15:21


Slovak (sk)
0% révisées 95.2% traduites
 mars 14 2023, 15:21


Slovenian (Slovenia) (sl_SI)
0% révisées 97.41% traduites
 mars 14 2023, 15:21


Spanish (Argentina) (es_AR)
0% révisées 91.21% traduites
 mars 14 2023, 15:21


Spanish (Spain) (es_ES)
0% révisées 89.16% traduites
 mars 14 2023, 15:21


Swedish (sv)
0% révisées 92.94% traduites
 mars 14 2023, 15:21


Turkish (Turkey) (tr_TR)
0% révisées 98.01% traduites
 mars 14 2023, 15:21


Ukrainian (uk)
0% révisées 98.06% traduites
 mars 14 2023, 15:21


Welsh (cy)
0% révisées 87.33% traduites
 mars 14 2023, 15:21
`;
let m;

console.log("const base = {");
while ((m = regex.exec(str)) !== null) {
    // This is necessary to avoid infinite loops with zero-width matches
    if (m.index === regex.lastIndex) {
        regex.lastIndex++;
    }

    console.log("'" + m[1].replace(/ +$/, '') + "': '" + m[3].replace(/ +$/, '') + "',");
    
    // The result can be accessed through the `m`-variable.
    //m.forEach((match, groupIndex) => {
    //    console.log(`Found match, group ${groupIndex}: ${match}`);
    //});
}
console.log("};");
*/

const base = {
'English': 'en',
'Arabic': 'ar',
'Asturian': 'ast',
'Basque': 'eu',
'Bosnian': 'bs_BA',
'BrazilianPortuguese': 'pt_BR',
'Bulgarian': 'bg_BG',
'Catalan': 'ca',
'ChineseChina': 'zh_CN',
'ChineseTaiwan': 'zh_TW',
'Croatian': 'hr_HR',
'Czech': 'cs',
'Danish': 'da_DK',
'Dutch': 'nl',
'Finnish': 'fi',
'French': 'fr',
'German': 'de',
'Hebrew': 'he',
'Hungarian': 'hu',
'Icelandic': 'is',
'Indonesian': 'id_ID',
'Italian': 'it',
'Japanese': 'ja',
'Kazakh': 'kk',
'Latvian': 'lv',
'Lithuanian': 'lt',
'Macedonian': 'mk_MK',
'NorwegianBokmal': 'nb_NO',
'NorwegianNynorsk': 'nn_NO',
'Polish': 'pl',
'Portuguese': 'pt',
'Romanian': 'ro_RO',
'Russian': 'ru',
'Serbian': 'sr',
'SerbianLatin': 'sr@latin',
'Montenegrin': 'sr_ME@latin',
'Slovak': 'sk',
'Slovenian': 'sl_SI',
'SpanishArgentina': 'es_AR',
'SpanishSpain': 'es_ES',
'Swedish': 'sv',
'TurkishTurkey': 'tr_TR',
'Ukrainian': 'uk',
'Welsh': 'cy',
};


exec("git status", (error, stdout, stderr) => {
    if (error) {
        console.log(`error: ${error.message}`);
        return;
    }
    if (stderr) {
        console.log(`stderr: ${stderr}`);
        return;
    }


    const regex = /\/([a-zA-Z -.]+).lproj/gm;
    let m;

    const modifiedLanguages = [];
	while ((m = regex.exec(stdout)) !== null) {
	    // This is necessary to avoid infinite loops with zero-width matches
	    if (m.index === regex.lastIndex) {
	        regex.lastIndex++;
	    }
	    
	    if (modifiedLanguages.indexOf(m[1]) == -1) {
	    	modifiedLanguages.push(m[1]);
	    }
	}

	//console.log(modifiedLanguages);
	modifiedLanguages.forEach((modifiedLanguage) => {
		if (!base[modifiedLanguage]) {
			console.log(modifiedLanguage + " not found. Stopping.");
			process.exit(0);
		}
	});

	modifiedLanguages.forEach((modifiedLanguage) => {
		// Each language
		console.log("Doing " + modifiedLanguage);
		const lines = stdout.split("\n");
		lines.forEach((line) => {
			// Starting with "modified"
			if (line.indexOf("modified:") > 0 && line.indexOf("/" + modifiedLanguage) > 0) {
				const regexLine = /modified\:[\s+](.*)Localizable\.strings/gm;
				mLine = regexLine.exec(line);
				if (mLine[1]) {
					const file = mLine[1].replace(/^ +/, '') + "Localizable.strings";
					console.log("> " + file);
					execSync("git add " + file);
				} else {
					console.log("Error null : " + mLine[1])
				}
			}
		});

		execSync("git commit -m \"i18n(" + base[modifiedLanguage] + "): Update " + modifiedLanguage + " translations\"");
	});
});

