/*
 * Maintained by jemo from 2019.5.29 to now
 * Created by jemo on 2019.5.29 15:55
 * School
 */

import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'config.dart';

class School extends StatefulWidget {

  @override
  SchoolState createState() => SchoolState();

}

class SchoolState extends State<School> {
  var teacherList = [];
  Map<String, dynamic> pageInfo = {
    'hasNextPage': true,
  };

  @override
  void initState() {
    super.initState();
  }

  void fetchData() async {
    if(pageInfo['hasNextPage']) {
      final query = r'''
        query schoolPaginationQuery(
          $count: Int!
          $cursor: String
        ) {
          viewer {
            ...school_viewer
          }
        }
        fragment school_viewer on Viewer {
          userList(first: $count, after: $cursor) {
            edges {
              node {
                id
                avatar
                nickname
                introduction
                backgroundImage
                __typename
              }
              cursor
            }
            pageInfo {
              endCursor
              hasNextPage
            }
          }
        }
      ''';
      Map<String, dynamic> variables = {
        'count': 5,
      };
      if(pageInfo['endCursor'] != null) {
        variables['cursor'] = pageInfo['endCursor'];
      }
      final data = {
        'query': query,
        'variables': variables,
      };

      final body = json.encode(data);
      final response = await http.post(
        graphqlUrl,
        headers: {
          "Content-Type": "application/json",
        },
        body: body,
      );
      if(response.statusCode == 200) {
        final data = json.decode(response.body);
        final edges = data["data"]["viewer"]["userList"]["edges"];
        setState(() {
          teacherList = [...teacherList, ...edges];
          pageInfo = data["data"]["viewer"]["userList"]["pageInfo"];
        });
      } else {
        throw Exception('Failed to load post');
      }
    } else {
      //print('没有更多了');
    }
  }
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (content, i) {
        if(i < teacherList.length) {
          final teacher = teacherList[i];
          Map<String, dynamic> node = teacher['node'];
          if(node['backgroundImage'] == null || node['backgroundImage'].isEmpty) {
            node['backgroundImage'] = 'https://destpact.com/image/one-piece.jpg';
          }
          if(node['avatar'] == null || node['avatar'].isEmpty) {
            node['avatar'] = 'https://destpact.com/icon/avatar-8a-128.svg';
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: <Widget>[
                  // 背景图
                  Container(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: Image.network(
                      node['backgroundImage'],
                      height: 240,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 头像和昵称
                  Positioned(
                    bottom: -70,
                    child: Container(
                      transform: Matrix4.translationValues(0.0, -70, 0.0),
                      margin: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: new BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: new BorderRadius.circular(5),
                              child: Image.network(
                                node['avatar'],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              node['nickname'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: <Shadow>[
                                  Shadow(
                                    offset: Offset(1.0, 1.0),
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
              // 简介
              Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  node['introduction'],
                ),
              ),
            ],
          );
        } else {
          fetchData();
        }
      }
    );
  }
}
