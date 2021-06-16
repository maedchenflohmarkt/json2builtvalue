import 'dart:html';

import 'package:json2builtvalue/parser.dart';

const String startingJson = """
{
    "id": 157538,
    "date": "2017-07-21T10:30:34",
    "date_gmt": "2017-07-21T17:30:34",
    "type": "post",
    "link": "https://example.com",
    "title": {
        "rendered": "Json 2 dart built_value converter"
    },
    "tags": [
        {
            "title": {
                "base": "Article",
                "translation": "Артыкул"
            },
            "id": 10
        }
    ]
}
""";

void mainweb() {
//  querySelector('#output').text = 'Your Dart app is running.';

  Element? outputText = querySelector('#output_text');
  Element? input = document.getElementById('input_text');
  input?.text = startingJson;

  querySelector('#convert')?.onClick.forEach((MouseEvent event) async {
    try {
      Element? rootClassNameElement =
          document.getElementById('root_class_name');
      String? rootClassName = (rootClassNameElement as TextInputElement).value;

      Element? elementById = document.getElementById('input_text');
      String? json = (elementById as TextAreaElement).value;
      print('json is $json');
      JsonParser parser = new JsonParser();
      String outputClasses =
          parser.parse(json!, rootClassName!.replaceAll(' ', ''), []);

      outputText?.text = outputClasses;
      // outputText.text = json;
    } catch (e) {
      outputText?.text = 'Error: ${e.toString()}';
    }
  });
}
