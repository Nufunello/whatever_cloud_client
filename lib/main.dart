import 'dart:async';
import 'package:http/http.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'content_provider.dart' as content;

class Size {
  late final double height;
  late final double width;
  Size(this.width, this.height);
}

class Preferences {
  late Size itemSize;
  Preferences(this.itemSize);
}

class ContentPage extends StatefulWidget {
  final Preferences preferences;
  final Stream<content.Context> context;
  const ContentPage(
      {Key? key, required this.preferences, required this.context})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ContentState();
}

class ContentPageItem extends StatelessWidget {
  final content.Item item;
  const ContentPageItem({Key? key, required this.item}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(children: [Expanded(child: item.image), Text(item.title)]);
  }
}

class ContentState extends State<ContentPage> {
  content.Context? _contentContext;
  int _count = 0;

  void _bind_context(content.Context event) {
    setState(() => _contentContext = event);
    event.count.listen((event) {
      setState(() => _count = event);
    });
  }

  FutureBuilder<content.Item> item(Future<content.Item> future) {
    return FutureBuilder<content.Item>(
      builder: ((context, snapshot) => snapshot.hasData
          ? ContentPageItem(item: snapshot.requireData)
          : const CircularProgressIndicator()),
      future: future,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_contentContext == null) {
      widget.context.listen(_bind_context);
    }
    final size = widget.preferences.itemSize;
    return Center(
        child: CustomScrollView(slivers: [
      SliverGrid(
        delegate: SliverChildBuilderDelegate(
            childCount: 1,
            (context, index) => ContentPageItem(
                item: content.Item(
                    image: Image.network(
                        'https://localhost:44346/file?file=owl.jpg'),
                    title: "OWl"))), //item(_contentContext!.getItem(index))),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]));
  }
}

class UploadFileDialog extends StatefulWidget {
  const UploadFileDialog({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => UploadFileDialogState();
}

class UploadFileDialogState extends State<UploadFileDialog> {
  var _files = <PlatformFile>[];

  void _sendFile() {
    var request = MultipartRequest("POST",
        Uri(scheme: 'https', host: 'localhost', port: 44346, path: 'file'));
    for (var file in _files) {
      var value =
          MultipartFile.fromBytes('files', file.bytes!, filename: file.name);
      request.files.add(value);
    }
    request.send();
  }

  bool _isFileSelected() {
    return _files.isNotEmpty;
  }

  Widget _topPart() {
    return GestureDetector(
        child: _isFileSelected()
            ? Column(children: _files.map((e) => Text(e.name)).toList())
            : const Text('Select a file to upload'),
        onTap: () => FilePicker.platform
            .pickFiles(allowMultiple: true, withData: true)
            .then((value) => {
                  if (value != null && value.count != 0)
                    {
                      setState(() => {(_files = value.files)})
                    }
                }));
  }

  Widget _bottomPart() {
    return FloatingActionButton(
        onPressed: _isFileSelected() ? _sendFile : null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Scaffold(
            backgroundColor: Colors.blueGrey,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(child: _topPart()),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_bottomPart()],
                ),
              ],
            )));
  }
}

class Scaff extends StatelessWidget {
  final Preferences preferences;
  final StreamController<content.Context> contextController;
  const Scaff(
      {Key? key, required this.preferences, required this.contextController})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: ContentPage(
                preferences: preferences, context: contextController.stream)),
        floatingActionButton: FloatingActionButton(
            onPressed: () => showDialog(
                context: context,
                builder: (context) => const UploadFileDialog())));
  }
}

void main() async {
  var preferences = Preferences(Size(150, 150));
  final contextController = StreamController<content.Context>();
  contextController
      .add(content.ItemProvider().getContext("home")..preload(0, 10));
  runApp(MaterialApp(
    title: "Whatever cloud",
    home: Scaff(preferences: preferences, contextController: contextController),
  ));
}
