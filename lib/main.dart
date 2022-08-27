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

class ContentPageItem extends StatefulWidget {
  final content.Item item;
  final void Function(bool) onSelectionChanged;
  const ContentPageItem(
      {Key? key, required this.item, required this.onSelectionChanged})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ContentPageItemState();
}

class ContentPageItemState extends State<ContentPageItem> {
  bool _isSelected = false;
  void setSelected(bool isSelected) {
    setState(() {
      _isSelected = isSelected;
      widget.onSelectionChanged(_isSelected);
    });
  }

  Widget base(content.Item item) {
    return ImageTitleItem(
        image: item.type == content.ItemType.image
            ? Image.network('$protocol://$ip:$port/file?path=${item.icon}')
            : defaultImage,
        title: item.title);
  }

  Widget applyGesture(Widget base) {
    return GestureDetector(
        child: base,
        onLongPress: () => setSelected(true),
        onTap: () {
          setSelected(!_isSelected);
        });
  }

  @override
  Widget build(BuildContext context) {
    final item = applyGesture(base(widget.item));
    if (_isSelected) {
      return Container(
          decoration:
              BoxDecoration(border: Border.all(color: Colors.blueAccent)),
          child: item);
    } else {
      return item;
    }
  }
}

class ContentState extends State<ContentPage> {
  content.Context? _contentContext;
  final _selectedItems = <int>{};
  int _count = 0;

  void _bindContext(content.Context event) {
    setState(() => _contentContext = event);
    event.size.listen((event) {
      setState(() {
        _count = event;
        _selectedItems.clear();
      });
    });
  }

  Widget item(int index, Future<content.Item> future) {
    return FutureBuilder<content.Item>(
      builder: ((context, snapshot) => snapshot.hasData
          ? ContentPageItem(
              onSelectionChanged: (isSelected) {
                setState(() {
                  if (isSelected) {
                    _selectedItems.add(index);
                  } else {
                    _selectedItems.remove(index);
                  }
                });
              },
              item: snapshot.requireData,
            )
          : const CircularProgressIndicator()),
      future: future,
    );
  }

  Widget controlbar() {
    return Container(
        color: Colors.lightBlue,
        child: IntrinsicHeight(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          FloatingActionButton(
            child: const Icon(Icons.delete),
            onPressed: () {
              _contentContext?.askRemoveItem(_selectedItems.toList());
            },
          )
        ])));
  }

  Widget elementsGrid() {
    final size = widget.preferences.itemSize;
    return CustomScrollView(slivers: [
      SliverGrid(
        delegate: SliverChildBuilderDelegate(
            childCount: _count,
            (context, index) => item(index, _contentContext!.getItem(index))),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_contentContext == null) {
      widget.context.listen(_bindContext);
    }
    final children = <Widget>[];
    if (_selectedItems.isNotEmpty) {
      children.add(controlbar());
    }
    children.add(Expanded(child: elementsGrid()));
    return Column(children: children);
  }
}

final String ip = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
const int port = 31136;
const String protocol = 'http';
final defaultImage = Image.asset('images/file.png');

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
          backgroundColor: Colors.lightBlue),
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

  Image _imageForItem(PlatformFile file) {
    if ((content.types['.' + file.extension!] ??
            content.ItemType.unsupported) ==
        content.ItemType.image) {
      return Image.memory(file.bytes!);
    } else {
      return defaultImage;
    }
  }

  Widget _topPart() {
    return CustomScrollView(
        shrinkWrap: true,
        scrollDirection: Axis.vertical,
        slivers: [
          SliverFixedExtentList(
            delegate: SliverChildListDelegate(_files
                .map<Widget>((file) => ImageTitleItem(
                    image: _imageForItem(file), title: file.name))
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
        body: ContentPage(
            preferences: preferences, context: contextController.stream),
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
