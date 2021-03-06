[![Build Status](https://travis-ci.org/dart-lang/source_gen.svg?branch=master)](https://travis-ci.org/dart-lang/source_gen)
[![Coverage Status](https://coveralls.io/repos/dart-lang/source_gen/badge.svg?branch=master)](https://coveralls.io/r/dart-lang/source_gen)
[![Stories in Ready](https://badge.waffle.io/dart-lang/source_gen.png?label=ready&title=Ready)](https://waffle.io/dart-lang/source_gen)

_**Highly experimental. Expect breaking changes.**_

`source_gen` provides:

* A **tool** for generating code that is part of your Dart project.
* A **framework** for creating and using multiple code generators in a single
  project.
* A **convention** for human and tool generated Dart code to coexist with clean
  separation.

## Example

Given a library `example.dart`:

```dart
library source_gen.example.example;

import 'package:source_gen/generators/json_serializable.dart';

part 'example.g.dart';

@JsonSerializable()
class Person extends Object with _$PersonSerializerMixin {
  final String firstName, middleName, lastName;
  final DateTime dateOfBirth;

  Person(this.firstName, this.lastName, {this.middleName, this.dateOfBirth});

  factory Person.fromJson(json) => _$PersonFromJson(json);
}
```

`source_gen` creates the corresponding part `example.g.dart`:

```dart
part of source_gen.example.example;

// **************************************************************************
// Generator: JsonGenerator
// Target: class Person
// **************************************************************************

Person _$PersonFromJson(Map<String, Object> json) => new Person(
    json['firstName'], json['lastName'],
    middleName: json['middleName'],
    dateOfBirth: json.containsKey('dateOfBirth')
        ? DateTime.parse(json['dateOfBirth'])
        : null);

abstract class _$PersonSerializerMixin {
  String get firstName;
  String get middleName;
  String get lastName;
  DateTime get dateOfBirth;
  Map<String, Object> toJson() => {
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'dateOfBirth': dateOfBirth == null ? null : dateOfBirth.toIso8601String()
  };
}
```

See the [example code][] in the `source_gen` GitHub repo.

## Creating a generator

Extend the `Generator` class to plug into `source_gen`.

* [Trivial example][]
* [Included generators][]

## Running generators

Create a script that invokes the [generate][] method.

Alternatively, you can create a `build.dart` file which calls the [build]
method. You can use the [build_system package][] to enjoy this automatic workflow.

*Note: The original design was meant to work with the
[Dart Editor build system][]. Dart Editor is unsupported as of Dart 1.11.*

See [build.dart][] in the repository for an example.

## source_gen vs Dart Transformers
[Dart Transformers][] are often used to create and modify code and assets as part
of a Dart project.

Transformers allow modification of existing code and encapsulates changes by
having developers use `pub` commands – `run`, `serve`, and `build`.

`source_gen` provides a different model. Code is generated and updated
as part of a project. It is designed to create *part* files that augment
developer maintained Dart libraries.

Generated code **MAY** be checked in as part of our project source,
although the decision may vary depending on project needs.

Generated code **SHOULD** be included when publishing a project as a *pub
package*. The fact that `source_gen` is used in a package is an *implementation
detail*.

[Dart Transformers]: https://www.dartlang.org/tools/pub/assets-and-transformers.html
[example code]: https://github.com/dart-lang/source_gen/tree/master/example
[Trivial example]: https://github.com/dart-lang/source_gen/blob/master/test/src/comment_generator.dart
[Included generators]: https://github.com/dart-lang/source_gen/tree/master/lib/generators
[build.dart]: https://github.com/dart-lang/source_gen/blob/master/build.dart
[generate]: http://www.dartdocs.org/documentation/source_gen/latest/index.html#source_gen/source_gen@id_generate
[build]: http://www.dartdocs.org/documentation/source_gen/latest/index.html#source_gen/source_gen@id_build
[Dart Editor build system]: https://www.dartlang.org/tools/editor/build.html
[build_system package]: https://pub.dartlang.org/packages/build_system
