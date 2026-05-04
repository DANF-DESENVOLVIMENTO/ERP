import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app/erp_danf_app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      assert(() {
        debugPrintScheduleFrameStacks = true;
        return true;
      }());

      final runtimeErrorNotifier = ValueNotifier<Object?>(null);
      void publishRuntimeError(Object error) {
        void assign() {
          runtimeErrorNotifier.value = error;
        }

        final phase = SchedulerBinding.instance.schedulerPhase;
        if (phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks) {
          assign();
          return;
        }

        SchedulerBinding.instance.addPostFrameCallback((_) {
          assign();
        });
      }

      FlutterError.onError = (details) {
        publishRuntimeError(details.exception);
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        publishRuntimeError(error);
        return true;
      };

      Object? firebaseInitializationError;
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (error) {
        firebaseInitializationError = error;
      }

      runApp(
        ErpDanfApp(
          firebaseInitializationError: firebaseInitializationError,
          runtimeErrorListenable: runtimeErrorNotifier,
        ),
      );
    },
    (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}
