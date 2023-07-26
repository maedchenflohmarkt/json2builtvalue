//
// Created by S. Alikhver on 11.06.21.
//
import 'dart:io';

import 'package:json2builtvalue/json_schema_parser.dart';
import 'package:json2builtvalue/root.dart';

void main(List<String> args) {
  final schemaDir = args.length > 0 ? args[0] : "in";
  final serializersImport =
      args.length > 1 ? args[1] : "core/app/model/serializers.dart";

  final parser = new JsonSchemaParser();

  Directory(schemaDir)
      .listSync(recursive: false)
      .expand<MapEntry<String, String>>((fileEntity) => (fileEntity is File)
          ? parser
              .parseToMap(
                  fileEntity.readAsStringSync(),
                  fileEntity.uri.pathSegments.last.split(".").first,
                  [],
                  SerializationOptions(
                      serializersImport: serializersImport,
                      serializersVariableName: "serializers"))
              .entries
          : [])
      .map((entry) => File('gen/${entry.key}.dart')
          .create(recursive: true)
          .then((file) => file.writeAsString(entry.value)))
      .forEach((file) async => print("File is done: ${(await file).path}"));
}
