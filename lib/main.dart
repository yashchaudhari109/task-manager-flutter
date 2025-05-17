import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

void main() {
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Task Manager',
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
