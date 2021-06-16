//
// Created by S. Alikhver on 10.06.21.
//

import 'package:json2builtvalue/generator.dart';
import 'package:json2builtvalue/root.dart';
import 'package:json_schema/json_schema.dart';
import 'package:recase/recase.dart';

class JsonSchemaParser {
  final Set<String> typesRepo = Set();

  Map<String, String> parseToMap(
      String jsonSchemeString, String topLevelName, List<String> reservedNames,
      [SerializationOptions? options]) {
    JsonSchema schema = JsonSchema.createSchema(jsonSchemeString);
    return _recursiveParsing(topLevelName + "Model", schema, options);
  }

  Map<String, String> _recursiveParsing(
      String className, JsonSchema schema, SerializationOptions? options) {
    List<GenClass> allClasses = [];
    Map<String, String> result = {};

    List<GenField> fields = _getTypedClassFields(schema);
    allClasses.add(new GenClass(className, fields));
    fields.map((field) => field.type).forEach((GenType type) {
      if ((((type.type == JsonType.LIST || type.type == JsonType.LIST_N) &&
                  (type.listType == JsonType.MAP ||
                      type.listType == JsonType.MAP_N)) ||
              type.type == JsonType.MAP ||
              type.type == JsonType.MAP_N) &&
          !typesRepo.contains(type.name)) {
        typesRepo.add(type.name);
        result.addAll(
            _recursiveParsing(type.name, type.rawData as JsonSchema, options));
      }
    });

    result.addEntries(allClasses.map((cl) => MapEntry(ReCase(cl.name).snakeCase,
        Generator.generateStringClass(cl, options))));

    return result;
  }

  List<GenField> _getTypedClassFields(JsonSchema schema) {
    List<GenField> parentFieldsList = [];

    schema.properties.forEach((key, val) {
      parentFieldsList.add(_returnField(key, val));
    });

    return parentFieldsList;
  }

  GenField _returnField(String key, JsonSchema val) {
    print("_returnType for $key == ${val.typeList}");
    SchemaType type = val.type ??
        val.typeList!.firstWhere((element) => element != SchemaType.nullValue);
    bool isNullable =
        val.typeList!.any((element) => element == SchemaType.nullValue);
    if (type == SchemaType.string)
      return GenField(
          GenType(key, isNullable ? JsonType.STRING_N : JsonType.STRING, val),
          key);
    else if (type == SchemaType.integer)
      return GenField(
          GenType(key, isNullable ? JsonType.INT_N : JsonType.INT, val), key);
    else if (type == SchemaType.number)
      return GenField(
          GenType(key, isNullable ? JsonType.DOUBLE_N : JsonType.DOUBLE, val),
          key);
    else if (type == SchemaType.boolean)
      return GenField(
          GenType(key, isNullable ? JsonType.BOOL_N : JsonType.BOOL, val), key);
    else if (type == SchemaType.array) {
      return GenField(
          GenType("${val.items?.propertyName ?? key}Model",
              isNullable ? JsonType.LIST_N : JsonType.LIST, val.items,
              listType: _returnListType(val.items!)),
          key);
    } else if (type == SchemaType.object) {
      return GenField(
          GenType("${val.propertyName ?? key}Model",
              isNullable ? JsonType.MAP_N : JsonType.MAP, val),
          key);
    } else
      throw new ArgumentError('Cannot resolve JSON-encodable type for $val.');
  }

  JsonType _returnListType(JsonSchema val) {
    print("_returnJsonType for ${val.propertyName} == ${val.type}");
    SchemaType type = val.type ??
        val.typeList!.firstWhere((element) => element != SchemaType.nullValue);
    bool isNullable =
        val.typeList!.any((element) => element == SchemaType.nullValue);
    if (type == SchemaType.string)
      return isNullable ? JsonType.STRING_N : JsonType.STRING;
    else if (type == SchemaType.integer)
      return isNullable ? JsonType.INT_N : JsonType.INT;
    else if (type == SchemaType.number)
      return isNullable ? JsonType.DOUBLE_N : JsonType.DOUBLE;
    else if (type == SchemaType.boolean)
      return isNullable ? JsonType.BOOL_N : JsonType.BOOL;
    else if (type == SchemaType.object)
      return isNullable ? JsonType.MAP_N : JsonType.MAP;
    else
      throw new ArgumentError('Cannot resolve JSON-encodable type for $val.');
  }
}
