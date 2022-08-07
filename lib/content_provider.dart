library content;

import 'dart:io';

import 'package:flutter/material.dart';

class Item {
  final Image image;
  final String title;

  const Item({required this.image, required this.title});
}

class Context {
  Item getItem(int index) {
    return Item(
        image: Image.file(File(
            'C:/Users/nafan/Desktop/dev/whatever_cloud_client/build/owl.jpg')),
        title: '$index');
  }
}

class ItemProvider {
  Context getContext(String context) {
    return Context();
  }
}
