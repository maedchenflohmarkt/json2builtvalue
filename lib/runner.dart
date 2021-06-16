//
// Created by S. Alikhver on 11.06.21.
//
import 'dart:io';

import 'package:json2builtvalue/json_schema_parser.dart';
import 'package:json2builtvalue/root.dart';

void main() {
  final parser = new JsonSchemaParser();

  Directory inDir = Directory("in");

  Stream.fromIterable(inDir.listSync(recursive: false))
      .forEach((fileEntity) async {
    if (fileEntity is File) {
      String jsonString = fileEntity.readAsStringSync();
      Map<String, String> classFiles = parser.parseToMap(
          jsonString,
          fileEntity.uri.pathSegments.last.split(".").first,
          [],
          SerializationOptions(
              serializersImport: "core/app/model/serializers.dart",
              serializersVariableName: "serializers"));

      await Stream.fromIterable(classFiles.entries).forEach((entry) {
        String filename = 'gen/${entry.key}.dart';
        print("Preparing file: $filename");
        File(filename)
            .create(recursive: true)
            .then((file) => file.writeAsString(entry.value))
            .then((value) => print("File is done: ${filename}"));
      });
    }
  });
}
