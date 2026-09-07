import 'package:flutter_test/flutter_test.dart';
import 'package:duka_manager/services/printer_service.dart';

void main() {
  test('EscPosBuilder generates correct ESC/POS byte sequence', () {
    final builder = EscPosBuilder();
    builder.reset();
    builder.text("TEST SHOP", bold: true, align: 1, size: 2);
    builder.leftRight("1x Milk", "KES 100", bold: false);
    builder.newLine();
    builder.paperCut();

    final bytes = builder.bytes;
    expect(bytes.isNotEmpty, true);
    expect(bytes[0], 0x1B); // ESC
    expect(bytes[1], 0x40); // @
  });
}
