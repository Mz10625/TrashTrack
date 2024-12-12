
import 'package:flutter/material.dart';
import 'package:live_location/ActiveVehiclesScreen.dart';
import 'package:live_location/firebase_operations.dart';
import 'package:live_location/reset_password.dart';
import 'signup.dart';

class Login extends StatefulWidget{
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
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
              decoration: const BoxDecoration(
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
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
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
                  const Text(
                    'Welcome Back,',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    controller: email,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    obscureText: !_passwordVisible,
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
                        icon: !_passwordVisible ? const Icon(Icons.visibility_rounded) : const Icon(Icons.visibility_off)
                      ),
                    ),
                    controller: pass,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.push(context, MaterialPageRoute(builder: (context)=> const ForgotPasswordPage()));
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color.fromRGBO(11, 52, 110,1)),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width/3,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade300,
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
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUp()),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(color: Color.fromRGBO(11, 52, 110,1)),
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
