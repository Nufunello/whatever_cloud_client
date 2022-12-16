library content;

import 'dart:async' as ass;
import "package:dart_amqp/dart_amqp.dart";
import 'package:path/path.dart';

enum ItemType { image, video, unsupported }

late String SERVER_IP;

class Item {
  final String path;
  final String title;
  final ItemType type;

  const Item({required this.title, required this.type, required this.path});
}

class Messager {
  static final clients = <String, Client>{};
  static Client client(String IP) {
    return clients.putIfAbsent(
        IP,
        () => Client(
            settings: ConnectionSettings(
                host: IP,
                authProvider: const PlainAuthenticator("test", "test"))));
  }

  static Future<Channel>? _channel;
  static Future<Channel> channel(String ip) {
    return _channel ??= client(ip).channel();
  }

  static Future<Exchange> exchange(String IP) {
    return channel(IP).then((client) =>
        client.exchange('amq.direct', ExchangeType.DIRECT, durable: true));
  }

  static Future<Consumer> privateQueue(
      String ip, String routingKey, Function(AmqpMessage message) listener) {
    return Messager.channel(ip)
        .then((client) => client.privateQueue())
        .then((queue) async =>
            queue.bind(await Messager.exchange(ip), routingKey))
        .then((queue) => (queue..purge()).consume())
      ..then((consumer) => consumer.listen(listener));
  }

  static void publish(String ip, String routingKey, Object message) {
    Messager.exchange(ip).then(
      (exchange) => exchange.publish(message, routingKey),
    );
  }
}

class Context {
  final _items = <int, ass.Completer<Item>>{};
  final _size = ass.StreamController<int>();
  final void Function(int, int) _askForItem;
  final void Function(List<int>) _askRemoveItem;

  Stream<int> get size => _size.stream;

  Context({required askForItem, required askForRemove})
      : _askForItem = askForItem,
        _askRemoveItem = askForRemove;

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
    final completer = _items.putIfAbsent(index, () => ass.Completer());
    completer.complete(item);
  }

  void askRemoveItem(List<int> index) {
    _askRemoveItem(index);
  }
}

const types = <String, ItemType>{
  '.jpg': ItemType.image,
  '.jpeg': ItemType.image,
  '.png': ItemType.image,
  '.gif': ItemType.image,
  '.mp4': ItemType.video
};

class ContextProvider {
  final _items = <String, Context>{};
  late Future<Consumer> _consumer;

  Context Function() _getContextCreator(String ip, String name) {
    return () {
      return Context(
          askForItem: (int index, int count) => Messager.publish(
              ip,
              'server/search/content',
              {'Context': name, 'Index': index, 'Count': count}),
          askForRemove: (List<int> indexes) =>
              Messager.publish(ip, 'server/search/update', {
                'Context': name,
                'Items': indexes
                    .map((index) => {'Index': index, 'Action': 'Remove'})
                    .toList()
              }));
    };
  }

  void _contentHandle(String ip, AmqpMessage arg) {
    final message = arg.payloadAsJson;

    final name = message['Context'];
    final context = _items.putIfAbsent(name, _getContextCreator(ip, name));

    final items = message['Items'];
    for (final item in items) {
      final String path = item['Path'];
      final type = types[extension(path)] ?? ItemType.unsupported;
      context.addItem(
          item['Index'], Item(title: basename(path), type: type, path: path));
    }
  }

  void _sizeHandle(String ip, AmqpMessage arg) {
    final message = arg.payloadAsJson;

    final name = message['Context'];
    final context = _items.putIfAbsent(name, _getContextCreator(ip, name));

    context.setSize(message['Size']);
  }

  ContextProvider(String ip) {
    Messager.privateQueue(ip, 'client/search/content',
        ((message) => _contentHandle(ip, message)));
    _consumer = Messager.privateQueue(
        ip, 'client/search/size', ((message) => _sizeHandle(ip, message)));
  }
  Context getContext(String ip, String name) {
    final askForSize = !_items.containsKey(name);
    final context = _items.putIfAbsent(name, _getContextCreator(ip, name));
    if (askForSize) {
      _consumer.then((value) =>
          Messager.publish(ip, 'server/search/size', {'Context': name}));
    }
    return context;
  }
}
