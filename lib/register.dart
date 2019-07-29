/*
 * Maintained by jemo from 2019.7.17 to now
 * Created by jemo on 2019.7.17 16:25
 * Register
 */

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'config.dart';

class Register extends StatefulWidget {

  @override
  RegisterState createState() => RegisterState();

}

class RegisterState extends State<Register> {

  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final validationCodeController = TextEditingController();
  final passwordController = TextEditingController();
  final repeatPasswordController = TextEditingController();
  int countdown = -1;
  bool passwordObscure = true;
  Timer countdownTimer;

  void onGetValidationCodePressed() async {
    var phone = phoneController.text;
    RegExp phoneReg = new RegExp(r'(^1[3-9](\d{9})$)');
    if(phone.length == 0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('请先输入手机号'),
          );
        },
      );
      return null;
    }
    if(!phoneReg.hasMatch(phone)) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('手机号格式不正确'),
          );
        },
      );
      return null;
    }
    final query = r'''
      mutation GetValidationCodeMutation(
        $input: GetValidationCodeInput!
      ) {
        getValidationCode(input: $input) {
          result {
            error
            message
          }
        }
      }
    ''';
    Map<String, dynamic> variables = {
      'input': {
        'clientMutationId': "111",
        'phone': phone,
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
      final result = data['data']['getValidationCode']['result'];
      final message = result['message'];
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
      setState(() {
        countdown = 5 * 60;
      });
      countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          countdown = countdown - 1;
        });
        if(countdown < 0) {
          timer.cancel();
        }
      });
    } else {
      throw Exception('网络出错了');
    }
  }

  void onSubmitPressed() async {
    if(!formKey.currentState.validate()) {
      return null;
    }
    var phone = phoneController.text;
    var validationCode = validationCodeController.text;
    var password = passwordController.text;
    var repeatPassword = repeatPasswordController.text;
    if(password != repeatPassword) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('两次输入的密码不一致'),
          );
        },
      );
      return null;
    }
    final query = r'''
      mutation CreateUserMutation(
        $input: CreateUserInput!
      ) {
        createUser(input: $input) {
          createUserResult {
            error
            message
            token
          }
        }
      }
    ''';
    Map<String, dynamic> variables = {
      'input': {
        'clientMutationId': "222",
        'phone': phone,
        'password': password,
        'code': validationCode,
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
      final result = data['data']['createUser']['createUserResult'];
      final message = result['message'];
      final token = result['token'];
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
    validationCodeController.dispose();
    passwordController.dispose();
    repeatPasswordController.dispose();
    countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidate: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40.0, 0.0, 40.0, 0.0),
        child: Column(
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
                  controller: validationCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '请输入验证码',
                    labelText: '验证码',
                  ),
                  validator: (value) {
                    if(value.isEmpty) {
                      return '请输入验证码';
                    }
                    return null;
                  },
                ),
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: RaisedButton(
                    onPressed: countdown > 0 ? null : onGetValidationCodePressed,
                    child: Text(
                      countdown > 0 ? '${countdown}秒' : '获取验证码'
                    ),
                  ),
                ),
              ],
            ),
            Stack(
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: passwordObscure,
                  decoration: const InputDecoration(
                    hintText: '请输入密码',
                    labelText: '密码',
                  ),
                  validator: (value) {
                    if(value.isEmpty) {
                      return '请输入密码';
                    }
                    if(value.length < 6) {
                      return '请输入长度不少于 6 位的秘密';
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
                    }
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: repeatPasswordController,
              obscureText: passwordObscure,
              decoration: const InputDecoration(
                hintText: '请再次输入密码',
                labelText: '重复密码',
              ),
              validator: (value) {
                if(value.isEmpty) {
                  return '请再次输入密码';
                }
                return null;
              },
            ),
            Container(
              margin: EdgeInsets.fromLTRB(0, 30, 0, 0),
              width: double.infinity,
              child: RaisedButton(
                color: Colors.redAccent,
                onPressed: onSubmitPressed,
                child: Text('立即注册'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
