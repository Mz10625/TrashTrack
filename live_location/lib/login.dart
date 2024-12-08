
import 'package:flutter/material.dart';
import 'package:live_location/ActiveVehiclesScreen.dart';
import 'package:live_location/firebase_operations.dart';
import 'package:live_location/home.dart';
import 'signup.dart';

class Login extends StatefulWidget{
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  // String password = "";
  TextEditingController pass = TextEditingController();
  TextEditingController email = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.58,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/login1.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Back,',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    controller: email,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    obscureText: _passwordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: IconButton(onPressed: ()=>{
                        setState((){
                          _passwordVisible = !_passwordVisible;
                          // password = pass.text;
                        }),
                      },
                        icon: !_passwordVisible ? Icon(Icons.visibility_rounded) : Icon(Icons.visibility_off)
                      ),
                    ),
                    controller: pass,
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {

                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: ()async {
                      if(pass.text != "" && email.text != ""){
                        // int login_success = 1;
                        int login_success = await login(email.text,pass.text);
                        if(login_success == 1){
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ActiveVehiclesScreen()));
                        }
                        else if(login_success == -1){
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text("Network Error"),
                                content: Text("Please check your Internet connectivity and try again"),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text("Ok")
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        else{
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: Text("Login Failed"),
                                content: Text("Incorrect Email or Password"),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text("Ok")
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      }
                      else{
                        showDialog(
                          context: context,
                          builder: (context){
                            return AlertDialog(
                              title: Text("Missing Fileds"),
                              content: Text(
                                  "Please Enter Username and Password"
                              ),
                              actions: [
                                TextButton(
                                  onPressed: (){
                                    Navigator.pop(context) ;
                                  },
                                  child: Text("Ok",style: TextStyle(color: Colors.black54),),
                                )
                              ],
                            );
                          },
                        );
                      }
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUp()),
                        );
                      },
                      child: Text(
                        'Sign Up',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
