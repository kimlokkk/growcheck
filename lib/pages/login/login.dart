// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/home/home.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:sizer/sizer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController staffNoController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscureText = true;
  bool isSwitched = false;

  Future signin() async {
    var response = await http.post(Uri.parse('https://app.kizzukids.com.my/growkids/flutter/login.php'), body: {
      "staff_no": staffNoController.text,
      "password": passwordController.text,
    });

    var data = json.decode(response.body);
    if (data == "Error 1") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Password")));
      print(data);
    } else if (data == "Error 2") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Not Found")));
      print(data);
    } else {
      if (isSwitched == true) {
        SharedPreferences preferences = await SharedPreferences.getInstance();
        preferences.setString('staffNo', staffNoController.text);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log In Success")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => const Home(),
          ),
        );
        setState(() {
          staff_no = data[0]['staff_no'];
          id = data[0]['staff_id'];
          name = data[0]['staff_name'];
          nickname = data[0]['staff_nickname'];
          ic = data[0]['staff_ic'];
          password = data[0]['staff_pass'];
          email = data[0]['staff_email'];
          designation = data[0]['staff_designation'];
          image = data[0]['staff_img'];
          program = data[0]['staff_program'];
          branch = data[0]['staff_branch'];
          total_screenings = data[0]['total_screenings'].toString();
          current_month_screenings = data[0]['current_month_screenings'].toString();
          previous_month_screenings = data[0]['previous_month_screenings'].toString();
          students_to_screen_today = data[0]['students_to_screen_today'].toString();
        });
        print(data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Log In Success !")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => const Home(),
          ),
        );
        print(data);
        setState(() {
          staff_no = data[0]['staff_no'];
          id = data[0]['staff_id'];
          name = data[0]['staff_name'];
          nickname = data[0]['staff_nickname'];
          ic = data[0]['staff_ic'];
          password = data[0]['staff_pass'];
          email = data[0]['staff_email'];
          designation = data[0]['staff_designation'];
          image = data[0]['staff_img'];
          program = data[0]['staff_program'];
          branch = data[0]['staff_branch'];
          total_screenings = data[0]['total_screenings'].toString();
          current_month_screenings = data[0]['current_month_screenings'].toString();
          previous_month_screenings = data[0]['previous_month_screenings'].toString();
          students_to_screen_today = data[0]['students_to_screen_today'].toString();
        });
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg-colour.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Growkids.purple, // The color and opacity to apply to the image
              BlendMode.color, // The blending mode to apply the color filter
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              child: Image.asset(
                'assets/Growcheck-logo.png',
                scale: 8,
              ),
            ),
            SizedBox(
              height: 2.h,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.h),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    15,
                  ), // Set the desired border radius here
                ),
                child: Container(
                  padding: EdgeInsets.all(2.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome !',
                        style: TextStyle(
                          color: const Color(0xfffc638f),
                          fontSize: 18.sp,
                        ),
                      ),
                      const Text(
                        'Our services are ready for you',
                        style: TextStyle(
                          color: Color(0xff4648a1),
                        ),
                      ),
                      SizedBox(
                        height: 2.h,
                      ),
                      TextField(
                        keyboardType: TextInputType.text,
                        controller: staffNoController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person),
                          prefixIconColor: Color(0xff4648a1),
                          filled: true,
                          fillColor: GrowkidsPastel.purple,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            borderSide: BorderSide.none,
                          ),
                          hintText: 'Staff Number',
                        ),
                        autofocus: false,
                      ),
                      SizedBox(
                        height: 1.h,
                      ),
                      TextField(
                        obscureText: _obscureText,
                        controller: passwordController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          prefixIconColor: const Color(0xff4648a1),
                          hintText: 'Password',
                          filled: true,
                          fillColor: GrowkidsPastel.purple,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            color: const Color(0xff4648a1),
                            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.h,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Switch(
                            activeColor: Growkids.pink,
                            value: isSwitched,
                            onChanged: (value) {
                              setState(() {
                                isSwitched = value;
                              });
                            },
                          ),
                          SizedBox(
                            width: 2.w,
                          ),
                          const Text(
                            'Remember Me ?',
                            style: TextStyle(
                              color: Color(
                                0xff4648a1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          /*Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPass(),
                            ),
                          );*/
                        },
                        child: const Text(
                          'Forgot Password ?',
                          style: TextStyle(
                            color: Color(0xff4648a1),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 2.h,
                      ),
                      SizedBox(
                        height: 5.h,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            signin();
                            /*Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) => TabPage(),
                              ),
                            );*/
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfffc638f),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10), // <-- Radius
                            ),
                          ),
                          child: const Text(
                            'LOGIN',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 1.h,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 2.h,
            ),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 40.w,
                child: Text(
                  'By clicking on sign in, you agree to our terms and services',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
