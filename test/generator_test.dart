import 'dart:async';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:json2builtvalue/parser.dart';
import 'package:test/test.dart';

main() {
  final _dartfmt = new DartFormatter();

//  "targets": ["dartium","javascript"],

  final String jsonString = """
  {
  "language": "dart",
  "age": 1,
  "website": {
    "homepage": "www.dartlang.org",
    "api": "api.dartlang.org",
    "value" : {
      "type": "int",
      "obj": 12
    } 
  },
  "property": {
    "property": {
        "data": {
          "type": "text"
        }
    }
  }, 
  "is_new": true,
  "version": 2.0
}
  """;

//  final String jsonString = """
//  {
//  "website": {
//    "homepage": "www.dartlang.org",
//    "api": "api.dartlang.org"
//  }
//}
//  """;

//  final String jsonString = """
//  {
//   "targets": ["dartium","javascript"]
//  }
//  """;

  test('should parse json', () async {
    final parser = new Parser();

    Map<String, String> classFiles =
        parser.parseToMap(jsonString, 'RootModel', ["Value"]);

    Stream files = Stream.fromIterable(classFiles.entries).asyncMap((entry) {
      String filename = 'gen/${entry.key}.dart';
      print("Preparing file: $filename");
      return File(filename)
          .create(recursive: true)
          .then((file) => file.writeAsString(entry.value));
    });

    await for (var file in files) {
      print("File is done: ${file.path}");
    }

    print("Done!");

    expect(true, true);
  });
}
