import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDeepLink {
  const AppDeepLink({required this.route, this.date});

  final String route;
  final String? date;

  static AppDeepLink? fromData(Map<String, dynamic> data) {
    final route = data['route'];
    if (route is! String || route.isEmpty) return null;
    return AppDeepLink(
      route: route,
      date: data['date'] is String ? data['date'] as String : null,
    );
  }
}

class DeepLinkController extends Notifier<AppDeepLink?> {
  @override
  AppDeepLink? build() => null;

  void setFromData(Map<String, dynamic> data) {
    final link = AppDeepLink.fromData(data);
    if (link != null) {
      state = link;
    }
  }

  void consume() {
    state = null;
  }
}

final deepLinkControllerProvider =
    NotifierProvider<DeepLinkController, AppDeepLink?>(DeepLinkController.new);
