import 'dart:convert';
import 'dart:io';

import 'package:flutter_launcher_icons/config/web_config.dart';
import 'package:flutter_launcher_icons/constants.dart' as constants;
import 'package:flutter_launcher_icons/custom_exceptions.dart';
import 'package:flutter_launcher_icons/utils.dart' as utils;
import 'package:flutter_launcher_icons/web/web_template.dart';
import 'package:image/image.dart';
import 'package:path/path.dart' as path;

/// Creates web icons for the Flutter app
void createIcons(Map<String, dynamic> flutterLauncherIconsConfig, String? flavor) {
  // Check if web generation is enabled
  final webConfig = flutterLauncherIconsConfig['web'];
  if (webConfig == null) {
    print('Web configuration not found');
    return;
  }

  // Handle both Map and WebConfig types
  bool shouldGenerate = false;
  if (webConfig is Map<String, dynamic>) {
    shouldGenerate = webConfig['generate'] == true;
  } else if (webConfig is WebConfig) {
    shouldGenerate = webConfig.generate;
  }

  if (!shouldGenerate) {
    print('Web icon generation is disabled');
    return;
  }

  utils.printStatus('Creating icons WEB');

  // Determine if we should generate new icons or copy existing ones
  final bool shouldGenerateNewIcons = _shouldGenerateNewIcons(flutterLauncherIconsConfig);

  if (shouldGenerateNewIcons) {
    _generateNewWebIcons(flutterLauncherIconsConfig, flavor);
  } else {
    _copyExistingWebFiles(flutterLauncherIconsConfig);
  }

  editIndexFile();
}

/// Determines if we should generate new icons or copy existing ones
bool _shouldGenerateNewIcons(Map<String, dynamic> config) {
  // Check if we have an image path for generation
  final webConfig = config['web'];
  String? imagePath;

  if (webConfig is Map<String, dynamic>) {
    imagePath = webConfig['image_path'];
  } else if (webConfig is WebConfig) {
    imagePath = webConfig.imagePath;
  }

  // If no specific web image path, check global image path
  imagePath ??= config['image_path'];

  return imagePath != null;
}

/// Generates new web icons from an image file
Future<void> _generateNewWebIcons(Map<String, dynamic> config, String? flavor) async {
  try {
    // Get image path
    final webConfig = config['web'];
    String? imagePath;

    if (webConfig is Map<String, dynamic>) {
      imagePath = webConfig['image_path'];
    } else if (webConfig is WebConfig) {
      imagePath = webConfig.imagePath;
    }

    // Fallback to global image path
    imagePath ??= config['image_path'];

    if (imagePath == null) {
      throw Exception('No image path found for web icon generation');
    }

    final imgFilePath = path.join(flavor ?? '', imagePath);

    // Decode and load image
    final imgFile = await utils.decodeImageFile(imgFilePath);
    if (imgFile == null) {
      throw FileNotFoundException(imgFilePath);
    }

    // Generate favicon
    await _generateFavicon(imgFile, flavor);

    // Generate icons
    await _generateIcons(imgFile, flavor);

    // Update manifest
    await _updateManifestFile(config, flavor);
  } catch (e) {
    print('Error generating new web icons: $e');
    rethrow;
  }
}

/// Generates favicon from image
Future<void> _generateFavicon(Image image, String? flavor) async {
  final favIcon = utils.createResizedImage(constants.kFaviconSize, image);
  final favIconPath = path.join(flavor ?? '', constants.webFaviconFilePath);
  final favIconFile = await utils.createFileIfNotExist(favIconPath);
  await favIconFile.writeAsBytes(encodePng(favIcon));
}

/// Generates web icons from image
Future<void> _generateIcons(Image image, String? flavor) async {
  const webIconSizeTemplates = <WebIconTemplate>[
    WebIconTemplate(size: 192),
    WebIconTemplate(size: 512),
    WebIconTemplate(size: 192, maskable: true),
    WebIconTemplate(size: 512, maskable: true),
  ];

  final iconsDirPath = path.join(flavor ?? '', constants.webIconsDirPath);
  final iconsDir = await utils.createDirIfNotExist(iconsDirPath);

  for (final template in webIconSizeTemplates) {
    final resizedImg = utils.createResizedImage(template.size, image);
    final iconFile = await utils.createFileIfNotExist(path.join(iconsDir.path, template.iconFile));
    await iconFile.writeAsBytes(encodePng(resizedImg));
  }
}

/// Updates manifest.json with new icon configurations
Future<void> _updateManifestFile(Map<String, dynamic> config, String? flavor) async {
  final manifestPath = path.join(flavor ?? '', constants.webManifestFilePath);
  final manifestFile = await utils.createFileIfNotExist(manifestPath);

  Map<String, dynamic> manifestConfig;
  try {
    final content = await manifestFile.readAsString();
    manifestConfig = jsonDecode(content) as Map<String, dynamic>;
  } catch (e) {
    // If manifest doesn't exist or is invalid, create a basic one
    manifestConfig = {
      'name': 'Flutter App',
      'short_name': 'Flutter App',
      'start_url': '.',
      'display': 'standalone',
      'background_color': '#ffffff',
      'theme_color': '#ffffff',
      'icons': [],
    };
  }

  // Update colors if specified
  final webConfig = config['web'];
  if (webConfig is Map<String, dynamic>) {
    if (webConfig['background_color'] != null) {
      manifestConfig['background_color'] = webConfig['background_color'];
    }
    if (webConfig['theme_color'] != null) {
      manifestConfig['theme_color'] = webConfig['theme_color'];
    }
  } else if (webConfig is WebConfig) {
    if (webConfig.backgroundColor != null) {
      manifestConfig['background_color'] = webConfig.backgroundColor;
    }
    if (webConfig.themeColor != null) {
      manifestConfig['theme_color'] = webConfig.themeColor;
    }
  }

  // Update icons
  const webIconSizeTemplates = <WebIconTemplate>[
    WebIconTemplate(size: 192),
    WebIconTemplate(size: 512),
    WebIconTemplate(size: 192, maskable: true),
    WebIconTemplate(size: 512, maskable: true),
  ];

  manifestConfig['icons'] = webIconSizeTemplates.map<Map<String, dynamic>>((e) => e.iconManifest).toList();

  await manifestFile.writeAsString(utils.prettifyJsonEncode(manifestConfig));
}

/// Copies existing web files (legacy approach)
void _copyExistingWebFiles(Map<String, dynamic> flutterLauncherIconsConfig) {
  try {
    // Check if we have custom paths for existing files
    final bool hasCustomPaths = _hasCustomWebPaths(flutterLauncherIconsConfig);

    if (hasCustomPaths) {
      // Copy from custom paths
      final List<File> iconsFiles = _getWebIconsFiles(flutterLauncherIconsConfig);
      _saveWebIconsFiles(iconsFiles);

      final File manifestFile = _getWebManifestFile(flutterLauncherIconsConfig);
      _saveWebManifestFile(manifestFile);
    } else {
      print('No custom web paths found and no image path for generation. Using default web structure.');
    }
  } catch (e) {
    print('Error copying existing web files: $e');
    rethrow;
  }
}

/// Checks if custom web paths are configured
bool _hasCustomWebPaths(Map<String, dynamic> config) {
  // Check root level paths
  if (config['web_icons_path'] != null || config['web_manifest_path'] != null) {
    return true;
  }

  // Check web config paths
  final webConfig = config['web'];
  if (webConfig is Map<String, dynamic>) {
    return webConfig['web_icons_path'] != null || webConfig['web_manifest_path'] != null;
  } else if (webConfig is WebConfig) {
    return webConfig.webIconsPath != null || webConfig.webManifestPath != null;
  }

  return false;
}

/// Gets web icons files from the specified path
List<File> _getWebIconsFiles(Map<String, dynamic> flutterLauncherIconsConfig) {
  final List<File> files = [];

  final String iconsPath = getWebIconsPath(flutterLauncherIconsConfig);
  final Directory dir = Directory(iconsPath);

  if (!dir.existsSync()) {
    print('Warning: Icons directory does not exist: $iconsPath');
    return files;
  }

  void task(FileSystemEntity entity) {
    if (entity is File) {
      files.add(entity);
    }
  }

  dir.listSync().forEach(task);

  return files;
}

/// Gets the web manifest file
File _getWebManifestFile(Map<String, dynamic> flutterLauncherIconsConfig) {
  final String manifestPath = getWebManifestPath(flutterLauncherIconsConfig);
  final File manifestFile = File(manifestPath);

  if (!manifestFile.existsSync()) {
    throw Exception('Manifest file not found: $manifestPath');
  }

  return manifestFile;
}

/// Saves web icons files to the web icons folder
void _saveWebIconsFiles(List<File> files) {
  _saveWebBaseFiles(files, constants.webIconsFolder);
}

/// Saves web manifest file to the web resources folder
void _saveWebManifestFile(File file) {
  _saveWebBaseFiles([file], constants.webResFolder);
}

/// Base function to save web files to the specified folder
void _saveWebBaseFiles(List<File> files, String folderName) {
  for (var file in files) {
    final String fileName = file.path.split('/').last.toLowerCase();
    final String newFilePath = '$folderName$fileName';
    final File newFile = File(newFilePath);
    if (!newFile.existsSync()) {
      newFile.createSync(recursive: true);
    }
    file.copySync(newFilePath);
  }
}

/// Edits the index.html file to update web icons
void editIndexFile() {
  final File indexFile = File(constants.webIndexFilePath);
  String indexFileContent = indexFile.readAsStringSync();

  indexFileContent = _replaceAppleTouchIcon(indexFileContent);
  indexFileContent = _replaceShortcutIcon(indexFileContent);
  indexFileContent = _replaceTitle(indexFileContent);

  indexFile.writeAsStringSync(indexFileContent);
}

const String _nameStart = '"name": "';
const String _nameEnd = '",';

/// Replaces the title in index.html with the one from manifest.json
String _replaceTitle(String indexFileContent) {
  try {
    final String manifestFilePath = '${constants.webResFolder}manifest.json';
    final File manifestFile = File(manifestFilePath);

    if (!manifestFile.existsSync()) {
      print('Warning: Manifest file not found, skipping title replacement');
      return indexFileContent;
    }

    final String manifestFileContent = manifestFile.readAsStringSync();
    final int nameStartIndex = manifestFileContent.indexOf(_nameStart);

    if (nameStartIndex == -1) {
      print('Warning: Could not find name in manifest.json');
      return indexFileContent;
    }

    final int nameEndIndex = manifestFileContent.indexOf(_nameEnd, nameStartIndex);

    if (nameEndIndex == -1) {
      print('Warning: Could not find end of name in manifest.json');
      return indexFileContent;
    }

    final String newTitle = manifestFileContent.substring(nameStartIndex + _nameStart.length, nameEndIndex);

    return _replaceIndexTag(indexFileContent: indexFileContent, tagName: 'title', newContent: newTitle);
  } catch (e) {
    print('Error replacing title: $e');
    return indexFileContent;
  }
}

/// Replaces the apple touch icon in index.html
String _replaceAppleTouchIcon(String indexFileContent) {
  return _replaceIndexHrefFilePath(
    indexFileContent: indexFileContent,
    tagName: 'apple-touch-icon',
    newContent: constants.newAppleTouchIconFilePath,
  );
}

/// Replaces the shortcut icon in index.html
String _replaceShortcutIcon(String indexFileContent) {
  return _replaceIndexHrefFilePath(
    indexFileContent: indexFileContent,
    tagName: 'shortcut icon',
    newContent: constants.newShortcutIconFilePath,
  );
}

const String _hrefStart = 'href="';
const String _hrefEnd = '"';

/// Replaces href file paths in index.html
String _replaceIndexHrefFilePath({
  required String indexFileContent,
  required String tagName,
  required String newContent,
}) {
  final int appleTouchIconIndex = indexFileContent.indexOf(tagName);
  if (appleTouchIconIndex != -1) {
    final String restantIndexContent = indexFileContent.substring(appleTouchIconIndex, indexFileContent.length - 1);

    final int startHrefIndex = restantIndexContent.indexOf(_hrefStart);
    final int endHRefIndex = restantIndexContent.indexOf(_hrefEnd, startHrefIndex + _hrefStart.length + 1);

    final int appleTouchIconHrefStartIndex = appleTouchIconIndex + startHrefIndex + _hrefStart.length;
    final int appleTouchIconHrefEndIndex =
        appleTouchIconHrefStartIndex + (endHRefIndex - (startHrefIndex + _hrefStart.length));

    indexFileContent = indexFileContent.replaceRange(
      appleTouchIconHrefStartIndex,
      appleTouchIconHrefEndIndex,
      newContent,
    );
  } else {
    print('$tagName not found');
  }

  return indexFileContent;
}

/// Creates start and end tags for HTML elements
String _tagStart(String name) => '<$name>';
String _tagEnd(String name) => '</$name>';

/// Replaces content between HTML tags
String _replaceIndexTag({required String indexFileContent, required String tagName, required String newContent}) {
  final String tagStart = _tagStart(tagName);
  final String tagEnd = _tagEnd(tagName);

  final int startTagIndex = indexFileContent.indexOf(tagStart);
  final int endTagIndex = indexFileContent.indexOf(tagEnd, startTagIndex);

  final int hrefStartIndex = startTagIndex + tagStart.length;
  final int hrefEndIndex = endTagIndex;

  indexFileContent = indexFileContent.replaceRange(hrefStartIndex, hrefEndIndex, newContent);

  return indexFileContent;
}

/// Gets the web icons path from configuration
String getWebIconsPath(Map<String, dynamic> config) {
  // Try to get from web_icons_path first (root level)
  final path = config['web_icons_path'];
  if (path != null) {
    return path.toString();
  }

  // Fallback to web.web_icons_path if exists
  final webConfig = config['web'];
  if (webConfig is Map<String, dynamic> && webConfig['web_icons_path'] != null) {
    return webConfig['web_icons_path'].toString();
  } else if (webConfig is WebConfig && webConfig.webIconsPath != null) {
    return webConfig.webIconsPath!;
  }

  throw Exception('web_icons_path is required in configuration');
}

/// Gets the web manifest path from configuration
String getWebManifestPath(Map<String, dynamic> config) {
  // Try to get from web_manifest_path first (root level)
  final path = config['web_manifest_path'];
  if (path != null) {
    return path.toString();
  }

  // Fallback to web.web_manifest_path if exists
  final webConfig = config['web'];
  if (webConfig is Map<String, dynamic> && webConfig['web_manifest_path'] != null) {
    return webConfig['web_manifest_path'].toString();
  } else if (webConfig is WebConfig && webConfig.webManifestPath != null) {
    return webConfig.webManifestPath!;
  }

  throw Exception('web_manifest_path is required in configuration');
}
