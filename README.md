# arb_translator
  
  <a href="https://flutter.io">  
    <img src="https://img.shields.io/badge/Platform-Flutter-yellow.svg"  
      alt="Platform" />  
  </a> 
   <a href="https://pub.dartlang.org/packages/arb_translator">  
    <img src="https://img.shields.io/pub/v/arb_translator.svg"  
      alt="Pub Package" />  
  </a>
   <a href="https://www.paypal.me/kawal7415">  
    <img src="https://img.shields.io/badge/Donate-PayPal-green.svg"  
      alt="Donate" />  
  </a>
   <a href="https://github.com/justkawal/arb_translator/issues">  
    <img src="https://img.shields.io/github/issues/justkawal/arb_translator"  
      alt="Issue" />  
  </a> 
   <a href="https://github.com/justkawal/arb_translator/network">  
    <img src="https://img.shields.io/github/forks/justkawal/arb_translator"  
      alt="Forks" />  
  </a> 
   <a href="https://github.com/justkawal/arb_translator/stargazers">  
    <img src="https://img.shields.io/github/stars/justkawal/arb_translator"  
      alt="Stars" />  
  </a>
  <br>
  <br>
 
## Uses Google Cloud Translations for translating files.
[arb_translator](https://www.pub.dev/packages/arb_translator) is a dart command-line tool for translating arb file into multiple languages.
 
#### This library is MIT licensed So, it's free to use anytime, anywhere without any consent, because we believe in Open Source work.

# Lets Get Started

### Add to the command line with

```yaml
  flutter packages pub global activate arb_translator
```

### Find Out available options

```yaml
  flutter packages pub run arb_translator:translate --help
```

### Options
options | description
------------ | -------------
 source_arb | (@required if source_dir not provided) path to the source arb file which has to be translated to other languages
 source_dir | (@required if source_arb not provided) path to a directory containing ARB files to be translated recursively. Each file will be translated to all specified languages and saved in language-specific subdirectories.
 api_key | (@required) path to the file of api key which contains api key of google cloud console
 output_directory | (optional) directory where the translated files should be written. When using --source_arb, defaults to the directory of the source file. When using --source_dir, defaults to the parent directory of the source directory.
 language_codes | (optional) comma separated language codes in which translation has to be done  , by-default it is set to en,zh Eg. is ```--language_codes ml,kn,pa,en```
 output_file_name | (optional) output _file_name is the initial name to be concatenated with the language codes. Eg. ```--output_file_name wow``` then this will save the translated files as ```wow_{language_code}.arb```, Suppose the langauge code is ml,hi then the files created will be wow_ml.arb and wow_zh.arb
 append_lang_code | (optional) whether to append language code to output filenames. Defaults to true. Set to false to keep original filenames.

### Translating a Single File

```yaml
  pub run arb_translator:translate --source_arb path/to/source_en.arb --api_key path/to/api_key_file --language_codes hi,en,zh
```

### Translating a Directory Recursively

```yaml
  pub run arb_translator:translate --source_dir path/to/arb_files --api_key path/to/api_key_file --language_codes hi,en,zh
```

This will:
1. Find all .arb files in the source directory and its subdirectories
2. For each file found, create language-specific subdirectories (e.g., hi/, en/, zh/)
3. Translate each file into all specified languages
4. Save the translated files in their respective language directories

For example, if you have:
```
path/to/arb_files/
  ├── app_en.arb
  └── subdir/
      └── messages_en.arb
```

And run with `--language_codes hi,es`, it will create:
```
path/to/arb_files/
  ├── hi/
  │   ├── app_en_hi.arb
  │   └── subdir/
  │       └── messages_en_hi.arb
  └── es/
      ├── app_en_es.arb
      └── subdir/
          └── messages_en_es.arb
```

If you run with `--language_codes hi,es --no-append_lang_code`, it will create:
```
path/to/arb_files/
  ├── hi/
  │   ├── app_en.arb
  │   └── subdir/
  │       └── messages_en.arb
  └── es/
      ├── app_en.arb
      └── subdir/
          └── messages_en.arb
```

### Changing location of translated file 
* use ```--output_directory``` with directory argument to change the saving location for the translated output file

```yaml
flutter packages pub run arb_translator:translate --source_arb path/to/source_en.arb --api_key path/to/api_key_file --language_codes hi,en,zh --output_directory /path/to/my/custom/output_directory/
```

### Custom Translations
If a translation by Google is incorrect or less suitable, you can override it by adding an 'x-translations' attribute and then specify your own translation for any specified language code. For instance, overriding the Swedish translation of the word "Continue" to "Fortsätt" would be done like this:

```json
"continue_": "Continue",
"@continue_": {
  "description": "custom translations",
  "x-translations": {
    "sv": "Fortsätt"
  }
}
```

### Don't like the name ```arb_translator_..blah..blah..blah.arb``` ??
* use ```--output_file_name``` with the single file name so that the output file name will be changed.
* from the below code the output file will be of the name justkawal_{language code}.arb
* Remember that we will automatically concate the language code of the respective files

```yaml
flutter packages pub run arb_translator:translate --source_arb path/to/source_en.arb --api_key path/to/api_key_file --language_codes hi,en,zh --output_directory /path/to/my/custom/output_directory/ --output_file_name justkawal_
```

### How to save api_key
* Create a text file and then put the api key got from google cloud console in that file.
* Now just simply call the file's path as the argument for --api_key

### Having trouble using api key for translation ?
* Enable Cloud Translation API inside APIS and Services section in google cloud console.
* Some quota of google Cloud translation APIS are free for translating upto a limit
* [Check Pricing and quota here](https://cloud.google.com/translate/pricing)
