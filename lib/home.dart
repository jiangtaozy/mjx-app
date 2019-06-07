/*
 * Maintained by jemo from 2019.5.29 to now
 * Created by jemo on 2019.5.29 12:16
 * Home
 */

import 'package:flutter/material.dart';
import 'school.dart';
import 'classroom.dart';
import 'my.dart';

class Home extends StatefulWidget {

  @override
  HomeState createState() => HomeState();

}

class HomeState extends State<Home> {

  int selectedIndex = 0;
  final widgetOptions = [
    School(),
    Classroom(),
    My(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('母鸡行'),
      ),
      body: Center(
        child: widgetOptions.elementAt(selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            title: Text('主页'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            title: Text('课堂'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_box),
            title: Text('我的'),
          ),
        ],
        currentIndex: selectedIndex,
        fixedColor: Colors.blue,
        onTap: onItemTapped,
      ),
    );
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

}
