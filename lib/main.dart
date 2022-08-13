import 'dart:async';

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
      builder: ((context, snapshot) {
        if (snapshot.hasData) {
          return ContentPageItem(item: snapshot.requireData);
        } else {
          return const CircularProgressIndicator();
        }
      }),
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
            childCount: _count,
            (context, index) => item(_contentContext!.getItem(index))),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]));
  }
}

void main() async {
  var preferences = Preferences(Size(150, 150));
  final contextController = StreamController<content.Context>();
  contextController
      .add(content.ItemProvider().getContext("home")..preload(0, 10));
  runApp(MaterialApp(
    title: "Whatever cloud",
    home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: ContentPage(
                preferences: preferences, context: contextController.stream))),
  ));
}
