import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  Future<void> generateSalesReport(
    List<Map<String, dynamic>> salesData, 
    double totalRevenue, 
    double totalProfit, 
    String period
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // 1. Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Sales Report", style: pw.TextStyle(font: fontBold, fontSize: 24, color: PdfColors.orange800)),
                      pw.Text("Period: $period", style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("M-Bizna Shop", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                      pw.Text("Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  )
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),

            // 2. Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPdfSummaryCard("Total Revenue", "KES ${totalRevenue.toStringAsFixed(0)}", PdfColors.blue50, PdfColors.blue800, fontBold),
                _buildPdfSummaryCard("Total Profit", "KES ${totalProfit.toStringAsFixed(0)}", PdfColors.green50, PdfColors.green800, fontBold),
                _buildPdfSummaryCard("Transactions", "${salesData.length}", PdfColors.grey100, PdfColors.black, fontBold),
              ]
            ),

            pw.SizedBox(height: 30),

            // 3. Transactions Table
            pw.Table.fromTextArray(
              context: context,
              border: null,
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.orange800),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: ['Date', 'Item', 'Qty', 'Amount'],
              data: salesData.map((tx) {
                return [
                  DateFormat('MM-dd HH:mm').format(DateTime.parse(tx['date_time'])),
                  tx['name'],
                  tx['quantity'].toString(),
                  tx['total_price'].toStringAsFixed(0),
                ];
              }).toList(),
            ),
            
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("End of Report", style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    // This opens the native Print/Share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sales_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryCard(String title, String value, PdfColor bg, PdfColor text, pw.Font font) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 16, color: text)),
        ],
      ),
    );
  }
}