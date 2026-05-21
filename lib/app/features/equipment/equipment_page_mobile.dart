import 'package:flutter/material.dart';
import 'package:soundimplosion/common/widgets/equipment_sheet_card.dart';

class EquipmentPageMobile extends StatelessWidget {
  const EquipmentPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [EquipmentSheetCard()],
    );
  }
}
