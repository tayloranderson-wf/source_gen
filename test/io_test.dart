// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('!browser')
library source_gen.test.io_test;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_test.dart';
import 'package:source_gen/src/io.dart';

import 'test_utils.dart';

void main() {
  test('expandFileListToIncludePeers', () {
    var examplePath = p.join(getPackagePath(), 'example');
    var jsonPath = p.join(examplePath, 'data.json');

    var things = expandFileListToIncludePeers([jsonPath])
        .map((path) => p.relative(path, from: examplePath))
        .toList();

    expect(things,
        unorderedEquals(['data.json', 'example.dart', 'example.g.dart']));
  });

  test('find files', () async {
    var testFilesPath = p.join(getPackagePath(), 'test', 'test_files');

    var files = await getDartFiles(testFilesPath);
    expect(files, hasLength(6));
  });

  test('search with one sub directory', () async {
    var testFilesPath = p.join(getPackagePath(), 'test');

    var files = await getDartFiles(testFilesPath, searchList: ['test_files']);

    expect(files, hasLength(6));
  });

  test('search with one sub directory and one file', () async {
    var testFilesPath = p.join(getPackagePath(), 'test');

    var files = await getDartFiles(testFilesPath,
        searchList: ['test_files', 'io_test.dart']);

    expect(files, hasLength(7));
  });

  test('search with one file', () async {
    var testFilesPath = p.join(getPackagePath(), 'test');

    var files = await getDartFiles(testFilesPath, searchList: ['io_test.dart']);

    expect(files, hasLength(1));
  });

  test('search with none existent file', () async {
    var testFilesPath = p.join(getPackagePath(), 'test');

    var files =
        await getDartFiles(testFilesPath, searchList: ['no_file_here.dart']);

    expect(files, hasLength(0));
  });

  group('redundant items fail', () {
    test('dir then contained file', () async {
      var testFilesPath = p.join(getPackagePath());

      var caught = false;
      return getDartFiles(testFilesPath,
          searchList: ['test', 'test/io_test.dart']).catchError((error) {
        expect(error, isArgumentError);
        caught = true;
      }).whenComplete(() {
        expect(caught, isTrue);
      });
    });

    test('dir then contained dir', () async {
      var testFilesPath = p.join(getPackagePath());

      var caught = false;
      return getDartFiles(testFilesPath,
          searchList: ['test', 'test/test_files']).catchError((error) {
        expect(error, isArgumentError);
        caught = true;
      }).whenComplete(() {
        expect(caught, isTrue);
      });
    });

    test('file then containing dir', () async {
      var testFilesPath = p.join(getPackagePath());

      var caught = false;
      return getDartFiles(testFilesPath,
          searchList: ['test/io_test.dart', 'test']).catchError((error) {
        expect(error, isArgumentError);
        caught = true;
      }).whenComplete(() {
        expect(caught, isTrue);
      });
    });

    test('dir then containing dir', () async {
      var testFilesPath = p.join(getPackagePath());

      var caught = false;
      return getDartFiles(testFilesPath,
          searchList: ['test/test_files', 'test']).catchError((error) {
        expect(error, isArgumentError);
        caught = true;
      }).whenComplete(() {
        expect(caught, isTrue);
      });
    });
  });

  group('symbolic links', () {
    setUp(() {
      schedule(() async {
        await _doSetup();

        await d.dir('root', [
          d.file('file.dart', '// cool!'),
          d.dir('sub', [d.file('subfile.dart')])
        ]).create();

        await d.dir('link_content', [d.file('link_content.dart')]).create();

        // create the link!
        var link = new Link(p.join(d.defaultRoot, 'root', 'link'));
        await link.create(p.join(d.defaultRoot, 'link_content'));
      });
    });

    test("are not traversed by default", () {
      schedule(() async {
        var root = p.join(d.defaultRoot, 'root');
        var files = await getDartFiles(root);

        files = files.map((path) => p.relative(path, from: root)).toList();

        expect(files,
            unorderedEquals(['file.dart', p.join('sub', 'subfile.dart')]));
      });
    });

    test("are traversed when requested", () {
      schedule(() async {
        var root = p.join(d.defaultRoot, 'root');
        var files = await getDartFiles(root, followLinks: true);

        files = files.map((path) => p.relative(path, from: root)).toList();

        expect(
            files,
            unorderedEquals([
              'file.dart',
              p.join('sub', 'subfile.dart'),
              p.join('link', 'link_content.dart')
            ]));
      });
    });
  });
}

Future _doSetup() async {
  var dir = await createTempDir();
  d.defaultRoot = dir.path;
}
