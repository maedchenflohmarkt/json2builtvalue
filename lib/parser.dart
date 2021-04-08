import 'dart:convert';

import 'package:built_collection/src/list.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:json2builtvalue/root.dart';
import 'package:recase/recase.dart';

class Parser {
  final _dartfmt = new DartFormatter();
  final Set<String> classNamesRepo = Set();

  String parse(String jsonString, String topLevelName) {
    return parseToMap(jsonString, topLevelName)
        .values
        .reduce((s1, s2) => s1 + s2);
  }

  Map<String, String> parseToMap(String jsonString, String topLevelName) {
    classNamesRepo.clear();
    var decode = json.decode(jsonString);
    return _recurseParsing(topLevelName, decode);
  }

  Map<String, String> _recurseParsing(className, decode) {
    List<GenClass> allClasses = [];
    Map<String, String> result = {};

    List<GenField> fields = _getTypedClassFields(decode);
    fields = fields.map((f) {
      String realClassName = f.type.name;
      while (!classNamesRepo.add(realClassName)) {
        realClassName += "Of${ReCase(className).pascalCase}";
      }
      return GenField(f.type.copyWith(name: realClassName), f.fieldName);
    }).toList();

    allClasses.add(new GenClass(className, fields));
    fields.map((field) => field.type).forEach((GenType s) {
      if ((s.type == JsonType.LIST && s.listType == JsonType.MAP) ||
          s.type == JsonType.MAP) {
        result.addAll(_recurseParsing(s.name, s.value));
      }
    });

    result.addEntries(allClasses.map(
        (cl) => MapEntry(ReCase(cl.name).snakeCase, _generateStringClass(cl))));

    return result;
  }

  String _generateStringClass(GenClass genClass) {
    var topLevelClass = new Class((b) => b
      ..abstract = true
      ..constructors.add(new Constructor((b) => b..name = '_'))
      ..implements.add(new Reference(
          'Built<${_getPascalCaseClassName(genClass.name)}, ${_getPascalCaseClassName(genClass.name)}Builder>'))
      ..name = _getPascalCaseClassName(genClass.name)
      ..methods = _buildMethods(genClass.fields)
      ..methods.add(new Method((b) => b
        ..name = 'toJson'
        ..returns = new Reference('String')
        ..body = new Code(
            'return json.encode(serializers.serializeWith(${_getPascalCaseClassName(genClass.name)}.serializer, this));')))
      ..methods.add(new Method((b) => b
        ..name = 'fromJson'
        ..static = true
        ..requiredParameters.add(new Parameter((b) => b
          ..name = 'jsonString'
          ..type = new Reference('String')))
        ..returns = new Reference(_getPascalCaseClassName(genClass.name))
        ..body = new Code(
            'return serializers.deserializeWith(${_getPascalCaseClassName(genClass.name)}.serializer, json.decode(jsonString));')))
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

    String classString = topLevelClass.accept(new DartEmitter()).toString();

    String header = """
      library ${new ReCase(genClass.name).snakeCase};
      import 'dart:convert';
      
      import 'package:built_collection/built_collection.dart';
      import 'package:built_value/built_value.dart';
      import 'package:built_value/serializer.dart';
      
      part '${new ReCase(genClass.name).snakeCase}.g.dart';
    
    """;

    String output = _dartfmt.format(header + classString);

//    print(output);
    return output;
  }

  String _getPascalCaseClassName(String name) => new ReCase(name).pascalCase;

  ListBuilder<Method> _buildMethods(List<GenField> topLevel) {
    return new ListBuilder(topLevel.map((GenField s) => new Method((b) => b
      ..name = new ReCase(s.fieldName).camelCase
      ..returns = _getDartType(s.type)
      ..annotations.add(new CodeExpression(
          new Code("BuiltValueField(wireName: '${s.fieldName}')")))
      ..type = MethodType.getter)));
  }

  Reference _getDartType(GenType subtype) {
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
      default:
        return new Reference('dynamic');
    }
  }

  String _getDartTypeFromJsonType(GenType subtype) {
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
      default:
        return 'dynamic';
    }
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
