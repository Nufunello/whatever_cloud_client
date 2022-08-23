library content;

import 'dart:async' as ass;
import "package:dart_amqp/dart_amqp.dart";
import 'package:path/path.dart';
import 'dart:io' show Platform;

enum ItemType { image, video }

class Item {
  final String icon;
  final String title;
  final ItemType type;

  const Item({required this.icon, required this.title, required this.type});
}

class Messager {
  static Future<Channel> get client => (() => Client(
          settings: ConnectionSettings(
              host: Platform.isAndroid ? '10.0.2.2' : '127.0.0.1'))
      .channel())();
  static Future<Exchange> get exchange => (() => client.then((client) =>
      client.exchange('amq.direct', ExchangeType.DIRECT, durable: true)))();

  static void privateQueue(
      String routingKey, Function(AmqpMessage message) listener) {
    Messager.client
        .then((client) => client.privateQueue())
        .then((queue) async => queue.bind(await Messager.exchange, routingKey))
        .then((queue) => (queue..purge()).consume())
        .then((consumer) => consumer.listen(listener));
  }

  static void publish(String routingKey, Object message) {
    Messager.exchange.then(
      (exchange) => exchange.publish(message, routingKey),
    );
  }
}

class Context {
  final _items = <int, ass.Completer<Item>>{};
  final _size = ass.StreamController<int>();
  final void Function(int, int) _askForItem;

  Stream<int> get size => _size.stream;

  Context({required askForItem}) : _askForItem = askForItem;

  ass.Future<Item> getItem(int index) {
    final completer = _items.putIfAbsent(
      index,
      () {
        _askForItem(index, 1);
        return ass.Completer<Item>();
      },
    );
    return completer.future;
  }

  void setSize(int size) {
    _size.add(size);
    _items.clear();
  }

  void addItem(int index, Item item) {
    final completer = _items[index]!;
    completer.complete(item);
  }
}

const types = <String, ItemType>{
  '.jpg': ItemType.image,
  '.png': ItemType.image
};

class ContextProvider {
  final _items = <String, Context>{};

  Context Function() _getContextCreator(String name) {
    return () {
      Messager.publish('server/search/size', {'Context': name});
      return Context(
          askForItem: (int index, int count) => Messager.publish(
              'server/search/content',
              {'Context': name, 'Index': index, 'Count': count}));
    };
  }

  void _contentHandle(AmqpMessage arg) {
    final message = arg.payloadAsJson;

    final name = message['Context'];
    final context = _items.putIfAbsent(name, _getContextCreator(name));

    final items = message['Items'];
    for (final item in items) {
      final String path = item['Path'];
      context.addItem(
          item['Index'],
          Item(
              title: path,
              icon: basename(path),
              type: types[extension(path)]!));
    }
  }

  void _sizeHandle(AmqpMessage arg) {
    final message = arg.payloadAsJson;

    final name = message['Context'];
    final context = _items.putIfAbsent(name, _getContextCreator(name));

    context.setSize(message['Size']);
  }

  ContextProvider() {
    Messager.privateQueue('client/search/content', _contentHandle);
    Messager.privateQueue('client/search/size', _sizeHandle);
  }
  Context getContext(String name) {
    final context = _items.putIfAbsent(name, _getContextCreator(name));
    return context;
  }
}
