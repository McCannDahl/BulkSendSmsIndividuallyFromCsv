import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BSSMSIFCSV',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool filePicked = false;
  List<String> phoneNumbers = [];
  String? displayText;
  late TextEditingController _controller;
  bool messageExists = false;
  List<List<dynamic>>  csvfields = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    getPermissions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> getPermissions() async {
    final permission = Permission.sms.request();
    if (await permission.isGranted) {
      pickFile();
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      setState(() {
        filePicked = true;
      });
      parseFile(file);
    }
  }

  bool isValidPhoneNumber(String? value) => RegExp(r'(^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$)').hasMatch(value ?? '');

  Future<void> parseFile(File file) async {
    final input = file.openRead();
    final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();
    setState(() {
      csvfields = fields;
    });
    for (var field in fields) {
      try {
        var phoneNumber = field[0].toString();
        if (phoneNumber != null && phoneNumber != '') {
          if (isValidPhoneNumber(phoneNumber)) {
            phoneNumbers.add(phoneNumber);
          }
        }
      } catch (err) {
        print(err);
      }
    }
    setState(() {
      phoneNumbers = phoneNumbers.toSet().toList(); // this removes duplicates
    });
  }

  Future<void> _sendTexts() async {
    for (var i = 0; i < phoneNumbers.length; i++) {
      var result = '';
      result = await sendSMS(message: _controller.text, recipients: [phoneNumbers[i]], sendDirect: true).catchError((onError) {
        print(onError);
        result = onError.toString();
        return onError.toString();
      });
      setState(() {
        displayText = '$result ${i + 1}/${phoneNumbers.length}';
      });
      await Future.delayed(Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Hello!',
            ),
            !filePicked
                ? const Text(
                    'You must pick a file. Make sure the phone numbers are in the 0th column (column A)',
                  )
                : SingleChildScrollView(child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    Text(
                      'You will send to ${phoneNumbers.length} numbers',
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      child: TextField(
                        onChanged: (value) => setState(() {
                          messageExists = value != '';
                        }),
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Message',
                        ),
                      ),
                    ),
                    displayText != null
                        ? Text(
                            'Result: $displayText',
                          )
                        : Container(),

                    Text(
                      phoneNumbers.toString(),
                    ),
                    Text(
                      csvfields.toString(),
                    ),
                  ]))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: filePicked && messageExists ? _sendTexts : null, tooltip: 'Send', child: const Icon(Icons.send), backgroundColor: filePicked && messageExists ? null : Colors.grey), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
