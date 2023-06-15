import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emartdriver/constants.dart';
import 'package:emartdriver/main.dart';
import 'package:emartdriver/model/User.dart';
import 'package:emartdriver/rental_service/model/rental_order_model.dart';
import 'package:emartdriver/services/FirebaseHelper.dart';
import 'package:emartdriver/services/helper.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'renatal_summary_screen.dart';

class RentalHomeScreen extends StatefulWidget {
  const RentalHomeScreen({Key? key}) : super(key: key);

  @override
  State<RentalHomeScreen> createState() => _RentalHomeScreenState();
}

class _RentalHomeScreenState extends State<RentalHomeScreen> {
  final FireStoreUtils _fireStoreUtils = FireStoreUtils();
  List<RentalOrderModel> ordersList = [];

  @override
  void initState() {
    // TODO: implement initState
    getDriver();
    getBookedData();
    super.initState();
  }

  bool isLoading = true;

  late Stream<User> driverStream;
  getDriver() async {
    driverStream = FireStoreUtils().getDriver(MyAppState.currentUser!.userID);
    driverStream.listen((event) {
      setState(() => MyAppState.currentUser = event);
    });
  }


  getBookedData() async {
    print(MyAppState.currentUser!.isCompany);
    print(MyAppState.currentUser!.companyId);
    if (MyAppState.currentUser!.isCompany == true) {
      await _fireStoreUtils.getRentalBook(MyAppState.currentUser!.userID, true).then((value) {
        setState(() {
          ordersList = value;
          isLoading = false;
          print("--->${value.length}");
        });
      });
    } else {
      await _fireStoreUtils.getRentalBook(MyAppState.currentUser!.userID, false).then((value) {
        setState(() {
          ordersList = value;
          isLoading = false;
          print("--->");
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ordersList.isEmpty
              ? Center(
                  child: Text(
                  "Booking not found",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ).tr())
              : RefreshIndicator(
                  onRefresh: () async {
                    // Replace this delay with the code to be executed during refresh
                    // and return asynchronous code
                    getBookedData();
                  },
                  child: ListView.builder(
                    itemCount: ordersList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      return buildRides(ordersList[index]);
                    },
                  ),
                ),
    );
  }

  buildRides(RentalOrderModel orderModel) {
    return InkWell(
      onTap: () {
        push(context, RenatalSummaryScreen(rentalOrderModel: orderModel));
      },
      child: GestureDetector(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Color(COLOR_PRIMARY),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CachedNetworkImage(
                            height: 50,
                            width: 50,
                            imageUrl: orderModel.author!.profilePictureURL,
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                              ),
                            ),
                            placeholder: (context, url) => Center(
                                child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
                            )),
                            errorWidget: (context, url, error) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  placeholderImage,
                                  fit: BoxFit.cover,
                                )),
                            fit: BoxFit.cover,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orderModel.author!.firstName + " " + orderModel.author!.lastName,
                                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Visibility(
                                  visible: orderModel.bookWithDriver == true ? true : false,
                                  child: Text(
                                    "With driver trip".tr(),
                                    style: TextStyle(fontSize: 14, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  "$symbol ${double.parse(orderModel.subTotal.toString()).toStringAsFixed(decimal)}",
                                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              buildUsersDetails(context,
                                  address: orderModel.pickupAddress.toString(), time: DateFormat('yyyy-MM-dd hh:mm a').format(orderModel.pickupDateTime!.toDate())),
                              const SizedBox(
                                height: 10,
                              ),
                              buildUsersDetails(context,
                                  isSender: false, address: orderModel.dropAddress.toString(), time: DateFormat('yyyy-MM-dd hh:mm a').format(orderModel.dropDateTime!.toDate())),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Visibility(
                          visible: MyAppState.currentUser!.companyId.isEmpty && orderModel.status == ORDER_STATUS_PLACED,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black.withOpacity(0.10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0),
                                    onPressed: () async {
                                      MyAppState.currentUser!.rentalBookingDate = null;
                                      await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
                                      setState(() {
                                        orderModel.status = ORDER_STATUS_REJECTED;
                                      });
                                      await FireStoreUtils.updateRentalOrder(orderModel);

                                      getBookedData();

                                      if (orderModel.paymentMethod.toLowerCase() != "cod") {
                                        double subTotal = (double.parse(orderModel.subTotal.toString()) + double.parse(orderModel.driverRate.toString())) -
                                            double.parse(orderModel.discount.toString());

                                        double totalTax = 0.0;
                                        if (orderModel.taxType!.isNotEmpty) {
                                          if (orderModel.taxType == "percent") {
                                            totalTax = subTotal * double.parse(orderModel.tax.toString()) / 100;
                                          } else {
                                            totalTax = double.parse(orderModel.tax.toString());
                                          }
                                        }

                                        double userAmount = 0;

                                        if (orderModel.paymentMethod.toLowerCase() != "cod") {
                                          userAmount = subTotal + totalTax;
                                        }

                                        FireStoreUtils.createPaymentId().then((value) async {
                                          final paymentID = value;
                                          await FireStoreUtils.topUpWalletAmount(userID: orderModel.authorID, paymentMethod: "Refund Amount", amount: userAmount, id: paymentID)
                                              .then((value) async {
                                            await FireStoreUtils.updateUserWalletAmount(userId: orderModel.authorID, amount: userAmount).then((value) {});
                                          });
                                        });
                                      }

                                      if (MyAppState.currentUser!.isCompany == true) {
                                        await FireStoreUtils.sendFcmMessage(
                                            "Booking Rejected ! ".tr(),
                                            "${MyAppState.currentUser!.companyName} " + "has reject your booking request.".tr(),
                                            orderModel.author!.fcmToken,
                                            orderModel.driver!.fcmToken);
                                      } else {
                                        await FireStoreUtils.sendFcmMessageSingle(
                                            "Booking Rejected ! ".tr(),
                                            "${MyAppState.currentUser!.firstName} ${MyAppState.currentUser!.lastName} " + "has reject your booking request.".tr(),
                                            orderModel.author!.fcmToken);
                                      }
                                    },
                                    child: Text(
                                      'Decline'.tr(),
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 5,
                                ),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(COLOR_PRIMARY),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
                                      });
                                      await FireStoreUtils.updateRentalOrder(orderModel);

                                      if (MyAppState.currentUser!.isCompany == true) {
                                        await FireStoreUtils.sendFcmMessage(
                                            "Booking Accepted !".tr(),
                                            "${MyAppState.currentUser!.companyName} " + "has accept your booking request.".tr(),
                                            orderModel.author!.fcmToken,
                                            orderModel.driver!.fcmToken);
                                      } else {
                                        await FireStoreUtils.sendFcmMessageSingle(
                                            "Booking Accepted !".tr(),
                                            "${MyAppState.currentUser!.firstName} ${MyAppState.currentUser!.lastName} " + "has accept your booking request.".tr(),
                                            orderModel.author!.fcmToken);
                                      }
                                      getBookedData();
                                    },
                                    child: Text(
                                      'Accept'.tr(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Visibility(
                          visible: orderModel.status == ORDER_STATUS_DRIVER_ACCEPTED,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(COLOR_PRIMARY),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (orderModel.pickupDateTime!.toDate().isBefore(DateTime.now())) {

                                        print("---------->");
                                        print(MyAppState.currentUser!.toJson());
                                        MyAppState.currentUser!.rentalBookingDate = getDaysInBeteween(orderModel.pickupDateTime!.toDate(), orderModel.dropDateTime!.toDate());
                                        await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);

                                        setState(() {
                                          orderModel.status = ORDER_STATUS_IN_TRANSIT;
                                        });
                                        await FireStoreUtils.updateRentalOrder(orderModel);
                                        getBookedData();

                                        await FireStoreUtils.sendFcmMessageSingle("Star Ride !".tr(),
                                            "${MyAppState.currentUser!.firstName} ${MyAppState.currentUser!.lastName} has start your ride", orderModel.author!.fcmToken);
                                      } else {
                                        final snack = SnackBar(
                                          content: Text(
                                            'You can start ride on your pickup date and time.'.tr(),
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.black,
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(snack);
                                      }
                                    },
                                    child: Text(
                                      'Start Ride'.tr(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Visibility(
                          visible: orderModel.status == ORDER_STATUS_IN_TRANSIT,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(COLOR_PRIMARY),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () async {
                                      MyAppState.currentUser!.rentalBookingDate = null;

                                      setState(() {
                                        orderModel.status = ORDER_STATUS_COMPLETED;
                                      });

                                      Position? locationData = await getCurrentLocation();
                                      MyAppState.currentUser!.location = UserLocation(latitude: locationData.latitude, longitude: locationData.longitude);
                                      await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);

                                      updateRentalWalletAmount(orderModel);
                                      await FireStoreUtils.updateRentalOrder(orderModel);

                                      getBookedData();

                                      await FireStoreUtils.getRentalFirstOrderOrNOt(orderModel).then((value) async {
                                        if (value == true) {
                                          await FireStoreUtils.updateRentalReferralAmount(orderModel);
                                        }
                                      });

                                      await FireStoreUtils.sendFcmMessageSingle("Booking Completed ! ".tr(),
                                          "${MyAppState.currentUser!.firstName} ${MyAppState.currentUser!.lastName} " + "has completed your ride.", orderModel.author!.fcmToken);
                                    },
                                    child: Text(
                                      'Complete Ride'.tr(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }

  List<Timestamp> getDaysInBeteween(DateTime startDate, DateTime endDate) {
    List<Timestamp> days = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      days.add(Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day + i)));
    }
    return days;
  }

  buildUsersDetails(
    context, {
    bool isSender = true,
    required String time,
    required String address,
  }) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15.0), border: Border.all(color: Colors.grey.withOpacity(0.30), width: 2.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSender ? "PickUp".tr() + " " : "Drop off".tr() + " ",
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
            const SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(
                      right: 8.0,
                    ),
                    child: Icon(
                      Icons.access_time_outlined,
                      size: 20,
                      color: Color(COLOR_PRIMARY),
                    )),
                Expanded(
                  child: Text(
                    time,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 8,
            ),
            Row(
              children: [
                Padding(
                    padding: const EdgeInsets.only(
                      right: 8.0,
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 20,
                      color: Color(COLOR_PRIMARY),
                    )),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
