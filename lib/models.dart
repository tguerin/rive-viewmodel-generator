enum InputType { number, boolean, enumValue }

class RiveInput {
  final String name;
  final InputType type;
  final List<String> enumValues;

  RiveInput({required this.name, required this.type, List<String>? enumValues}) : enumValues = enumValues ?? [];

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.toString().split('.').last,
    if (enumValues.isNotEmpty) 'values': enumValues,
  };

  factory RiveInput.fromJson(Map<String, dynamic> json) {
    return RiveInput(
      name: json['name'] as String,
      type: InputType.values.firstWhere((e) => e.toString().split('.').last == json['type']),
      enumValues: (json['values'] as List?)?.cast<String>() ?? [],
    );
  }
}

class RiveViewModel {
  final String name;
  final List<RiveInput> inputs;

  RiveViewModel({required this.name, required this.inputs});

  Map<String, dynamic> toJson() => {'name': name, 'inputs': inputs.map((i) => i.toJson()).toList()};

  factory RiveViewModel.fromJson(Map<String, dynamic> json) {
    return RiveViewModel(
      name: json['name'] as String,
      inputs: (json['inputs'] as List).map((i) => RiveInput.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
