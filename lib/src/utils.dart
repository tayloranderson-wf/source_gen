// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library source_gen.utils;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/package_map_provider.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/source/pub_package_map_provider.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk_io.dart' show DirectoryBasedDartSdk;
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/source_io.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:cli_util/cli_util.dart' as cli;
import 'package:path/path.dart' as p;

String findPartOf(String source) {
  try {
    var unit = parseCompilationUnit(source);

    var partOf = unit.directives
        .firstWhere((d) => d is PartOfDirective, orElse: () => null);

    if (partOf == null) {
      return null;
    }

    var offset = partOf.offset;

    return source.substring(offset);
  } on AnalyzerErrorGroup {
    return null;
  }
}

String friendlyNameForElement(Element element) {
  var friendlyName = element.displayName;

  if (friendlyName == null) {
    throw new ArgumentError(
        'Cannot get friendly name for $element - ${element.runtimeType}.');
  }

  var names = <String>[friendlyName];
  if (element is ClassElement) {
    names.insert(0, 'class');
    if (element.isAbstract) {
      names.insert(0, 'abstract');
    }
  }
  if (element is VariableElement) {
    names.insert(0, element.type.toString());

    if (element.isConst) {
      names.insert(0, 'const');
    }

    if (element.isFinal) {
      names.insert(0, 'final');
    }
  }
  if (element is LibraryElement) {
    names.insert(0, 'library');
  }

  return names.join(' ');
}

/// [foundFiles] is the list of files to consider for the context.
Future<AnalysisContext> getAnalysisContextForProjectPath(
    String projectPath, List<String> foundFiles) async {
  // TODO: fail more clearly if this...fails
  var sdkPath = cli.getSdkDir().path;

  JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
  DartSdk sdk = DirectoryBasedDartSdk.defaultSdk;

  var packageResolver = _getPackageResolver(projectPath);

  var resolvers = [
    new DartUriResolver(sdk),
    new ResourceUriResolver(PhysicalResourceProvider.INSTANCE),
    packageResolver
  ];

  // TODO: Remove this once dartbug.com/23017 is fixed
  // See source_gen bug https://github.com/dart-lang/source_gen/issues/46
  var options = new AnalysisOptionsImpl()
    ..cacheSize = 256
    ..analyzeFunctionBodies = false;

  var context = AnalysisEngine.instance.createAnalysisContext()
    ..analysisOptions = options
    ..sourceFactory = new SourceFactory(resolvers);

  // ensures all libraries defined by the set of files are resolved
  _getLibraryElements(foundFiles, context).toList();

  return context;
}

UriResolver _getPackageResolver(String projectPath) {
  // is there a .packages file? If yes, use that!

  var dotPackagesPath = p.join(projectPath, '.packages');

  if (FileSystemEntity.isFileSync(dotPackagesPath)) {
    PubPackageMapProvider pubPackageMapProvider = new PubPackageMapProvider(
        PhysicalResourceProvider.INSTANCE, DirectoryBasedDartSdk.defaultSdk);
    PackageMapInfo packageMapInfo = pubPackageMapProvider
        .computePackageMap(PhysicalResourceProvider.INSTANCE.getResource('.'));
    Map<String, List<Folder>> packageMap = packageMapInfo.packageMap;
    if (packageMap != null) {
      return new PackageMapUriResolver(
          PhysicalResourceProvider.INSTANCE, packageMap);
    }
  }

  var packagesPath = p.join(projectPath, 'packages');

  var packageDirectory = new JavaFile(packagesPath);

  return new PackageUriResolver([packageDirectory]);
}

/// Returns all of the declarations in [unit], including [unit] as the first
/// item.
Iterable<Element> getElementsFromLibraryElement(LibraryElement unit) sync* {
  yield unit;
  for (var cu in unit.units) {
    for (var compUnitMember in cu.unit.declarations) {
      yield* _getElements(compUnitMember);
    }
  }
}

Set<LibraryElement> getLibraries(
    AnalysisContext context, Iterable<String> filePaths) {
  return filePaths.fold(new Set<LibraryElement>(), (set, path) {
    var elementLibrary = getLibraryElementForSourceFile(context, path);

    if (elementLibrary != null) {
      set.add(elementLibrary);
    }

    return set;
  });
}

LibraryElement getLibraryElementForSourceFile(
    AnalysisContext context, String sourcePath) {
  Source source = new FileBasedSource(new JavaFile(sourcePath));

  var libs = context.getLibrariesContaining(source);

  if (libs.length > 1) {
    throw "We don't support multiple libraries for a source.";
  }

  if (libs.isEmpty) {
    return null;
  }

  var libSource = libs.single;

  return context.getLibraryElement(libSource);
}

Iterable<Element> _getElements(CompilationUnitMember member) {
  if (member is TopLevelVariableDeclaration) {
    return member.variables.variables.map((v) => v.element);
  }
  var element = member.element;

  if (element == null) {
    print([member, member.runtimeType, member.element]);
    throw new Exception('Could not find any elements for the provided unit.');
  }

  return [element];
}

LibraryElement _getLibraryElement(String path, AnalysisContext context) {
  Source source = new FileBasedSource(new JavaFile(path));
  if (context.computeKindOf(source) == SourceKind.LIBRARY) {
    return context.computeLibraryElement(source);
  }
  return null;
}

String getFileBasedSourcePath(FileBasedSource source) {
  return p.fromUri(source.uri);
}

// may return `null` if [path] doesn't refer to a library.
/// [dartFiles] is a [Stream] of paths to [.dart] files.
Iterable<LibraryElement> _getLibraryElements(
        List<String> dartFiles, AnalysisContext context) =>
    dartFiles
        .map((path) => _getLibraryElement(path, context))
        .where((lib) => lib != null);
