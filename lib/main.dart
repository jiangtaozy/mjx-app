/*
 * Maintained by jemo from 2019.5.29 to now
 * Created by jemo on 2019.5.29 12:16
 * Main
 */

import 'package:flutter/material.dart';
import 'home.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '母鸡行',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Home(),
    );
  }
}
