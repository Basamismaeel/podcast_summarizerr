import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:podcast_safety_net/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(child: PodcastSafetyNetApp(prefs: prefs)),
    );
    await tester.pumpAndSettle();
  });
}
