// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library source_gen.build_file;

import 'package:source_gen/generators/json_literal_generator.dart' as literal;
import 'package:source_gen/generators/json_serializable_generator.dart' as json;
import 'package:source_gen/source_gen.dart';

main(List<String> args) async {
  var msg = await build(args, const [
    const json.JsonSerializableGenerator(),
    const literal.JsonLiteralGenerator()
  ], librarySearchPaths: [
    'example',
    'test/test_files/json_test_example.dart'
  ]);
  print(msg);
}
