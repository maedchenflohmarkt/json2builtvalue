import 'dart:convert';

import 'package:json2builtvalue/root.dart';
import 'package:recase/recase.dart';

import 'generator.dart';

class JsonParser {
  final Set<String> classNamesRepo = Set();

  String parse(
      String jsonString, String topLevelName, List<String> reservedNames,
      [SerializationOptions? options]) {
    return parseToMap(jsonString, topLevelName, reservedNames, options)
        .values
        .reduce((s1, s2) => s1 + s2);
  }

  Map<String, String> parseToMap(
      String jsonString, String topLevelName, List<String> reservedNames,
      [SerializationOptions? options]) {
    classNamesRepo.clear();
    classNamesRepo
        .addAll(reservedNames.map((className) => className.toLowerCase()));
    var decode = json.decode(jsonString);
    return _recurseParsing(topLevelName, decode, options);
  }

  Map<String, String> _recurseParsing(
      className, decode, SerializationOptions? options) {
    List<GenClass> allClasses = [];
    Map<String, String> result = {};

    List<GenField> fields = _getTypedClassFields(decode);
    fields = fields.map((f) {
      String realClassName = f.type.name;
      while (!classNamesRepo.add(realClassName)) {
        realClassName += "Of${ReCase(className).pascalCase}";
      }
      return GenField(f.type.copyWith(realClassName), f.fieldName);
    }).toList();

    allClasses.add(new GenClass(className, fields));
    fields.map((field) => field.type).forEach((GenType s) {
      if ((s.type == JsonType.LIST && s.listType == JsonType.MAP) ||
          s.type == JsonType.MAP) {
        result.addAll(_recurseParsing(s.name, s.rawData, options));
      }
    });

    result.addEntries(allClasses.map((cl) => MapEntry(ReCase(cl.name).snakeCase,
        Generator.generateStringClass(cl, options))));

    return result;
  }

  List<GenField> _getTypedClassFields(decode) {
    List<GenField> parentFieldsList = [];
    var toDecode;

    if (decode is List) {
      toDecode = decode[0];
    } else {
      toDecode = decode;
    }

    toDecode.forEach((key, val) {
      parentFieldsList.add(_returnType(key, val));
    });

    return parentFieldsList;
  }

  GenField _returnType(key, val) {
    if (val is String)
      return GenField(GenType(key, JsonType.STRING, val), key);
    else if (val is int)
      return GenField(GenType(key, JsonType.INT, val), key);
    else if (val is num)
      return GenField(GenType(key, JsonType.DOUBLE, val), key);
    else if (val is bool)
      return GenField(GenType(key, JsonType.BOOL, val), key);
    else if (val is List) {
      return GenField(
          GenType(key, JsonType.LIST, val, listType: _returnJsonType(val)),
          key);
    } else if (val is Map) {
      return GenField(GenType(key, JsonType.MAP, val), key);
    } else
      throw new ArgumentError('Cannot resolve JSON-encodable type for $val.');
  }

  JsonType _returnJsonType(List list) {
    var item = list[0];
    print('got item $item');
    if (item is String)
      return JsonType.STRING;
    else if (item is int)
      return JsonType.INT;
    else if (item is num)
      return JsonType.DOUBLE;
    else if (item is bool)
      return JsonType.BOOL;
    else if (item is Map)
      return JsonType.MAP;
    else
      throw new ArgumentError('Cannot resolve JSON-encodable type for $item.');
  }
}
