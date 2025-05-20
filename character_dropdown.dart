import 'package:flutter/material.dart';

// Define a list of all available characters
const List<String> allCharacters = <String>['Dragon', 'Wizard', 'Alien', 'Robot', 'Detective', 'Knight', 'Goblin', 'Orc', 'Space Pirate', 'Robot Companion'];

class CharacterDropdown extends StatelessWidget {
  // Properties that the widget needs from its parent
  final String hintText;
  final String? selectedValue;
  final ValueChanged<String?>? onChanged; // Callback when the value changes

  // Constructor to receive the properties
  const CharacterDropdown({
    super.key, // Boilerplate key for widgets
    required this.hintText, // Hint text for this specific dropdown
    required this.selectedValue, // The currently selected value for this dropdown
    required this.onChanged, // The function to call when a new value is selected
  }); // Call the parent constructor

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      hint: Text(hintText),
      value: selectedValue, // Use the value passed in
      items: allCharacters.map((String value) { // Use the common list
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged, // Use the onChanged callback passed in
    );
  }
}