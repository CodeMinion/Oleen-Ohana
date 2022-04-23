import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:another_brother/label_info.dart';
import 'package:another_brother/printer_info.dart' as abPi;
import 'package:another_quickbase/another_quickbase.dart';
import 'package:another_quickbase/another_quickbase_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_platform/universal_platform.dart';
import 'app_keys.dart';
import 'dart:ui' as ui;

const double kLabelWidth = 90.3;
const double kLabelHeight = 29;
TextStyle kLabelTextStyle = GoogleFonts.vibur();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  final bool isDark = false;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      //debugShowCheckedModeBanner: false,
      title: 'Oleen Ohana',
      theme: toThemeData(),
      /*ThemeData(
        primarySwatch: Colors.cyan,
      )*/
      home: const MyHomePage(title: 'Oleen Ohana'),
    );
  }

  ThemeData toThemeData() {
    var accent1 = const Color(0xFFfaac64);
    var bg1 = const Color(0xFFa3dec9);
    var surface1 = const Color(0xFFfaac64); //Colors.white;
    var mainTextColor = isDark ? Colors.white : Colors.black;
    var greyStrong = const Color(0xFF131A22);
    var inverseTextColor = !isDark ? Colors.black : Colors.white;
    //var focus = const Color(0xFF4ac3be);
    var grey = const Color(0xff999999);
    var textTheme = (!isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    ColorScheme scheme = ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent1,
        secondary: accent1,
        background: bg1,
        surface: surface1,
        onBackground: mainTextColor,
        onSurface: mainTextColor,
        onError: mainTextColor,
        onPrimary: greyStrong,
        onSecondary: inverseTextColor,
        error: Colors.black);

    var t = ThemeData.from(
        // Use the .dark() and .light() constructors to handle the text themes
        textTheme: _buildTextTheme(textTheme),
        // Use ColorScheme to generate the bulk of the color theme
        colorScheme: scheme);

    t = t.copyWith(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        primaryIconTheme: const IconThemeData(
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
            isDense: true,
            filled: true,
            fillColor: surface1,
            labelStyle: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black.withAlpha(200),
            ),
            focusedErrorBorder:
                OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            errorBorder:
                OutlineInputBorder(borderSide: BorderSide(color: accent1)),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: greyStrong))),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: grey,
          selectionHandleColor: Colors.transparent,
          selectionColor: grey,
        ),
        snackBarTheme: t.snackBarTheme.copyWith(
            backgroundColor: accent1,
            actionTextColor: mainTextColor,
            contentTextStyle:
                t.textTheme.caption!.copyWith(color: mainTextColor)),
        scaffoldBackgroundColor: bg1,
        highlightColor: shift(accent1, .1),
        toggleableActiveColor: accent1,
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(side: BorderSide(color: accent1))));
    // All done, return the ThemeData
    return t;
  }

  /// This will add luminance in dark mode, and remove it in light.
  // Allows the view to just make something "stronger" or "weaker" without worrying what the current theme brightness is
  //      color = theme.shift(someColor, .1); //-10% lum in dark mode, +10% in light mode
  Color shift(Color c, double amt) {
    amt *= (isDark ? -1 : 1);
    var hslc = HSLColor.fromColor(c); // Convert to HSL
    double lightness =
        (hslc.lightness + amt).clamp(0, 1.0) as double; // Add/Remove lightness
    return hslc.withLightness(lightness).toColor(); // Convert back to Color
  }

  TextTheme _buildTextTheme(TextTheme base) {
    return base
        .copyWith(
          bodyText2: GoogleFonts.robotoCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            //letterSpacing: letterSpacingOrNone(0.5),
          ),
          bodyText1: GoogleFonts.eczar(
            fontSize: 40,
            fontWeight: FontWeight.w400,
            //letterSpacing: letterSpacingOrNone(1.4),
          ),
          button: GoogleFonts.robotoCondensed(
            fontWeight: FontWeight.w700,
            //letterSpacing: letterSpacingOrNone(2.8),
          ),
          headline5: GoogleFonts.eczar(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            //letterSpacing: letterSpacingOrNone(1.4),
          ),
        )
        .apply(
          displayColor: Colors.black,
          bodyColor: Colors.black,
        );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with OleenLogo {
  final PagingController<int, CustomerAddress> _pagingController =
      PagingController(firstPageKey: 0);
  final List<CustomerAddress> _selectedCustomers = List.empty(growable: true);
  final int _recordsPerPage = 10;

  final _formKey = GlobalKey<FormState>();
  static const String _kDefaultState = 'HI';
  CustomerAddress? _activeCustomer;

  QuickBaseClient client = QuickBaseClient(
      qBRealmHostname: AppKeys.quickbaseRealm,
      appToken: AppKeys.quickbaseAppToken);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems =
          await _fetchContacts(page: pageKey, pageSize: _recordsPerPage);
      final isLastPage = newItems.length < _recordsPerPage;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: OleenAppBar(
          title: widget.title,
        ),
        body: Center(
            child: _buildLargeContactsView(
                context) //_buildSmallContactsView(context),
            ),
        floatingActionButton: AnimatedSwitcher(
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            duration: const Duration(milliseconds: 600),
            child: _selectedCustomers.isNotEmpty
                ? FloatingActionButton(
                    key: const ObjectKey("print"),
                    onPressed: () {
                      // Print a label for every selected customer.
                      _printLabels(customersToPrint: _selectedCustomers);
                    },
                    tooltip: 'Print',
                    child: const Icon(Icons.print))
                : FloatingActionButton(
                    key: const ObjectKey("add"),
                    onPressed: () {
                      // Open dialog to enter new customer.
                      _showCustomerEntryDialog();
                    },
                    tooltip: 'Add Customer',
                    child: const Icon(Icons
                        .person_add)) // This trailing comma makes auto-formatting nicer for build methods.
            ));
  }

  ///
  /// Fetches a page of contacts from the contacts table.
  ///
  Future<List<CustomerAddress>> _fetchContacts(
      {required int page, required int pageSize}) async {
    await client.initialize();

    var contactTable = await client.getTable(
        tableId: AppKeys.quickbaseContactTableId,
        appId: AppKeys.quickbaseAppId);

    RecordsQueryResponse contacts = await client.runQuery(
        request: RecordsQueryRequest(
            select: [3, 6, 7, 9, 11, 12],
            from: contactTable.id!,
            options: RecordsQueryOptions(skip: page, top: pageSize)));

    List<CustomerAddress> customers = contacts.data?.map((item) {
          return CustomerAddress(
              recordId: item["3"]["value"],
              firstName: "${item["6"]["value"]}",
              lastName: "${item["7"]["value"]}",
              streetLine: "${item["9"]["value"]}",
              city: "${item["11"]["value"]}",
              state: "${item["12"]["value"]}");
        }).toList() ??
        List<CustomerAddress>.empty();

    return customers;
  }

  ///
  /// Adds the specified contact to the contacts table.
  ///
  Future<void> _addContact({required CustomerAddress customer}) async {
    var data = [
      {
        "6": {"value": customer.firstName},
        "7": {"value": customer.lastName},
        "9": {"value": customer.streetLine},
        "11": {"value": customer.city},
        "12": {"value": customer.state},
      }
    ];

    RecordsUpsertResponse response = await client.upsert(
        request: RecordsUpsertRequest(
            to: AppKeys.quickbaseContactTableId,
            data: data,
            fieldsToReturn: [3, 6, 7, 9, 11, 12]));
    setState(() {
      customer.recordId = response.data?.single["3"]["value"];
      _pagingController.itemList?.add(customer);
    });
  }

  ///
  /// Deletes the specified record from the contacts table.
  ///
  Future<void> _deleteContact({required CustomerAddress customer}) async {
    bool? delete = await _showBaseConfirmationDialogDialog(
      body: RichText(
        text: TextSpan(
          text: 'Delete customer  ',
          style: Theme.of(context).textTheme.bodyText2,
          children: <TextSpan>[
            TextSpan(
                text: "${customer.firstName} ${customer.lastName} ",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: "?"),
          ],
        ),
      ),
      positive: "Delete",
    );

    if (delete != true) {
      return;
    }

    var queryBuffer = StringBuffer();
    queryBuffer.write("{'3'.EX.'${customer.recordId}'}");
    /*
    queryBuffer.write("AND");
    queryBuffer.write("{'6'.EX.'${customer.firstName}'}");
    queryBuffer.write("AND");
    queryBuffer.write("{'7'.EX.'${customer.lastName}'}");
    queryBuffer.write("AND");
    queryBuffer.write("{'9'.EX.'${customer.streetLine}'}");
    queryBuffer.write("AND");
    queryBuffer.write("{'11'.EX.'${customer.city}'}");
    queryBuffer.write("AND");
    queryBuffer.write("{'12'.EX.'${customer.state}'}");
    */
    String where = queryBuffer.toString();

    int deletedCount = await client.deleteRecords(
        request: RecordsDeleteRequest(
            from: AppKeys.quickbaseContactTableId, where: where));

    if (deletedCount > 0) {
      setState(() {
        _pagingController.itemList?.remove(customer);
        _selectedCustomers.remove(customer);
      });
    }
  }

  ///
  /// Updates the given record on the contacts table.
  ///
  Future<void> _updateContact({required CustomerAddress customer}) async {
    var data = [
      {
        "3": {"value": "${customer.recordId}"},
        "6": {"value": customer.firstName},
        "7": {"value": customer.lastName},
        "9": {"value": customer.streetLine},
        "11": {"value": customer.city},
        "12": {"value": customer.state},
      }
    ];

    RecordsUpsertResponse response = await client.upsert(
        request: RecordsUpsertRequest(
            to: AppKeys.quickbaseContactTableId,
            data: data,
            fieldsToReturn: [6, 7, 9, 11, 12]));

    setState(() {});
  }

  Future<ui.Image> _generateContactLabel(
      {required CustomerAddress customer}) async {
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);

    double baseSize = 500;
    double labelWidthPx = baseSize;
    double labelHeightPx = baseSize * kLabelHeight / kLabelWidth;
    //double qrSizePx = labelHeightPx / 2;

    double titleFontSize = 50;
    double sublinesFontSize = 35;
    // Create Paragraph
    ui.ParagraphBuilder paraBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center));

    var labelFontStyle = kLabelTextStyle;
    // Add heading to paragraph
    paraBuilder.pushStyle(ui.TextStyle(
        fontFamily: labelFontStyle.fontFamily,
        fontSize: titleFontSize,
        color: Colors.black,
        fontWeight: FontWeight.bold));
    paraBuilder.addText("${customer.nameLine}");
    paraBuilder.pop();

    paraBuilder.pushStyle(ui.TextStyle(
        fontFamily: labelFontStyle.fontFamily,
        fontSize: sublinesFontSize,
        color: Colors.black,
        fontWeight: FontWeight.bold));
    paraBuilder.addText("\n${customer.streetLine}");
    paraBuilder.pop();

    paraBuilder.pushStyle(ui.TextStyle(
        fontFamily: labelFontStyle.fontFamily,
        fontSize: sublinesFontSize,
        color: Colors.black,
        fontWeight: FontWeight.bold));
    paraBuilder.addText("\n${customer.stateLine}");
    paraBuilder.pop();

    ui.Paragraph infoPara = paraBuilder.build();
    // Layout the pargraph in the remaining space.
    infoPara.layout(ui.ParagraphConstraints(width: labelWidthPx));

    Paint paint = Paint();
    paint.color = const Color.fromRGBO(255, 255, 255, 1);
    Rect bounds = Rect.fromLTWH(0, 0, labelWidthPx, labelHeightPx);
    canvas.save();
    canvas.drawRect(bounds, paint);

    // Draw paragraph on canvas.
    Offset paraOffset = Offset(0, (labelHeightPx - infoPara.height) / 2.0);
    canvas.drawParagraph(infoPara, paraOffset);

    var picture = await recorder
        .endRecording()
        .toImage(labelWidthPx.toInt(), labelHeightPx.toInt());

    return picture;
  }

  Widget _buildLargeContactsView(BuildContext context) {
    return PagedGridView(
        padding: const EdgeInsets.only(left: 16, right: 16),
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<CustomerAddress>(
          itemBuilder: (context, item, index) =>
              _createContactCard(index: index, customer: item),
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: 300 * kLabelHeight / kLabelWidth,
            maxCrossAxisExtent: 300,
            childAspectRatio: kLabelWidth / kLabelHeight));
  }

  Widget _buildSmallContactsView(BuildContext context) {
    return PagedListView<int, CustomerAddress>(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<CustomerAddress>(
        itemBuilder: (context, item, index) =>
            _createContactCard(index: index, customer: item),
      ),
    );
  }

  Widget _createContactCard(
      {required int index, required CustomerAddress customer}) {
    return ContactRowView(
      customer: customer,
      onLongPress: () {
        // Open update dialog
        _showUpdateCustomerDialog(customerToEdit: customer);
      },
      onDeleteTap: () {
        // TODO Consider opening a dialog.
        _deleteContact(customer: customer);
      },
      onTap: () {
        setState(() {
          customer.isSelected = !customer.isSelected;
          if (customer.isSelected) {
            _selectedCustomers.add(customer);
          } else {
            _selectedCustomers.remove(customer);
          }
        });
      },
    );
  }

  Widget _createCustomerForm(
      {required BuildContext context,
      bool isUpdate = false,
      required StateSetter setState}) {
    ThemeData mainTheme = Theme.of(context);
    return Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: _activeCustomer?.firstName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "First Name"),
              // The validator receives the text that the user has entered.
              validator: (value) {
                if (!isValidEntry(value)) {
                  return 'Please enter a valid name';
                }
                _activeCustomer?.firstName = value;
                return null;
              },
            ),
            const SizedBox(
              height: 8,
            ),
            TextFormField(
              initialValue: _activeCustomer?.lastName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Last Name"),
              // The validator receives the text that the user has entered.
              validator: (value) {
                if (!isValidEntry(value)) {
                  return 'Please enter a valid last name';
                }
                _activeCustomer?.lastName = value;
                return null;
              },
            ),
            const SizedBox(
              height: 8,
            ),
            TextFormField(
              initialValue: _activeCustomer?.streetLine,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "Street"),
              // The validator receives the text that the user has entered.
              validator: (value) {
                if (!isValidEntry(value)) {
                  return 'Please enter a valid street';
                }
                _activeCustomer?.streetLine = value;
                return null;
              },
            ),
            const SizedBox(
              height: 8,
            ),
            Theme(
              data: mainTheme.copyWith(
                  canvasColor: mainTheme.colorScheme.secondary),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: _activeCustomer?.state?.toUpperCase(),
                icon: const Icon(Icons.arrow_downward),
                elevation: 16,
                style: TextStyle(color: mainTheme.colorScheme.onSecondary),
                onChanged: (String? newValue) {
                  setState(() {
                    _activeCustomer?.state = newValue!;
                  });
                },
                items: <String>[
                  'AL',
                  'AK',
                  'AZ',
                  'AR',
                  'AS',
                  'CA',
                  'CO',
                  'CT',
                  'DE',
                  'DC',
                  'FL',
                  'GA',
                  'GU',
                  'HI',
                  'ID',
                  'IL',
                  'IN',
                  'IA',
                  'KS',
                  'OH',
                  'OK',
                  'OR',
                  'PA',
                  'PR',
                  'RI',
                  'SC',
                  'SD',
                  'TN',
                  'TX',
                  'TT',
                  'UT',
                  'VT',
                  'VA',
                  'VI',
                  'WA',
                  'WV',
                  'WI',
                  'WY'
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            TextFormField(
              initialValue: _activeCustomer?.city,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: "City"),
              // The validator receives the text that the user has entered.
              validator: (value) {
                if (!isValidEntry(value)) {
                  return 'Please enter a valid city';
                }
                _activeCustomer?.city = value;
                return null;
              },
            ),
            const SizedBox(
              height: 8,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48), // NEW
                ),
                onPressed: () {
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, _activeCustomer);
                  }
                },
                child: isUpdate
                    ? const Text('Update')
                    : const Text("Add Customer"),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ));
  }

  Widget _buildBaseDialogBody({required Widget child}) {
    return Dialog(
        backgroundColor: Colors.transparent,
        child: StatefulBuilder(builder: (context, StateSetter setState) {
          ThemeData theme = Theme.of(context);
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 50.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: theme.colorScheme.background,
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 16.0, top: 60),
                    child: SizedBox(
                            width: 400,
                            child: SingleChildScrollView(child: child)
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                child: Center(
                  child: buildAppLogo(width: 100, height: 100),
                ),
              ),
            ],
          );
        }));
  }

  Future<CustomerAddress?> _showBaseCustomerDialog({bool isUpdate = false}) {
    return showGeneralDialog<CustomerAddress?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Barrier",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Container();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeInOutBack.transform(anim1.value) - 1.0;
        return Transform(
            transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
            child: Opacity(
              opacity: anim1.value,
              child: _buildBaseDialogBody(
                  child: _createCustomerForm(
                      context: context,
                      setState: setState,
                      isUpdate: isUpdate)),
            ));
      },
    );
  }

  Future _showCustomerEntryDialog() async {
    _activeCustomer = CustomerAddress(state: _kDefaultState);
    CustomerAddress? customer = await _showBaseCustomerDialog();
    if (customer != null) {
      await _addContact(customer: customer);
    }
  }

  Future _showUpdateCustomerDialog(
      {required CustomerAddress customerToEdit}) async {
    _activeCustomer = customerToEdit.copyWidth();
    CustomerAddress? customer = await _showBaseCustomerDialog(isUpdate: true);
    if (customer != null) {
      customerToEdit.firstName = customer.firstName;
      customerToEdit.lastName = customer.lastName;
      customerToEdit.streetLine = customer.streetLine;
      customerToEdit.state = customer.state;
      customerToEdit.city = customer.city;

      await _updateContact(customer: customerToEdit);
    }
  }

  Future<bool?> _showBaseConfirmationDialogDialog(
      {required Widget body, required String positive}) {
    return showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Barrier",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Container();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeInOutBack.transform(anim1.value) - 1.0;
        return Transform(
            transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
            child: Opacity(
                opacity: anim1.value,
                child: _buildBaseDialogBody(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    body,
                    const SizedBox(
                      height: 16,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48), // NEW
                            ),
                            onPressed: () {
                              // Validate returns true if the form is valid, or false otherwise.
                              Navigator.pop(context, true);
                            },
                            child: Text(positive),
                          ),
                        )
                      ],
                    )
                  ],
                ))));
      },
    );
  }

  ///
  /// Prints the labels to using a Brother Printers.
  ///
  Future<void> _printLabels(
      {required List<CustomerAddress> customersToPrint}) async {
    // Create images
    List<ui.Image> preview = List.empty(growable: true);
    List<Uint8List> previewBytes = List.empty(growable: true);
    for (var element in customersToPrint) {
      ui.Image image = await _generateContactLabel(customer: element);
      preview.add(image);
      previewBytes.add((await image.toByteData(format: ImageByteFormat.png))!
          .buffer
          .asUint8List());
    }
    // Show dialog with preview
    bool? shouldPrint = await _showBaseConfirmationDialogDialog(
        body: LayoutBuilder(builder: (context, constraints) {
          bool hasMore = preview.length.toDouble() > 3;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: min(preview.length.toDouble(), 3) *
                  constraints.maxWidth *
                  kLabelHeight /
                  kLabelWidth  + (hasMore ? 8 : 0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(0),
                  separatorBuilder: (context, index) {
                    return const Divider(
                      height: 1,
                    );
                  },
                  itemCount: previewBytes.length,
                  itemBuilder: (context, index) {
                    return Image.memory(
                      previewBytes[index],
                      fit: BoxFit.fill,
                    );
                  }),
            ),
          );
        }),
        positive: "Print");

    if (shouldPrint != true) {
      // Don't print
      return;
    }

    // TODO Check if we are not on mobile and display snackbar.
    if (!(UniversalPlatform.isIOS || UniversalPlatform.isAndroid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Printing is only supported on Mobile Devices."),
        ),
      ));
      return;
    }

    // Configure printer.
    //////////////////////////////////////////////////
    /// Request the Storage permissions required by
    /// another_brother to print.
    //////////////////////////////////////////////////
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("Access to storage is needed in order print."),
        ),
      ));
      return;
    }
    //////////////////////////////////////////////////
    /// Configure printer
    /// Printer: QL1110NWB
    /// Connection: Bluetooth
    /// Paper Size: W62
    /// Important: Printer must be paired to the
    /// phone for the BT search to find it.
    //////////////////////////////////////////////////
    var printer = abPi.Printer();
    var printInfo = abPi.PrinterInfo();
    printInfo.printerModel = abPi.Model.QL_1110NWB;
    printInfo.printMode = abPi.PrintMode.FIT_TO_PAGE;
    printInfo.orientation = abPi.Orientation.LANDSCAPE;
    printInfo.isAutoCut = true;
    printInfo.port = abPi.Port.BLUETOOTH;
    // Set the label type.
    printInfo.labelNameIndex = QL1100.ordinalFromID(QL1100.W29H90.getId());

    // Set the printer info so we can use the SDK to get the printers.
    await printer.setPrinterInfo(printInfo);

    // Get a list of printers with my model available in the network.
    List<abPi.BluetoothPrinter> printers =
        await printer.getBluetoothPrinters([abPi.Model.QL_1110NWB.getName()]);

    if (printers.isEmpty) {
      // Show a message if no printers are found.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text("No paired printers found on your device."),
        ),
      ));
      return;
    }
    // Get the IP Address from the first printer found.
    printInfo.macAddress = printers.single.macAddress;
    printer.setPrinterInfo(printInfo);

    // Print labels one at a time.
    for (var labelImage in preview) {
      abPi.PrinterStatus status = await printer.printImage(labelImage);
    }
  }

  bool isValidEntry(String? value) {
    return value?.isNotEmpty == true;
  }
}

class ContactRowView extends StatelessWidget {
  final CustomerAddress customer;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleteTap;

  const ContactRowView(
      {Key? key,
      required this.customer,
      this.onTap,
      this.onLongPress,
      this.onDeleteTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      onTap: onTap,
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 1000),
        tween: ColorTween(
            begin: Colors.white,
            end: customer.isSelected ? Colors.lightBlueAccent : Colors.white),
        builder: (context, color, child) {
          return ColorFiltered(
            child: child,
            colorFilter: ColorFilter.mode(color!, BlendMode.modulate),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Card(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        customer.nameLine,
                        style: kLabelTextStyle.copyWith(fontSize: 20),
                      ),
                    ),
                    Text(customer.streetLine!, style: kLabelTextStyle),
                    Text(customer.stateLine, style: kLabelTextStyle),
                  ],
                ),
              ),
            ),
            if (customer.isSelected) ...[
              Positioned(
                  right: 0,
                  child: GestureDetector(
                    onTap: onDeleteTap,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close),
                    ),
                  ))
            ]
          ],
        ),
      ),
    );
  }
}

class OleenAppBar extends StatelessWidget with PreferredSizeWidget, OleenLogo {
  final String title;

  const OleenAppBar({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppBar(
          centerTitle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60))),
          title:
              Text(title, style: GoogleFonts.loveYaLikeASister(fontSize: 30)),
        ),
        Positioned(
          bottom: -10,
          child: Center(
            child: buildAppLogo(width: kToolbarHeight, height: kToolbarHeight),
          ),
        ),
        Positioned(
          right: 0,
          bottom: -10,
          child: Center(
            child: Transform.scale(
                scaleX: -1,
                child: buildAppLogo(
                    width: kToolbarHeight, height: kToolbarHeight)),
          ),
        )
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CustomerAddress {
  int? recordId;
  String? firstName;
  String? lastName;
  String? streetLine;
  String? city;
  String? state;
  bool isSelected;

  CustomerAddress(
      {this.recordId,
      this.city,
      this.state,
      this.streetLine,
      this.firstName,
      this.lastName,
      this.isSelected = false});

  String get nameLine => "$firstName $lastName";

  String get stateLine => "$city, $state";

  CustomerAddress copyWidth(
      {int? recordId,
      String? firstName,
      String? lastName,
      String? streetLine,
      String? city,
      String? state,
      bool? isSelected}) {
    return CustomerAddress(
        recordId: recordId ?? this.recordId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        streetLine: streetLine ?? this.streetLine,
        city: city ?? this.city,
        state: state ?? this.state,
        isSelected: isSelected ?? this.isSelected);
  }

  @override
  String toString() {
    return "$recordId: $nameLine $stateLine";
  }
}

mixin OleenLogo {
  Widget buildAppLogo({required double width, required double height}) {
    return Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
              image: AssetImage("assets/images/coconut.png"), fit: BoxFit.fill),
        ));
  }
}
