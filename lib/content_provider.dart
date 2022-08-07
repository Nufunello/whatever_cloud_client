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

class Context {
  final Client client;
  static const _exchange = 'amq.direct';
  static const ExchangeType type = ExchangeType.DIRECT;
  var content = <int, Completer<Item>>{};

  void _prepareConsumer(Consumer consumer) {
    consumer.queue.purge();
  }

  void _requestContent(int index, int size) {
    client
        .channel()
        .then((channel) => channel.exchange('amq.direct', type, durable: true))
        .then((exchange) => {
              exchange.publish(
                  {'Index': index, 'Size': size}, "whatever_cloud/server"),
            });
  }

  void _listener(AmqpMessage message) {
    final Iterable payload = json.decode(message.payloadAsString);
    for (var json in payload) {
      final item = Item(
          image: Image.file(File(
              'C:/Users/nafan/Desktop/dev/whatever_cloud_client/build/owl.jpg')),
          title: json['Title']);
      final completer = content[int.parse(json['Index'])]!;
      completer.complete(item);
    }
  }

  Context({required this.client}) {
    client
        .channel()
        .then((channel) => channel.exchange(_exchange, type, durable: true))
        .then((exchange) =>
            exchange.bindQueueConsumer('home', ['whatever_cloud/client']))
        .then((consumer) {
      _prepareConsumer(consumer);
      consumer.listen(_listener);
    });
  }
  Future<Item> getItem(int index) {
    if (content.containsKey(index)) {
      return content[index]!.future;
    } else {
      final completer = content.putIfAbsent(index, () => Completer());
      var future = completer.future;
      _requestContent(index, 1);
      return future;
    }
  }

  Future<void> preload(int index, int size) async {
    final futures = List<Future<Item>>.generate(size, (i) {
      i + index;
      var future = content.putIfAbsent(i, () => Completer()).future;
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
