library content;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import "package:dart_amqp/dart_amqp.dart";

class Item {
  final Image image;
  final String title;

  const Item({required this.image, required this.title});
}

class ContextItem extends ChangeNotifier {}

class Context {
  static const _exchange = 'amq.direct';
  static const ExchangeType _type = ExchangeType.DIRECT;

  final Client client;
  Stream<int> get count => _countController.stream;

  final _countController = StreamController<int>();
  final _content = <int, Completer<Item>>{};

  void _prepareConsumer(Consumer consumer) {
    consumer.queue.purge();
  }

  void _requestContent(int index, int size) {
    client
        .channel()
        .then((channel) => channel.exchange('amq.direct', _type, durable: true))
        .then(
          (exchange) => exchange.publish({'Index': index, 'Size': size},
              "whatever_cloud/server/home/content"),
        );
  }

  void _requestSize() {
    client
        .channel()
        .then((channel) => channel.exchange('amq.direct', _type, durable: true))
        .then(
          (exchange) => exchange.publish("home", "whatever_cloud/server/size"),
        );
  }

  void _content_listener(AmqpMessage message) {
    final Iterable payload = json.decode(message.payloadAsString);
    for (var json in payload) {
      final completer = _content[int.parse(json['Index'])]!;
      final item = Item(
          image: Image.file(File(
              'C:/Users/nafan/Desktop/dev/whatever_cloud_client/build/owl.jpg')),
          title: json['Title']);
      completer.complete(item);
    }
  }

  void _size_listener(AmqpMessage message) {
    _countController.add(message.payloadAsJson['Size']);
  }

  Context({required this.client}) {
    client
        .channel()
        .then((channel) => channel.exchange(_exchange, _type, durable: true))
        .then((exchange) {
      exchange.bindQueueConsumer('home_content',
          ['whatever_cloud/client/home/content']).then((consumer) {
        _prepareConsumer(consumer);
        consumer.listen(_content_listener);
      });
      exchange.bindQueueConsumer(
          'home_size', ['whatever_cloud/client/home/size']).then((consumer) {
        _prepareConsumer(consumer);
        consumer.listen(_size_listener);
      });
    });
    _requestSize();
  }
  Future<Item> getItem(int index) {
    if (_content.containsKey(index)) {
      return _content[index]!.future;
    } else {
      final completer = _content.putIfAbsent(index, () => Completer());
      var future = completer.future;
      _requestContent(index, 1);
      return future;
    }
  }

  Future<void> preload(int index, int size) async {
    final futures = List<Future<Item>>.generate(size, (i) {
      i + index;
      var future = _content.putIfAbsent(i, () => Completer()).future;
      _requestContent(i, 1);
      return future;
    });
    for (final future in futures) {
      await future;
    }
  }
}

class ItemProvider {
  static final contexts = {'home': Context(client: Client())};
  Context getContext(String context) {
    return contexts[context]!;
  }
}
