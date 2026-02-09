import 'dart:async';

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _streamController = StreamController<dynamic>.broadcast();

  // 发送事件
  void fire(dynamic event) => _streamController.add(event);

  // 监听事件
  Stream<T> on<T>() => _streamController.stream.where((event) => event is T).cast<T>();
}

// 定义一个特定的刷新事件
class RefreshWalletEvent {
  final String? txHash;
  final double? amount;
  RefreshWalletEvent({this.txHash, this.amount});
}