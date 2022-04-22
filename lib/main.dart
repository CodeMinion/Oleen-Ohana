import 'dart:ui';

import 'package:another_quickbase/another_quickbase.dart';
import 'package:another_quickbase/another_quickbase_models.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:vector_math/vector_math.dart' as math;
import 'app_keys.dart';

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
    var focus = const Color(0xFF4ac3be);
    var grey = const Color(0xff999999);
    var textTheme = (!isDark ? ThemeData.dark() : ThemeData.light()).textTheme;
    ColorScheme scheme = ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent1,
        primaryVariant: shift(accent1, .1),
        secondary: accent1,
        secondaryVariant: shift(accent1, .1),
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
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        accentIconTheme: IconThemeData(
          color: Colors.white,
        ),
        primaryIconTheme: IconThemeData(
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
            backgroundColor: greyStrong,
            actionTextColor: accent1,
            contentTextStyle: t.textTheme.caption!.copyWith(color: accent1)),
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

class _MyHomePageState extends State<MyHomePage> {
  final PagingController<int, CustomerAddress> _pagingController =
      PagingController(firstPageKey: 0);
  final List<CustomerAddress> _selectedCustomers = List.empty(growable: true);
  bool _clientReady = false;
  int _recordsPerPage = 10;

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
      print("Error: $error");
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
        appBar: AppBar(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40))),
          title: Text(widget.title,
              style: GoogleFonts.loveYaLikeASister(fontSize: 30)),
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
                      // TODO Print a label for every selected customer.
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

    print("contacts: $contacts");
    int index = 0;
    List<CustomerAddress> customers = contacts.data?.map((item) {
          ++index;
          return CustomerAddress(
              recordId: item["3"]["value"],
              firstName: "${item["6"]["value"]}",
              lastName: "${item["7"]["value"]}",
              streetLine: "${item["9"]["value"]}",
              city: "${item["11"]["value"]}",
              state: "${item["12"]["value"]}");
        }).toList() ??
        List<CustomerAddress>.empty();

    print("customers $customers");
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
    var queryBuffer = StringBuffer();
    print("Trying to delete recordId ${customer.recordId}");

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

    print("Deleted Count $deletedCount");
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

  Widget _buildLargeContactsView(BuildContext context) {
    return PagedGridView(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<CustomerAddress>(
          itemBuilder: (context, item, index) =>
              _createContactCard(index: index, customer: item),
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, childAspectRatio: 90.3 / 29));
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
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _activeCustomer?.state?.toUpperCase(),
              icon: const Icon(Icons.arrow_downward),
              elevation: 16,
              style: TextStyle(color: mainTheme.colorScheme.onSecondary),
              onChanged: (String? newValue) {
                setState(() {
                  print("Staet selected $newValue");
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
              child: Dialog(
                  backgroundColor: Colors.transparent,
                  child:
              StatefulBuilder(builder: (context, StateSetter setState) {
                ThemeData theme = Theme.of(context);
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top:50.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.background,
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom:16.0, top:60),
                          child: SizedBox(
                              width: 400,
                              child: _createCustomerForm(
                                  context: context, setState: setState, isUpdate: isUpdate)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                  image: AssetImage("assets/images/coconut.png"),
                                  fit: BoxFit.fill
                              ),

                          ),

                        ),
                      ),
                    ),
                  ],
                );
              })),
            ));
      },
    );
  }

  Future _showCustomerEntryDialog() async {
    _activeCustomer = CustomerAddress(state: _kDefaultState);
    CustomerAddress? customer = await _showBaseCustomerDialog();

    /*
    CustomerAddress? customer = await showDialog<CustomerAddress?>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(child: StatefulBuilder(
          builder: (context, StateSetter setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                  width: 400,
                  child: _createCustomerForm(context: context, setState: setState)),
            );
          }
        ));
      },
    );

     */
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

  ///
  /// Prints the labels to using a Brother Printers.
  Future<void> _printLabels(
      {required List<CustomerAddress> customersToPrint}) async {
    // TODO Print to a brother printer.
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
                    Text(
                      customer.nameLine,
                      style: GoogleFonts.vibur(fontSize: 20),
                    ),
                    Text(customer.streetLine!, style: GoogleFonts.vibur()),
                    Text(customer.stateLine, style: GoogleFonts.vibur()),
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

  String get stateLine => "$city,$state";

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
