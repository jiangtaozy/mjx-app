/*
 * Maintained by jemo from 2019.7.29 to now
 * Created by jemo on 2019.7.29 15:43
 * Login
 */

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'register.dart';
import 'config.dart';

class Login extends StatefulWidget {

  @override
  LoginState createState() => LoginState();

}

class LoginState extends State<Login> {

  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool passwordObscure = true;

  void onSubmitPressed() async {
    if(!formKey.currentState.validate()) {
      return null;
    }
    var phone = phoneController.text;
    var password = passwordController.text;
    final query = r'''
      mutation GetTokenMutation(
        $input: GetTokenInput!
      ) {
        getToken(input: $input) {
          getTokenResult {
            error
            message
            phone
            token
          }
        }
      }
    ''';
    Map<String, dynamic> variables = {
      'input': {
        'clientMutationId': "333",
        'phone': phone,
        'password': password,
      },
    };
    final data = {
      'query': query,
      'variables': variables,
    };
    final body = json.encode(data);
    showLoading();
    final response = await http.post(
      graphqlUrl,
      headers: {
        "Content-Type": "application/json",
      },
      body: body,
    );
    dismissLoading();
    if(response.statusCode == 200) {
      final data = json.decode(response.body);
      final result = data['data']['getToken']['getTokenResult'];
      final error = result['error'];
      final message = result['message'];
      final phone = result['phone'];
      final token = result['token'];
      if(error == null) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('token', token);
      }
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(message),
          );
        },
      );
      Timer(Duration(seconds: 1), () {
        Navigator.of(context, rootNavigator: true).pop('dialog');
      });
    } else {
      throw Exception('网络出错了');
    }
  }

  void showLoading() {
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(10),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  void dismissLoading() {
    Navigator.of(context, rootNavigator: true).pop('dialog');
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: formKey,
        autovalidate: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40.0, 0.0, 40.0, 0.0),
          child:  Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '请输入手机号码',
                  labelText: '手机号',
                ),
                validator: (value) {
                  if(value.isEmpty) {
                    return '请输入手机号码';
                  }
                  RegExp phoneReg = new RegExp(r'(^1[3-9](\d{9})$)');
                  if(!phoneReg.hasMatch(value)) {
                    return '手机号格式不正确';
                  }
                  return null;
                },
              ),
              Stack(
                children: [
                  TextFormField(
                    controller: passwordController,
                    obscureText: passwordObscure,
                    decoration: const InputDecoration(
                      hintText: '请输入秘密',
                      labelText: '密码',
                    ),
                    validator: (value) {
                      if(value.isEmpty) {
                        return '请输入秘密';
                      }
                      return null;
                    },
                  ),
                  Positioned(
                    right: 0,
                    bottom: 8,
                    child: IconButton(
                      icon: Icon(
                        passwordObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          passwordObscure = !passwordObscure;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 40, 0, 0),
                width: double.infinity,
                child: RaisedButton(
                  color: Colors.redAccent,
                  onPressed: onSubmitPressed,
                  child: Text('立即登录'),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: FlatButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Register()),
                    );
                  },
                  child: Text('注册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
