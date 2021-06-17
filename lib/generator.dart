//
// Created by S. Alikhver on 10.06.21.
//
import 'package:built_collection/src/list.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:json2builtvalue/root.dart';
import 'package:recase/recase.dart';

class Generator {
  static final _dartfmt = new DartFormatter();

  static String generateStringClass(
      GenClass genClass, SerializationOptions? options) {
    var topLevelClass = new Class((b) => b
      ..abstract = true
      ..constructors.add(new Constructor((b) => b..name = '_'))
      ..implements.add(new Reference(
          'Built<${_getPascalCaseClassName(genClass.name)}, ${_getPascalCaseClassName(genClass.name)}Builder>'))
      ..name = _getPascalCaseClassName(genClass.name)
      ..methods = _buildMethods(genClass.fields)
      ..methods.add(new Method((b) => b
        ..type = MethodType.getter
        ..name = 'serializer'
        ..static = true
        ..lambda = true
        ..returns = new Reference(
            'Serializer<${_getPascalCaseClassName(genClass.name)}>')
        ..body = new Code('_\$${ReCase(genClass.name).camelCase}Serializer')))
      ..constructors.add(
        new Constructor((b) => b
          ..factory = true
          ..redirect = refer(' _\$${_getPascalCaseClassName(genClass.name)}')
          ..requiredParameters.add(new Parameter((b) => b
            ..defaultTo = Code('= _\$${_getPascalCaseClassName(genClass.name)}')
            ..name =
                '[updates(${_getPascalCaseClassName(genClass.name)}Builder b)]'))),
      ));

    if (options != null) {
      topLevelClass = topLevelClass.rebuild((b) => b
        ..methods.add(new Method((b) => b
          ..name = 'toJson'
          ..returns = new Reference('String')
          ..body = new Code(
              'return json.encode(${options.serializersVariableName}.serializeWith(${_getPascalCaseClassName(genClass.name)}.serializer, this));')))
        ..methods.add(new Method((b) => b
          ..name = 'fromJson'
          ..static = true
          ..requiredParameters.add(new Parameter((b) => b
            ..name = 'jsonString'
            ..type = new Reference('String')))
          ..returns =
              new Reference("${_getPascalCaseClassName(genClass.name)}?")
          ..body = new Code(
              'return ${options.serializersVariableName}.deserializeWith(${_getPascalCaseClassName(genClass.name)}.serializer, json.decode(jsonString));')))
        ..methods.add(new Method((b) => b
          ..name = 'fromJsonObject'
          ..static = true
          ..requiredParameters.add(new Parameter((b) => b
            ..name = 'jsonObject'
            ..type = new Reference('Object')))
          ..returns =
              new Reference("${_getPascalCaseClassName(genClass.name)}?")
          ..body = new Code(
              'return ${options.serializersVariableName}.deserializeWith(${_getPascalCaseClassName(genClass.name)}.serializer, jsonObject);'))));
    }
    String classString = topLevelClass.accept(new DartEmitter()).toString();

    String header = """
      ${_buildNestedImports(genClass.fields, options)}
      
      part '${new ReCase(genClass.name).snakeCase}.g.dart';
    
    """;

    String output = _dartfmt.format(header + classString);

//    print(output);
    return output;
  }

  static String _getPascalCaseClassName(String name) =>
      new ReCase(name).pascalCase;

  static String _buildNestedImports(
      List<GenField> fields, SerializationOptions? options) {
    String baseImports = """
      import 'dart:convert';
      import 'package:built_value/built_value.dart';
      import 'package:built_value/serializer.dart';
    """;
    baseImports += fields.any((GenField field) =>
            field.type.type == JsonType.LIST ||
            field.type.type == JsonType.LIST_N)
        ? """
      import 'package:built_collection/built_collection.dart';
    """
        : "";
    if (options != null) {
      baseImports += """ 
      import 'package:${options.serializersImport}';
    """;
    }
    List items = fields
        .where((GenField field) =>
            field.type.type == JsonType.MAP ||
            field.type.listType == JsonType.MAP ||
            field.type.type == JsonType.MAP_N ||
            field.type.listType == JsonType.MAP_N)
        .map((GenField field) => ReCase(field.type.name).snakeCase)
        .map((String name) => "import '$name.dart';")
        .toList();

    String generatedClasses =
        items.isNotEmpty ? items.reduce((s1, s2) => "$s1\n$s2") : "";

    return baseImports + generatedClasses;
  }

  static ListBuilder<Method> _buildMethods(List<GenField> fields) {
    return new ListBuilder(fields.map((GenField s) => new Method((b) => b
      ..name = new ReCase(s.fieldName).camelCase
      ..returns = _getDartType(s.type)
      ..annotations.add(new CodeExpression(
          new Code("BuiltValueField(wireName: '${s.fieldName}')")))
      ..type = MethodType.getter)));
  }

  static Reference _getDartType(GenType subtype) {
    JsonType type = subtype.type;
    switch (type) {
      case JsonType.INT:
        return new Reference('int');
      case JsonType.DOUBLE:
        return new Reference('double');
      case JsonType.BOOL:
        return new Reference('bool');
      case JsonType.STRING:
        return new Reference('String');
      case JsonType.MAP:
        return new Reference(new ReCase(subtype.name).pascalCase);
      case JsonType.LIST:
        return new Reference('BuiltList<${_getDartTypeFromJsonType(subtype)}>');
      case JsonType.INT_N:
        return new Reference('int?');
      case JsonType.DOUBLE_N:
        return new Reference('double?');
      case JsonType.BOOL_N:
        return new Reference('bool?');
      case JsonType.STRING_N:
        return new Reference('String?');
      case JsonType.MAP_N:
        return new Reference(new ReCase(subtype.name).pascalCase + '?');
      case JsonType.LIST_N:
        return new Reference(
            'BuiltList<${_getDartTypeFromJsonType(subtype)}>?');
      default:
        return new Reference('dynamic?');
    }
  }

  static String _getDartTypeFromJsonType(GenType subtype) {
    var type = subtype.listType;
    switch (type) {
      case JsonType.INT:
        return 'int';
      case JsonType.DOUBLE:
        return 'double';
      case JsonType.STRING:
        return 'String';
      case JsonType.MAP:
        return new ReCase(subtype.name).pascalCase;
      case JsonType.INT_N:
        return 'int?';
      case JsonType.DOUBLE_N:
        return 'double?';
      case JsonType.STRING_N:
        return 'String?';
      case JsonType.MAP_N:
        return new ReCase(subtype.name).pascalCase + '?';
      default:
        return 'dynamic?';
    }
  }
}
