import 'package:flutter/material.dart';

import 'swipe_to_close_wrapper.dart';

/// 画面遷移の共通ルート（osm日日是好日と同じ）。左上の戻るボタンは出さず、
/// いちばん上からの下スワイプと、左端からの右スワイプで閉じる。
/// 地図やドラッグ操作のある画面は [closeOnSwipeDown] を false にする。
Route<T> osmPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool closeOnEdgeSwipe = true,
  bool closeOnSwipeDown = true,
}) => MaterialPageRoute<T>(
  settings: settings,
  builder: (context) => SwipeToCloseWrapper(
    closeOnEdgeSwipe: closeOnEdgeSwipe,
    closeOnSwipeDown: closeOnSwipeDown,
    child: builder(context),
  ),
);
