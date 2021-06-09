class GenType {
  final String name;
  final JsonType type;
  final JsonType? listType;
  final dynamic value;

  GenType(this.name, this.type, this.value, {this.listType});

  GenType copyWith(String name, {JsonType? type, value, JsonType? listType}) {
    return GenType(name, type ?? this.type, value ?? this.value,
        listType: listType ?? this.listType);
  }

  @override
  String toString() {
    return 'Subtype{name: $name, type: $type, listType: $listType, value: $value}';
  }
}

class GenField {
  final GenType type;
  final String fieldName;

  GenField(this.type, this.fieldName);

  @override
  String toString() {
    return 'Field{fieldName: $fieldName, type: $type}';
  }
}

class GenClass {
  final String name;
  final List<GenField> fields;

  GenClass(this.name, this.fields);

  @override
  String toString() {
    return 'Field{fieldName: $name, type: $fields}';
  }
}

enum JsonType { INT, DOUBLE, BOOL, STRING, MAP, LIST }

class SerializationOptions {
  final String serializersImport;
  final String serializersVariableName;

  SerializationOptions(
      {required this.serializersImport, required this.serializersVariableName});
}
