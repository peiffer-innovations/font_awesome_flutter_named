import 'dart:convert';
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:recase/recase.dart';
import 'package:version/version.dart';

/// Generated by [readAndPickMetadata] for each icon
class IconMetadata {
  final String name;
  final String label;
  final String unicode;
  final List<String> searchTerms;
  final List<String> styles;

  IconMetadata(
      this.name, this.label, this.unicode, this.searchTerms, this.styles);
}

const List<String> ignoredIcons = [
  'acquisitionsIncorporated',
  'pennyArcade',
];

const Map<String, String> nameAdjustments = {
  "500px": "fiveHundredPx",
  "360-degrees": "threeHundredSixtyDegrees",
  "1": "one",
  "2": "two",
  "3": "three",
  "4": "four",
  "5": "five",
  "6": "six",
  "7": "seven",
  "8": "eight",
  "9": "nine",
  "0": "zero",
  "42-group": "fortyTwoGroup"
};

final AnsiPen red = AnsiPen()..xterm(009);
final AnsiPen blue = AnsiPen()..xterm(012);
final AnsiPen yellow = AnsiPen()..xterm(011);

/// Utility program to customize font awesome flutter
///
/// For usage information see [displayHelp]
///
/// Steps:
/// 1. Check if icons.json exists in project root (or in lib/fonts)
/// if icons.json does not exist:
///   1.1 download official, free icons.json from github
///     https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/metadata/icons.json
///   1.2 download official, free icons and replace existing
///     https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-brands-400.ttf
///     https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-regular-400.ttf
///     https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-solid-900.ttf
/// 3. filter out unwanted icon styles
/// 4. build icons, example
/// if dynamic icons requested:
///   4.1 create map
/// 5. if duotone icons exist, enable them
/// 6. format all generated files
/// 7. if icons.json was downloaded by this tool, remove icons.json
void main(List<String> rawArgs) async {
  print(blue('''
####  #   #####################################################################
###  ###  ############ Font Awesome Flutter Configurator ######################
#   #   # #####################################################################
  '''));

  final argParser = setUpArgParser();
  final args = argParser.parse(rawArgs);

  if (args['help']) {
    displayHelp(argParser);
    exit(0);
  }

  File iconsJson = File('assets/fonts/icons.json');
  final hasCustomIconsJson = iconsJson.existsSync();

  if (!hasCustomIconsJson) {
    print(blue('No icons.json found, updating free icons'));
    await download(
        'https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/metadata/icons.json',
        File('assets/fonts/icons.json'));
    // await download(
    //     'https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-brands-400.ttf',
    //     File('assets/fonts/fa-brands-400.ttf'));
    // await download(
    //     'https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-regular-400.ttf',
    //     File('assets/fonts/fa-regular-400.ttf'));
    // await download(
    //     'https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/webfonts/fa-solid-900.ttf',
    //     File('assets/fonts/fa-solid-900.ttf'));
  } else {
    print(blue('Custom icons.json found, generating files'));
  }

  // A list of all versions mentioned in the metadata
  final List<String> versions = [];
  final List<IconMetadata> metadata = [];
  final Set<String> styles = {};
  final hasDuotoneIcons = readAndPickMetadata(
      iconsJson, metadata, styles, versions, args['exclude']);

  print(blue('\nGenerating example code'));
  writeCodeToFile(
    () => generateExamplesListClass(metadata, hasDuotoneIcons),
    'example/lib/icons.dart',
  );

  enableDuotoneExample(hasDuotoneIcons);

  writeCodeToFile(
    () => generateIconNameMap(metadata, hasDuotoneIcons),
    'lib/font_awesome_flutter_named.dart',
  );
}

/// Writes lines of code created by a [generator] to [filePath] and formats it
void writeCodeToFile(List<String> Function() generator, String filePath) {
  List<String> generated = generator();
  File(filePath).writeAsStringSync(generated.join('\n'));
  final result = Process.runSync('dart', ['format', filePath]);
  stdout.write(result.stdout);
  stderr.write(red(result.stderr));
}

/// Enables the use of a map to dynamically load icons by their name
///
/// To use, import:
/// `import 'package:font_awesome_flutter_named/font_awesome_flutter_named.dart'`
/// And then either use faIconNameMapping directly to look up specific icons,
/// or use the getIconFromCss helper function.
List<String> generateIconNameMap(
    List<IconMetadata> icons, bool hasDuotoneIcons) {
  print(yellow('''

------------------------------- IMPORTANT NOTICE -------------------------------
Dynamic icon retrieval by name disables icon tree shaking. This means unused
icons will not be automatically removed and thus make the overall app size
larger. It is highly recommended to use this option only in combination with
the "exclude" option, to remove styles which are not needed.
You may need to pass --no-tree-shake-icons to the flutter build command for it
to complete successfully.
--------------------------------------------------------------------------------
'''));

  print(blue('Generating name to icon mapping'));

  List<String> output = [
    '// ignore_for_file: deprecated_member_use',
    'library font_awesome_flutter_named;',
    '',
    "import 'package:flutter/widgets.dart';",
    "import 'package:font_awesome_flutter/font_awesome_flutter.dart';",
    '',
    '// THIS FILE IS AUTOMATICALLY GENERATED!',
    '',
    '/// Icon name to icon mapping for font awesome icons',
    '///',
    '/// Keys are in the following format: "style iconName"',
    'const Map<String, IconData> faIconNameMapping = {',
  ];

  var iconName;
  for (var icon in icons) {
    for (var style in icon.styles.where((style) => style != "duotone")) {
      iconName = normalizeIconName(icon.name, style, icon.styles.length);

      if (!ignoredIcons.contains(iconName)) {
        output.add("'$iconName': FontAwesomeIcons.$iconName,");
      }
    }
  }

  output.add('};');

  if (!hasDuotoneIcons) return output;

  output.addAll([
    '',
    '/// Icon name to icon mapping for duotone font awesome icons',
    'const Map<String, IconDataDuotone> faIconNameMappingDuotone = {',
  ]);

  for (var icon in icons) {
    if (icon.styles.contains('duotone')) {
      iconName = normalizeIconName(icon.name, "duotone", icon.styles.length);
      output.add("'${icon.name}': FontAwesomeIcons.$iconName,");
    }
  }

  output.add('};');

  return output;
}

/// Enables duotone support in the example app if duotone icons were found
///
/// Also disables it if no more duotone icons are present
void enableDuotoneExample(bool hasDuotoneIcons) {
  // Enable duotone example if duotone icons exist

  var exampleMain = new File('example/lib/main.dart').readAsStringSync();
  var duotoneMainExists = exampleMain.contains('FaDuotoneIcon');

  var result;
  if (hasDuotoneIcons && !duotoneMainExists) {
    print(blue("\nFound duotone icons. Enabling duotone example."));
    result = Process.runSync('git', ['apply', 'util/duotone_main.patch']);
  } else if (!hasDuotoneIcons && duotoneMainExists) {
    print(blue("\nDid not find duotone icons. Disabling duotone example."));
    result = Process.runSync('git', ['apply', '-R', 'util/duotone_main.patch']);
  } else {
    result = Null;
  }

  if (result != Null) {
    stdout.write(result.stdout);
    stderr.write(red(result.stderr));
  }
}

/// Builds the example icons
List<String> generateExamplesListClass(
    List<IconMetadata> metadata, bool hasDuotoneIcons) {
  final List<String> output = [
    "import 'package:font_awesome_flutter_example/example_icon.dart';",
    "import 'package:font_awesome_flutter_named/font_awesome_flutter_named.dart';",
    '',
    '// THIS FILE IS AUTOMATICALLY GENERATED!',
    '',
    'final icons = <ExampleIcon>[',
  ];

  for (var icon in metadata) {
    for (String style in icon.styles) {
      output.add(generateExampleIcon(icon, style));
    }
  }

  output.add('];');

  return output;
}

/// Generates an icon for the example app. Used by [generateExamplesListClass]
String generateExampleIcon(IconMetadata icon, String style) {
  var iconName = normalizeIconName(icon.name, style, icon.styles.length);

  return "ExampleIcon(faIconNameMapping[\'$iconName\']!, '$iconName'),";
}

/// Returns a normalized version of [iconName] which can be used as const name
///
/// [nameAdjustments] lists some icons which need special treatment to be valid
/// const identifiers, as they cannot start with a number.
/// The [style] name is automatically appended if necessary - deemed by the
/// number of [styleCompetitors] (number of styles) for this icon.
String normalizeIconName(String iconName, String style, int styleCompetitors) {
  iconName = nameAdjustments[iconName] ?? iconName;

  if (styleCompetitors > 1 && style != "regular") {
    iconName = "${style}_$iconName";
  }

  return iconName.camelCase;
}

/// Reads the [iconsJson] metadata and picks out relevant data
///
/// Relevant data includes search-terms, label, unicode, styles, changes and is
/// saved to [metadata] as [IconMetadata].
/// Changes versions are all put into the [versions] list to calculate the
/// latest font awesome version.
/// [excludedStyles], which can be set in the program arguments, are removed.
/// Returns whether the dataset contains duotone icons.
bool readAndPickMetadata(File iconsJson, List<IconMetadata> metadata,
    Set<String> styles, List<String> versions, List<String> excludedStyles) {
  var hasDuotoneIcons = false;

  var rawMetadata;
  try {
    final content = iconsJson.readAsStringSync();
    rawMetadata = json.decode(content);
  } catch (_) {
    print(
        'Error: Invalid icons.json. Please make sure you copied the correct file.');
    exit(1);
  }

  Map<String, dynamic> icon;
  for (var iconName in rawMetadata.keys) {
    icon = rawMetadata[iconName];

    // Add all changes to the list
    (icon['changes'] as List).forEach((v) => versions.add(v));

    List<String> iconStyles = (icon['styles'] as List).cast<String>();
    excludedStyles.forEach((excluded) => iconStyles.remove(excluded));

    if (iconStyles.isEmpty) continue;

    if (icon.containsKey('private') && icon['private']) continue;

    if (iconStyles.contains('duotone')) hasDuotoneIcons = true;

    styles.addAll(iconStyles);

    metadata.add(IconMetadata(
      iconName,
      icon['label'],
      icon['unicode'],
      (icon['search']['terms'] as List).map((e) => e.toString()).toList(),
      iconStyles,
    ));
  }

  return hasDuotoneIcons;
}

/// Calculates the highest version number found in the metadata
///
/// Expects a list of all versions listed in the metadata.
/// See [readAndPickMetadata].
Version calculateFontAwesomeVersion(List<String> versions) {
  final sortedVersions = versions.map((version) {
    try {
      return Version.parse(version);
    } on FormatException {
      return Version(0, 0, 0);
    }
  }).toList()
    ..sort();

  return sortedVersions.last;
}

/// Downloads the content from [url] and saves it to [target]
Future download(String url, File target) async {
  print('Downloading $url');
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();

  if (!target.existsSync()) {
    target.createSync(recursive: true);
  }
  return response.pipe(target.openWrite());
}

/// Defines possible command line arguments for this program
ArgParser setUpArgParser() {
  final argParser = ArgParser();

  argParser.addFlag('help',
      abbr: 'h',
      defaultsTo: false,
      negatable: false,
      help: 'display program options and usage information');

  argParser.addMultiOption('exclude',
      abbr: 'e',
      defaultsTo: [],
      allowed: ['brands', 'regular', 'solid', 'duotone', 'light', 'thin'],
      help: 'icon styles which are excluded by the generator');

  argParser.addFlag('dynamic',
      abbr: 'd',
      defaultsTo: false,
      negatable: false,
      help: 'builds a map, which allows to dynamically retrieve icons by name');

  return argParser;
}

/// Displays the program help page. Accessible via the --help command line arg
void displayHelp(ArgParser argParser) {
  var fileType = Platform.isWindows ? 'bat' : 'sh';
  print('''
This script helps you to customize the font awesome flutter package to fit your
individual needs. Please follow the "customizing font awesome flutter" guide on
github.

By default, this tool acts as an updater. It retrieves the newest version of
free font awesome icons from the web and generates all necessary files.
If an icons.json exists within the lib/fonts folder, no update is performed and
files in this folder are used for generation instead.
To exclude styles from generation, pass the "exclude" option with a comma
separated list of styles to ignore.

Usage:
configurator.$fileType [options]

Options:''');
  print(argParser.usage);
}
