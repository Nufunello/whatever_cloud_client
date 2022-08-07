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
  final Preferences _preferences;
  const ContentPage(this._preferences, {Key? key}) : super(key: key);

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
  @override
  Widget build(BuildContext context) {
    final size = widget._preferences.itemSize;
    return Center(
        child: CustomScrollView(slivers: [
      SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = content.ItemProvider().getContext("home").getItem(index);
          return FutureBuilder<content.Item>(
            builder: ((context, snapshot) => (snapshot.hasData)
                ? ContentPageItem(item: snapshot.requireData)
                : const CircularProgressIndicator()),
            future: item,
          );
        }),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]));
  }
}

void main() async {
  var preferences = Preferences(Size(150, 150));
  content.ItemProvider().getContext("home").preload(0, 10);
  runApp(MaterialApp(
    title: "Whatever cloud",
    home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: ContentPage(
          preferences,
        ))),
  ));
}
