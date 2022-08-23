import 'dart:async';
import 'package:http/http.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'content_provider.dart' as content;
import 'dart:io' show Platform;

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

class ImageTitleItem extends StatelessWidget {
  final Image image;
  final String title;
  const ImageTitleItem({Key? key, required this.image, required this.title})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(children: [Expanded(child: image), Text(title)]);
  }
}

class ContentPageItem extends StatelessWidget {
  final content.Item item;
  const ContentPageItem({Key? key, required this.item}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ImageTitleItem(
        image: Image.network('$protocol://$ip:$port/file?path=${item.icon}'),
        title: item.title);
  }
}

class ContentState extends State<ContentPage> {
  content.Context? _contentContext;
  int _count = 0;

  void _bindContext(content.Context event) {
    setState(() => _contentContext = event);
    event.size.listen((event) {
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
      widget.context.listen(_bindContext);
    }
    final size = widget.preferences.itemSize;
    return Center(
        child: CustomScrollView(slivers: [
      SliverGrid(
        delegate: SliverChildBuilderDelegate(
            childCount: _count,
            (context, index) => item(_contentContext!.getItem(index))),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]));
  }
}

final String ip = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
const int port = 31136;
const String protocol = 'http';

class UploadFileDialog extends StatefulWidget {
  final Preferences preferences;
  const UploadFileDialog({required this.preferences, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => UploadFileDialogState();
}

class UploadFileDialogState extends State<UploadFileDialog> {
  var _files = <PlatformFile>[];
  var _uploading = false;

  void _sendFile() {
    var request = MultipartRequest(
        "POST", Uri(scheme: protocol, host: ip, port: port, path: 'file'));
    for (var file in _files) {
      var value =
          MultipartFile.fromBytes('files', file.bytes!, filename: file.name);
      request.files.add(value);
    }
    setState(() {
      _uploading = true;
    });
    request
        .send()
        .then((value) => setState(() {
              _uploading = false;
            }))
        .onError((error, stackTrace) => setState(() {
              _uploading = true;
            }));
  }

  bool _isFileSelected() {
    return _files.isNotEmpty;
  }

  Widget _selectFileButton() {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(16.0),
        primary: Colors.white,
        textStyle: const TextStyle(fontSize: 20),
      ),
      onPressed: () => FilePicker.platform
          .pickFiles(allowMultiple: true, withData: true)
          .then((value) => {
                if (value != null && value.count != 0)
                  {
                    setState(() => {(_files = value.files)})
                  }
              }),
      child: const Text('Select files to upload'),
    );
  }

  Widget _topPart() {
    return CustomScrollView(
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        slivers: [
          SliverFixedExtentList(
            delegate: SliverChildListDelegate(_files
                .map<Widget>((file) => ImageTitleItem(
                    image: Image.memory(file.bytes!), title: file.name))
                .toList()),
            itemExtent: widget.preferences.itemSize.width,
          )
        ]);
  }

  Widget _bottomPart() {
    if (_uploading) {
      return const CircularProgressIndicator();
    } else {
      if (_isFileSelected()) {
        return FloatingActionButton(
            onPressed: _sendFile, child: const Icon(Icons.upload_file));
      } else {
        return const SizedBox();
      }
    }
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_selectFileButton(), _bottomPart()],
                )
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
                builder: (context) => UploadFileDialog(
                      preferences: preferences,
                    ))));
  }
}

void main() async {
  var preferences = Preferences(Size(150, 150));
  final contextController = StreamController<content.Context>();
  contextController.add(content.ContextProvider().getContext("home"));
  runApp(MaterialApp(
    title: "Whatever cloud",
    home: SafeArea(
        child: Scaff(
            preferences: preferences, contextController: contextController)),
  ));
}
