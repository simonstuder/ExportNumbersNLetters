# ExportNumbersNLetters
Musescore Plugin to export numbers or letters for beginners and mainly brass instruments. 

I created this plugin to distribute music sheets in form of letters or numbers for my beginner band members with brass instruments. Trumpet, Trombone, Euphonium and Sousaphone are implemented. (Contact me or open an issue if you want others that do not work yet)

Options include:

- Use flats or sharp letter descriptions only or choose automatically from the current key signature
- Set the output type (still working on pdf via libreoffice)
- Set the suffixes of output files for letters and numbers
- Let layout breaks create newlines in the output
- Set the spacing method and a spacing value

## Installation
[Download](https://github.com/simonstuder/ExportNumbersNLetters/archive/main.zip) the zip file and install according to the default MuseScore [Plugin Installation](https://musescore.org/en/handbook/3/plugins#installation) method

For output as docx the [pandoc](https://pandoc.org) converter is necessary as internally an html page is generated and then converted to docx.

## Output formats
Available formats are docx, html, txt, md and pdf in the future. Corresponding files will be generated.
When selecting docx, an html file is generated first and then converted to docx with the pandoc converter.

## Output styling
The generation of docx files uses the included reference.docx file as reference. To alter the look of the output modify the styles in this document. Heading 1 is the title of the score, Heading 2 is the style of song part headings and Heading 3 is the style of the instrument indication.

All other output is hardcoded so far.

## Translations
The languages this is available in are English and German. For others I would accept help with translation if wanted.

## Todo
- export to pdf via libreoffice if installed
- do not only use layout breaks at end of measures for newlines but other indicators, even individually per instrument
- fix separation of parts if the name of a new part is not at the beginning of a measure, even make it individually per instrument
- make spacing between parts more unified. Maybe check longest lines to adapt to that target or page width

