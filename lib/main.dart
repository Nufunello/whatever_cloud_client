import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:http/http.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'content_provider.dart' as content;
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image/flutter_image.dart';

import 'package:string_validator/string_validator.dart';

class Size {
  late final double height;
  late final double width;
  Size(this.width, this.height);
}

class Preferences {
  late Size itemSize;
  Preferences(this.itemSize);
}

class PlayVideoDialog extends StatefulWidget {
  final String url;
  const PlayVideoDialog({Key? key, required this.url}) : super(key: key);

  @override
  State<StatefulWidget> createState() => PlayVideoDialogState();
}

class PlayVideoDialogState extends State<PlayVideoDialog> {
  VideoPlayerController? _videoController;
  Future<void>? _video;
  @override
  Widget build(BuildContext context) {
    _videoController ??= VideoPlayerController.network(widget.url);
    final videoController = _videoController!;
    _video ??= videoController.initialize();
    return FutureBuilder(
        future: _video,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Scaffold(
                body: Center(
                    child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          height: videoController.value.size.height,
                          width: videoController.value.size.width,
                          child: VideoPlayer(videoController),
                        ))),
                floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        videoController.value.isPlaying
                            ? videoController.pause()
                            : videoController.play();
                      });
                    },
                    child: Icon(
                      videoController.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    )));
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        });
  }
}

class ImageDialog extends StatelessWidget {
  final String url;
  final String title;
  const ImageDialog({Key? key, required this.url, required this.title})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(children: [
        Expanded(
          child: Image(image: NetworkImageWithRetry(url)),
        ),
        Text(
          title,
          style: TextStyle(backgroundColor: Colors.blue),
        )
      ]),
    );
  }
}

class UnsupportedDialog extends StatelessWidget {
  final String title;
  const UnsupportedDialog({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 200,
        height: 200,
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: ExactAssetImage('images/file.png'), fit: BoxFit.cover)),
        child: Text(title),
      ),
    );
  }
}

class ContentPage extends StatefulWidget {
  final Preferences preferences;
  const ContentPage({Key? key, required this.preferences}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ContentState();
}

class ImageTitleItem extends StatelessWidget {
  final Widget image;
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
  final SelectedIndexes selectedItems;
  final int index;
  final Preferences preferences;
  const ContentPageItem(
      {Key? key,
      required this.item,
      required this.selectedItems,
      required this.index,
      required this.preferences})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ContentPageItemState();
}

class ContentPageItemState extends State<ContentPageItem> {
  void updateSelected() {
    final selectedItems = widget.selectedItems;
    final index = widget.index;
    final shouldBeSelected = !selectedItems.contains(index);
    if (shouldBeSelected) {
      selectedItems.add(index);
    } else {
      selectedItems.remove(index);
    }
    setState(() {});
  }

  static final fileWidgets =
      <content.ItemType, Widget Function(String, Preferences preferences)>{
    content.ItemType.unsupported: (String path, Preferences preferences) =>
        defaultImage,
    content.ItemType.image: (String path, Preferences preferences) => Image.network(
        '$protocol://${content.SERVER_IP}:$port/icon/$path/?width=${preferences.itemSize.width}&height=${preferences.itemSize.height}'),
    content.ItemType.video: (String path, Preferences preferences) => Image.network(
        '$protocol://${content.SERVER_IP}:$port/icon/$path/?width=${preferences.itemSize.width}&height=${preferences.itemSize.height}')
  };

  Widget base(content.Item item) {
    return ImageTitleItem(
        image: fileWidgets[item.type]!(item.path, widget.preferences),
        title: item.title);
  }

  Widget applyGesture(Widget base) {
    return StreamBuilder<bool>(
        stream: widget.selectedItems.isNotEmpty,
        builder: ((context, snapshot) => GestureDetector(
            onLongPress: updateSelected,
            onTap: (() {
              if (snapshot.hasData && snapshot.requireData) {
                updateSelected();
              } else {
                if (widget.selectedItems.hasIndexes()) {
                  return;
                }
                switch (widget.item.type) {
                  case content.ItemType.video:
                    {
                      showDialog(
                          context: context,
                          builder: (context) => PlayVideoDialog(
                                url:
                                    '$protocol://${content.SERVER_IP}:$port/file/${widget.item.path}/',
                              ));
                      break;
                    }
                  case content.ItemType.image:
                    {
                      showDialog(
                          context: context,
                          builder: (context) => ImageDialog(
                                url:
                                    '$protocol://${content.SERVER_IP}:$port/file/${widget.item.path}/',
                                title: widget.item.title,
                              ));
                      break;
                    }
                  case content.ItemType.unsupported:
                    {
                      showDialog(
                          context: context,
                          builder: (context) =>
                              UnsupportedDialog(title: widget.item.title));
                      break;
                    }
                }
              }
            }),
            child: base)));
  }

  @override
  Widget build(BuildContext context) {
    final item = applyGesture(base(widget.item));
    final selectedItems = widget.selectedItems;
    final index = widget.index;
    return Container(
        decoration: selectedItems.contains(index)
            ? BoxDecoration(border: Border.all(color: Colors.blueAccent))
            : null,
        child: item);
  }
}

class SelectedIndexes {
  final _selectedItems = <int>{};
  final _controllbarAppear = StreamController<bool>.broadcast();

  void _notify() {
    _controllbarAppear.add(_selectedItems.isNotEmpty);
  }

  void add(int index) {
    _selectedItems.add(index);
    _notify();
  }

  void remove(int index) {
    _selectedItems.remove(index);
    _notify();
  }

  void clear() {
    _selectedItems.clear();
    _notify();
  }

  bool contains(int index) {
    return _selectedItems.contains(index);
  }

  List<int> toList() {
    return _selectedItems.toList();
  }

  bool hasIndexes() {
    return _selectedItems.isNotEmpty;
  }

  Stream<bool> get isNotEmpty => _controllbarAppear.stream;
}

class ContentState extends State<ContentPage> {
  content.Context? _contentContext;
  StreamSubscription? subscription;
  final _selectedItems = SelectedIndexes();
  int _count = 0;

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void _bindContext(content.Context event) {
    setState(() => _contentContext = event);
    subscription = event.size.listen((event) {
      setState(() {
        _count = event;
      });
      _selectedItems.clear();
    });
  }

  Widget item(int index, Future<content.Item> future) {
    return FutureBuilder<content.Item>(
      builder: ((context, snapshot) => snapshot.hasData
          ? ContentPageItem(
              selectedItems: _selectedItems,
              index: index,
              item: snapshot.requireData,
              preferences: widget.preferences,
            )
          : const CircularProgressIndicator()),
      future: future,
    );
  }

  Widget deleteButton() {
    return FloatingActionButton(
      child: const Icon(Icons.delete),
      onPressed: () {
        _contentContext?.askRemoveItem(_selectedItems.toList());
      },
    );
  }

  Widget downloadButton() {
    return FloatingActionButton(
      child: const Icon(Icons.download),
      onPressed: () async {
        var status = await Permission.storage.status;
        if (!status.isGranted &&
            !await Permission.storage.request().isGranted) {
          return;
        }
        FilePicker.platform
            .getDirectoryPath(dialogTitle: "Save files to")
            .then((dest) {
          for (final i in _selectedItems._selectedItems) {
            _contentContext?.getItem(i).then((item) async {
              final response = await get(Uri(
                  scheme: protocol,
                  host: content.SERVER_IP,
                  port: port,
                  path: 'file/${item.path}/'));

              File(join(dest!, item.title))
                  .writeAsBytesSync(response.bodyBytes);
            });
          }
        });
      },
    );
  }

  Widget controlbar() {
    return Container(
        color: Colors.lightBlue,
        child: IntrinsicHeight(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [deleteButton(), downloadButton()])));
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
      _contentContext ??= content.ContextProvider(content.SERVER_IP)
          .getContext(content.SERVER_IP, "home");
      _bindContext(_contentContext!);
    }
    return StreamBuilder<bool>(
        stream: _selectedItems.isNotEmpty,
        builder: (context, snapshot) {
          final children = <Widget>[];
          if (snapshot.hasData && snapshot.requireData) {
            children.add(controlbar());
          }
          children.add(Expanded(child: elementsGrid()));
          return Column(children: children);
        });
  }
}

const int port = 44341;
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
        "POST",
        Uri(
            scheme: protocol,
            host: content.SERVER_IP,
            port: port,
            path: 'file'));
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
    return Expanded(
        child: FloatingActionButton(
      onPressed: () => FilePicker.platform
          .pickFiles(allowMultiple: true, withData: true)
          .then((value) => {
                if (value != null && value.count != 0)
                  {
                    setState(() => {(_files = value.files)})
                  }
              }),
      child: Icon(Icons.drive_file_move),
    ));
  }

  Image _imageForItem(PlatformFile file) {
    if ((content.types['.${file.extension!}'] ??
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
  const Scaff({Key? key, required this.preferences}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: ContentPage(preferences: preferences),
        floatingActionButton: FloatingActionButton(
            onPressed: () => showDialog(
                context: context,
                builder: (context) => UploadFileDialog(
                      preferences: preferences,
                    )),
            child: const Icon(Icons.upload_file)));
  }
}

class EnterIP extends StatefulWidget {
  const EnterIP({super.key, required this.preferences});
  final Preferences preferences;

  @override
  State<EnterIP> createState() => EnterIPState();
}

class EnterIPState extends State<EnterIP> {
  final _ipController = TextEditingController()..text = "192.168.0.";
  bool _buttonEnabled = false;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Start listening to changes.
    _ipController.addListener(() {
      setState(() {
        _buttonEnabled = isIP(_ipController.text);
      });
      content.SERVER_IP = _ipController.text;
    });
  }

  void navigateOnHTTPSuckass(
      BuildContext context, TextEditingController controller) {
    String IP = controller.text;
    Socket.connect(IP, port, timeout: Duration(seconds: 2)).then((socket) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: ((context) =>
                  SafeArea(child: Scaff(preferences: widget.preferences)))));
      socket.destroy();
    }).catchError((error) {
      showDialog(
          context: context,
          builder: ((context) =>
              AlertDialog(title: const Text('Server timeout'))));
    });
  }

  @override
  Widget build(BuildContext context) {
    final button = FloatingActionButton(
        onPressed: _buttonEnabled
            ? () => navigateOnHTTPSuckass(context, _ipController)
            : null,
        child: const Icon(Icons.login));
    return Scaffold(
        backgroundColor: Colors.white,
        body: ListView(children: [TextField(controller: _ipController)]),
        floatingActionButton: button);
  }
}

void main() async {
  var preferences = Preferences(Size(150, 150));
  runApp(MaterialApp(
    title: "Whatever cloud",
    home: SafeArea(child: EnterIP(preferences: preferences)),
  ));
}
