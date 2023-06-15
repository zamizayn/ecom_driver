import 'package:easy_localization/easy_localization.dart';
import 'package:emartdriver/constants.dart';
import 'package:emartdriver/main.dart';
import 'package:emartdriver/model/User.dart';
import 'package:emartdriver/services/FirebaseHelper.dart';
import 'package:emartdriver/services/helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RideSettingScreen extends StatefulWidget {
  const RideSettingScreen({Key? key}) : super(key: key);

  @override
  State<RideSettingScreen> createState() => _RideSettingScreenState();
}

class _RideSettingScreenState extends State<RideSettingScreen> {
  bool? isRide = true;
  bool? isIntercity = false;
  bool? isBoth = false;

  @override
  void initState() {
    // TODO: implement initState
    getUserData();
    super.initState();
  }

  User? user;
  bool isLoading = true;

  getUserData() async {
    if (MyAppState.currentUser != null) {
      await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.userID).then((value) {
        setState(() {
          user = value;

          if (user!.rideType == "both") {
            isIntercity = true;
            isBoth = true;
          } else {
            isIntercity = false;
            isBoth = false;
          }
          isLoading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? CircularProgressIndicator()
          : Column(
              children: [
                SwitchListTile.adaptive(
                    activeColor: Color(COLOR_ACCENT),
                    title: Text(
                      'Ride setting',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                      ),
                    ).tr(),
                    value: isRide!,
                    onChanged: (bool newValue) {
                      setState(() {
                        // isRide = newValue;
                        // if (isIntercity == true && isRide == true) {
                        //   isBoth = true;
                        // } else {
                        //   isBoth = false;
                        // }
                      });
                    }),
                SwitchListTile.adaptive(
                    activeColor: Color(COLOR_ACCENT),
                    title: Text(
                      'Intercity / OutStation',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                      ),
                    ).tr(),
                    value: isIntercity!,
                    onChanged: (bool newValue) {
                      setState(() {
                        isIntercity = newValue;
                        if (isIntercity == true && isRide == true) {
                          isBoth = true;
                        } else {
                          isBoth = false;
                        }
                      });
                    }),
                SwitchListTile.adaptive(
                    activeColor: Color(COLOR_ACCENT),
                    title: Text(
                      'Both',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                      ),
                    ).tr(),
                    value: isBoth!,
                    onChanged: (bool newValue) {
                      setState(() {
                        if (newValue) {
                          isBoth = newValue;
                          isIntercity = true;
                        } else {
                          isBoth = newValue;
                          isIntercity = false;
                          isRide = true;
                        }
                      });
                    }),
                Padding(
                    padding: const EdgeInsets.only(top: 32.0, bottom: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: double.infinity),
                      child: Material(
                        elevation: 2,
                        color: isDarkMode(context) ? Colors.black12 : Colors.white,
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(12.0),
                          onPressed: () async {
                            setState(() {
                              user!.rideType = isIntercity == true ? "both" : "ride";
                            });

                            FireStoreUtils.updateCurrentUser(user!).then((value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Setting successfully update.".tr(),
                                    style: TextStyle(fontSize: 17),
                                  ),
                                ),
                              );
                            });
                          },
                          child: Text(
                            'Save',
                            style: TextStyle(fontSize: 18, color: Color(COLOR_PRIMARY)),
                          ).tr(),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}
