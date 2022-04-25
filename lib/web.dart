import 'dart:io';

import 'package:flutter_launcher_icons/constants.dart' as constants;
import 'package:flutter_launcher_icons/utils.dart';

void createIcons(
  Map<String, dynamic> flutterLauncherIconsConfig,
  String? flavor,
) {
  printStatus('Creating icons WEB');
  final String filesPath = getWebFilesPath(flutterLauncherIconsConfig);
  final List<File> files = getWebFiles(filesPath);
  saveWebFiles(files);
  editIndexFile();
}

List<File> getWebFiles(String filesPath) {
  final List<File> files = [];

  final Directory dir = Directory(filesPath);

  void task(List<FileSystemEntity> entities) {
    for (var file in entities) {
      if (file is File) {
        files.add(file);
      } else if (file is Directory) {
        task(file.listSync());
      }
    }
  }

  task(dir.listSync());

  return files;
}

void saveWebFiles(List<File> files) {
  for (var file in files) {
    final String fileName = file.path.split('/').last;
    final String newFilePath = '${constants.webResFolder}$fileName';
    final File newFile = File(newFilePath);
    if (!newFile.existsSync()) {
      newFile.createSync(recursive: true);
    }
    newFile.writeAsBytesSync(file.readAsBytesSync());
  }
}

void editIndexFile() {
  const String indexFilePath = '${constants.webResFolder}index.html';
  final File indexFile = File(indexFilePath);
  String indexFileContent = indexFile.readAsStringSync();

  indexFileContent = _replaceAppleTouchIcon(indexFileContent);
  indexFileContent = _replaceShortcutIcon(indexFileContent);
  indexFileContent = _replaceTitle(indexFileContent);

  indexFile.writeAsStringSync(indexFileContent);
}

const String _nameStart = '"name": "';
const String _nameEnd = '",';
String _replaceTitle(String indexFileContent) {
  const String manifestFilePath = '${constants.webResFolder}manifest.json';
  final File manifestFile = File(manifestFilePath);
  final String manifestFileContent = manifestFile.readAsStringSync();
  final int nameStartIndex = manifestFileContent.indexOf(_nameStart);
  final int nameEndIndex =
      manifestFileContent.indexOf(_nameEnd, nameStartIndex);
  final String newTitle = manifestFileContent.substring(
    nameStartIndex + _nameStart.length,
    nameEndIndex,
  );

  return _replaceIndexTag(
    indexFileContent: indexFileContent,
    tagName: 'title',
    newContent: newTitle,
  );
}

String _replaceAppleTouchIcon(String indexFileContent) {
  return _replaceIndexHrefFilePath(
    indexFileContent: indexFileContent,
    tagName: 'apple-touch-icon',
    newContent: constants.newAppleTouchIconFilePath,
  );
}

String _replaceShortcutIcon(String indexFileContent) {
  return _replaceIndexHrefFilePath(
    indexFileContent: indexFileContent,
    tagName: 'shortcut icon',
    newContent: constants.newShortcutIconFilePath,
  );
}

const String _hrefStart = 'href="';
const String _hrefEnd = '"';
String _replaceIndexHrefFilePath({
  required String indexFileContent,
  required String tagName,
  required String newContent,
}) {
  final int appleTouchIconIndex = indexFileContent.indexOf(tagName);
  if (appleTouchIconIndex != -1) {
    final String restantIndexContent = indexFileContent.substring(
      appleTouchIconIndex,
      indexFileContent.length - 1,
    );

    final int startHrefIndex = restantIndexContent.indexOf(_hrefStart);
    final int endHRefIndex = restantIndexContent.indexOf(
      _hrefEnd,
      startHrefIndex + _hrefStart.length + 1,
    );

    final int appleTouchIconHrefStartIndex =
        appleTouchIconIndex + startHrefIndex + _hrefStart.length;
    final int appleTouchIconHrefEndIndex = appleTouchIconHrefStartIndex +
        (endHRefIndex - (startHrefIndex + _hrefStart.length));

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

String _tagStart(String name) => '<$name>';
String _tagEnd(String name) => '</$name>';
String _replaceIndexTag({
  required String indexFileContent,
  required String tagName,
  required String newContent,
}) {
  final String tagStart = _tagStart(tagName);
  final String tagEnd = _tagEnd(tagName);

  final int startTagIndex = indexFileContent.indexOf(tagStart);
  final int endTagIndex = indexFileContent.indexOf(tagEnd, startTagIndex);

  final int hrefStartIndex = startTagIndex + tagStart.length;
  final int hrefEndIndex = endTagIndex;

  indexFileContent = indexFileContent.replaceRange(
    hrefStartIndex,
    hrefEndIndex,
    newContent,
  );

  return indexFileContent;
}

String getWebFilesPath(Map<String, dynamic> config) {
  return config['web_files_path'];
}
