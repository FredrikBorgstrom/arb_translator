library translate;

import 'dart:convert';
import 'dart:io';

import 'package:arb_translator/src/models/arb_document.dart';
import 'package:arb_translator/src/models/arb_resource.dart';
import 'package:arb_translator/src/utils.dart';
import 'package:args/args.dart';
import 'package:console/console.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

final encoder = JsonEncoder.withIndent('  ');
final decoder = JsonDecoder();

const _sourceArb = 'source_arb';
const _sourceDir = 'source_dir';
const _apiKey = 'api_key';
const _help = 'help';
const _outputDirectory = 'output_directory';
const _languageCodes = 'language_codes';
const _outputFileName = 'output_file_name';
const _appendLangCode = 'append_lang_code';
const _copySourceToOutput = 'copy_source_to_output';

class Action {
  final ArbResource Function(String translation, String currentText)
      updateFunction;

  final String text;

  final String resourceId;

  const Action({
    required this.updateFunction,
    required this.resourceId,
    required this.text,
  });
}

void main(List<String> args) async {
  final yaml = loadYaml(await File('./pubspec.yaml').readAsString()) as YamlMap;
  final name = yaml['name'] as String;
  final version = yaml['version'] as String;
  Console.init();

  final result = parseArguments(args);

  final sourceDir = result[_sourceDir] as String?;
  final sourceArb = result[_sourceArb] as String?;
  final apiKeyFile = createFileRef(result[_apiKey] as String);
  String outputFileName = result[_outputFileName] as String;
  if (outputFileName == 'arb_translator_') {
    outputFileName = '';
  }
  final languageCodes =
      (result[_languageCodes] as List<String>).map((e) => e.trim()).toList();
  var outputDirectory = result[_outputDirectory] as String?;
  final appendLangCode = result[_appendLangCode] as bool? ?? true;
  final copySourceToOutput = result[_copySourceToOutput] as bool? ?? false;

  final apiKey = apiKeyFile.readAsStringSync();

  if (languageCodes.toSet().length != languageCodes.length) {
    _setBrightRed();
    stderr.write('Please remove language code duplicates');
    exit(2);
  }
  print('${'-' * 15}  $name $version  ${'-' * 15}');

  if (sourceDir != null) {
    await processDirectory(sourceDir, languageCodes, apiKey, outputDirectory,
        outputFileName, appendLangCode, copySourceToOutput);
  } else if (sourceArb != null) {
    await processSingleFile(sourceArb, languageCodes, apiKey, outputDirectory,
        outputFileName, appendLangCode);
  } else {
    _setBrightRed();
    stderr.write('Either --source_arb or --source_dir must be provided.');
    exit(2);
  }

  _setBrightGreen();
  print('✓ Translations created');
  Console.resetTextColor();
}

Future<void> processDirectory(
  String sourcePath,
  List<String> languageCodes,
  String apiKey,
  String? outputPath,
  String outputFileName,
  bool appendLangCode,
  bool copySourceToOutput,
) async {
  Directory sourceDir = Directory(sourcePath);
  if (!sourceDir.existsSync()) {
    _setBrightRed();
    stderr.write('Source directory $sourcePath does not exist');
    exit(2);
  }

  // Set default output directory to parent of source directory if not specified
  final effectiveOutputPath =
      outputPath ?? path.dirname(path.absolute(sourcePath));

  // If copy_source_to_output is true, copy the source directory to the output directory
  if (copySourceToOutput) {
    final sourceDirName = path.basename(path.absolute(sourcePath));
    Directory copiedSourceDir =
        Directory(path.join(effectiveOutputPath, sourceDirName));

    print('Copying source directory to output directory...');
    await _copyDirectory(sourceDir, copiedSourceDir);
    print('Source directory copied to: $copiedSourceDir');

    // Update sourceDir to point to the copied directory
    sourceDir = copiedSourceDir;
  }

  // Find all ARB files recursively
  final arbFiles = await findArbFiles(sourceDir);
  if (arbFiles.isEmpty) {
    _setBrightRed();
    stderr.write('No ARB files found in $sourcePath');
    exit(2);
  }

  print('Found ${arbFiles.length} ARB files to translate');
  print('Output directory: $effectiveOutputPath');

  for (final arbFile in arbFiles) {
    // final relativePath = path.relative(arbFile.path, from: sourcePath);
    final fileName = path.basename(arbFile.path);
    final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
    final fileExt = path.extension(fileName);

    for (final languageCode in languageCodes) {
      final langOutputDir = path.join(effectiveOutputPath, languageCode);
      final langOutputFileName = outputFileName.isEmpty
          ? appendLangCode
              ? '${fileNameWithoutExt}_$languageCode$fileExt'
              : fileName
          : appendLangCode
              ? '${outputFileName}_$languageCode$fileExt'
              : outputFileName;

      await processSingleFile(
        arbFile.path,
        [languageCode],
        apiKey,
        langOutputDir,
        langOutputFileName,
        appendLangCode,
      );
    }
  }
}

// Helper function to copy a directory recursively
Future<void> _copyDirectory(Directory source, Directory destination) async {
  // Create the destination directory if it doesn't exist
  if (!await destination.exists()) {
    await destination.create(recursive: true);
  }

  // Copy all files and subdirectories
  await for (final entity in source.list(recursive: false)) {
    final destinationPath =
        path.join(destination.path, path.basename(entity.path));

    if (entity is File) {
      await File(entity.path).copy(destinationPath);
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(destinationPath));
    }
  }
}

Future<List<File>> findArbFiles(Directory dir) async {
  final List<File> arbFiles = [];

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.arb')) {
      arbFiles.add(entity);
    }
  }

  return arbFiles;
}

Future<void> processSingleFile(
  String sourceArb,
  List<String> languageCodes,
  String apiKey,
  String? outputDirectory,
  String outputFileName,
  bool appendLangCode,
) async {
  final arbFile = createFileRef(sourceArb);
  final src = arbFile.readAsStringSync();
  final arbDocument = ArbDocument.decode(src);

  outputDirectory ??=
      arbFile.path.substring(0, arbFile.path.lastIndexOf('/') + 1);

  final actionLists = createActionLists(arbDocument);

  for (final languageCode in languageCodes) {
    print('• Processing for $languageCode');

    await createArbFile(
      languageCode: languageCode,
      arbDocument: arbDocument,
      actionLists: actionLists,
      outputDirectory: outputDirectory,
      outputFileName: outputFileName,
      apiKey: apiKey,
    );
  }
}

List<List<Action>> createActionLists(ArbDocument arbDocument) {
  const maxWords = 128;
  final actionLists = <List<Action>>[];
  final actionList = <Action>[];

  for (final resource in arbDocument.resources.values) {
    final tokens = resource.tokens;

    for (final token in tokens) {
      final text = token.value as String;
      final htmlSafe = text.contains('{') ? toHtml(text) : text;

      actionList.add(
        Action(
          text: htmlSafe,
          resourceId: resource.id,
          updateFunction: (String translation, String currentText) {
            return resource.copyWith(
              text: currentText.replaceRange(
                token.start,
                token.stop,
                translation,
              ),
            );
          },
        ),
      );

      if (actionList.length >= maxWords) {
        actionLists.add([...actionList]);
        actionList.clear();
      }
    }
  }

  if (actionList.isNotEmpty) {
    actionLists.add([...actionList]);
    actionList.clear();
  }
  return actionLists;
}

Future<void> createArbFile({
  required String languageCode,
  required ArbDocument arbDocument,
  required List<List<Action>> actionLists,
  required String outputDirectory,
  required String outputFileName,
  required String apiKey,
}) async {
  final unescape = HtmlUnescape();
  var newArbDocument = arbDocument.copyWith(locale: languageCode);

  final futuresList = actionLists.map((list) {
    return _translateNow(
      translateList: list.map((action) => action.text).toList(),
      parameters: <String, dynamic>{'target': languageCode, 'key': apiKey},
    );
  }).toList();

  var translateResults = await Future.wait(futuresList);

  translateResults = insertManualTranslations(
      translateResults, actionLists, languageCode, arbDocument);

  // This is reversed so that end operations replace contents in string
  // before the beginning ones.
  for (var i = translateResults.length - 1; i >= 0; i--) {
    final translateList = translateResults[i];
    final actionList = actionLists[i];

    for (var j = translateList.length - 1; j >= 0; j--) {
      final action = actionList[j];
      final translation = translateList[j];
      final sanitizedTranslation = unescape.convert(
        translation.contains('<') ? removeHtml(translation) : translation,
      );

      newArbDocument = newArbDocument.copyWith(
        resources: newArbDocument.resources
          ..update(
            action.resourceId,
            (resource) {
              final arbResource = action.updateFunction(
                sanitizedTranslation,
                resource.text,
              );

              return arbResource;
            },
          ),
      );
    }
  }

  final file = await File(
    path.join(outputDirectory, outputFileName),
  ).create(recursive: true);

  await file.writeAsString(newArbDocument.encode());
}

List<List<String>> insertManualTranslations(
    List<List<String>> translationsLists,
    List<List<Action>> actionLists,
    String languageCode,
    ArbDocument arbDocument) {
  List<List<String>> updatedTranslationsLists = [];

  for (var i = 0; i < translationsLists.length; i++) {
    final updatedTranslations = <String>[];
    updatedTranslationsLists.add(updatedTranslations);
    final translations = translationsLists[i];

    for (var j = 0; j < translations.length; j++) {
      final translation = translations[j];
      final resourceId = actionLists[i][j].resourceId;
      final arbResource = arbDocument.resources[resourceId];
      final xTranslations = arbResource?.attributes?.xTranslations;
      if (xTranslations != null && xTranslations[languageCode] != null) {
        updatedTranslations.add(xTranslations[languageCode] as String);
      } else {
        updatedTranslations.add(translation);
      }
    }
  }
  return updatedTranslationsLists;
}

/* return translationsLists.map((list) {
    outerIndex++;
    int innerIdx = -1;
    return list.map((e) {
      innerIdx++;
      return e;
    }).toList();
  }).toList(); */

Future<List<String>> _translateNow({
  required List<String> translateList,
  required Map<String, dynamic> parameters,
}) async {
  final translated = <String>[];

  parameters['q'] = translateList;

  final url =
      Uri.parse('https://translation.googleapis.com/language/translate/v2')
          .resolveUri(Uri(queryParameters: parameters));

  final data = await http.get(url);

  if (data.statusCode != 200) {
    throw http.ClientException('Error ${data.statusCode}: ${data.body}', url);
  } else {
    // TO DO: We should use `googleapis` to deserialize this. We might also use translate v3.
    final jsonData = jsonDecode(data.body) as Map<String, dynamic>;

    final translations = List<Map<String, dynamic>>.from(
      jsonData['data']['translations'] as Iterable,
    );

    if (translations.isNotEmpty) {
      for (final singleTranslation in translations) {
        translated.add(singleTranslation['translatedText'] as String);
      }
    }
  }

  return translated;
}

void _setBrightGreen() {
  Console.setTextColor(2, bright: true);
}

void _setBrightRed() {
  Console.setTextColor(1, bright: true);
}

ArgParser _initiateParse() {
  final parser = ArgParser();

  parser
    ..addFlag('help', hide: true, abbr: 'h')
    ..addOption(
      _sourceArb,
      help: 'source_arb file acts as main file to be translated to other '
          '[language_codes] provided.',
    )
    ..addOption(
      _sourceDir,
      help:
          'source directory containing ARB files to be translated recursively',
    )
    ..addOption(
      _outputDirectory,
      help: 'directory from where source_arb file was read',
    )
    ..addMultiOption(_languageCodes, defaultsTo: ['es'])
    ..addOption(_apiKey, help: 'path to api_key must be provided')
    ..addOption(
      _outputFileName,
      defaultsTo: 'arb_translator_',
      help: 'output_file_name is the file name used to concate before language '
          'codes',
    )
    ..addFlag(
      _appendLangCode,
      defaultsTo: true,
      help: 'whether to append language code to output filenames',
    )
    ..addFlag(
      _copySourceToOutput,
      defaultsTo: false,
      help: 'whether to copy the source directory to the output directory',
    );

  return parser;
}

ArgResults parseArguments(List<String> args) {
  final parser = _initiateParse();
  final result = parser.parse(args);

  if (result[_help] as bool? ?? false) {
    print(parser.usage);
    exit(0);
  }

  if (!result.wasParsed(_sourceArb) && !result.wasParsed(_sourceDir)) {
    _setBrightRed();
    stderr.write('Either --source_arb or --source_dir is required.');
    exit(2);
  }

  if (!result.wasParsed(_apiKey)) {
    _setBrightRed();
    stderr.write('--api_key is required');
    exit(2);
  }
  return result;
}

File createFileRef(String path) {
  final file = File(path);
  if (file.existsSync()) {
    return file;
  } else {
    _setBrightRed();
    stderr.write('$file not found on path ${file.path}');
    exit(2);
  }
}
