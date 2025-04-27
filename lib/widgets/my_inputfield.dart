import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PesoInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFilled;
  final VoidCallback? onEditingComplete;

  PesoInputField({
    required this.controller,
    required this.focusNode,
    this.isFilled = false,
    this.onEditingComplete,
  });

  String _formatToKg(String input) {
    String cleanedInput = input.replaceAll(RegExp(r'[^0-9]'), '');
    double valueInGrams = int.tryParse(cleanedInput)?.toDouble() ?? 0.0;
    double valueInKg = valueInGrams / 1000;
    return NumberFormat('0.000').format(valueInKg);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peso',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    String formatted = _formatToKg(newValue.text);
                    return TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  }),
                ],
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.balance),
                  suffix: Text(
                    'Kg',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  hintText: '0.000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onEditingComplete: onEditingComplete,
              ),
            ),
            if (isFilled)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class QuantidadeInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFilled;
  final VoidCallback? onEditingComplete;

  QuantidadeInputField({
    required this.controller,
    required this.focusNode,
    this.isFilled = false,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantidade',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.format_list_numbered),
                  hintText: '0',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onEditingComplete: onEditingComplete,
              ),
            ),
            if (isFilled)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
