import 'package:flutter/material.dart';

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

class ContentState extends State<ContentPage> {
  @override
  Widget build(BuildContext context) {
    final size = widget._preferences.itemSize;
    return Center(
        child: CustomScrollView(slivers: [
      SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Text('$index');
        }),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisExtent: size.height, maxCrossAxisExtent: size.width),
      )
    ]));
  }
}

void main() {
  var preferences = Preferences(Size(150, 150));
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
