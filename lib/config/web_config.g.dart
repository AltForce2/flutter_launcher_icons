// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebConfig _$WebConfigFromJson(Map json) => $checkedCreate(
  'WebConfig',
  json,
  ($checkedConvert) {
    final val = WebConfig(
      generate: $checkedConvert('generate', (v) => v as bool? ?? false),
      imagePath: $checkedConvert('image_path', (v) => v as String?),
      backgroundColor: $checkedConvert('background_color', (v) => v as String?),
      themeColor: $checkedConvert('theme_color', (v) => v as String?),
      webIconsPath: $checkedConvert('web_icons_path', (v) => v as String?),
      webManifestPath: $checkedConvert(
        'web_manifest_path',
        (v) => v as String?,
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'imagePath': 'image_path',
    'backgroundColor': 'background_color',
    'themeColor': 'theme_color',
    'webIconsPath': 'web_icons_path',
    'webManifestPath': 'web_manifest_path',
  },
);

Map<String, dynamic> _$WebConfigToJson(WebConfig instance) => <String, dynamic>{
  'generate': instance.generate,
  'image_path': instance.imagePath,
  'background_color': instance.backgroundColor,
  'theme_color': instance.themeColor,
  'web_icons_path': instance.webIconsPath,
  'web_manifest_path': instance.webManifestPath,
};
