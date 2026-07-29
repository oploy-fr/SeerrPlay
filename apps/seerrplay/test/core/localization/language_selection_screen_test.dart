import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/app/seerrplay_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the phone language before profile setup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const ProviderScope(child: SeerrPlayApp()));
    await tester.pumpAndSettle();

    expect(find.text('Elige tu idioma'), findsOneWidget);
    final choices = tester.widgetList<RadioListTile<String>>(
      find.byType(RadioListTile<String>),
    );
    expect(choices.first.value, 'es');
    expect(find.text('Idioma del teléfono'), findsOneWidget);
    expect(find.text('Nuevo perfil'), findsNothing);
  });
}
